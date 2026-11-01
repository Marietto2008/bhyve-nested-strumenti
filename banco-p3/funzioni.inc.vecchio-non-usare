#define	PTP_PEND_MAX	5		/* un livello per voce, LA57 compreso */
struct ptp_pend {
	uint64_t	ptegpa;		/* GPA dell'L2 della voce */
	uint64_t	l1page;		/* pagina dell'L1 da cui e' stata LETTA */
	uint64_t	old;		/* valore letto: il CAS lo esige ancora uguale */
	uint64_t	bits;		/* PG_A e/o PG_M da accendere */
	bool		w32;		/* voce a 32 bit (paginazione a 32 bit) */
};
int
vie_canonical_check(enum vm_cpu_mode cpu_mode, uint64_t gla)
{
	uint64_t mask;

	if (cpu_mode != CPU_MODE_64BIT)
		return (0);

	/*
	 * The value of the bit 47 in the 'gla' should be replicated in the
	 * most significant 16 bits.
	 */
	mask = ~((1UL << 48) - 1);
	if (gla & (1UL << 47))
		return ((gla & mask) != mask);
	else
		return ((gla & mask) != 0);
}

static int
pf_error_code(int usermode, int prot, int rsvd, uint64_t pte)
{
	int error_code = 0;

	if (pte & PG_V)
		error_code |= PGEX_P;
	if (prot & VM_PROT_WRITE)
		error_code |= PGEX_W;
	if (usermode)
		error_code |= PGEX_U;
	if (rsvd)
		error_code |= PGEX_RSV;
	if (prot & VM_PROT_EXECUTE)
		error_code |= PGEX_I;

	return (error_code);
}

static void
ptp_release(void **cookie)
{
	if (*cookie != NULL) {
		vm_gpa_release(*cookie);
		*cookie = NULL;
	}
}

static void *
ptp_hold(struct vcpu *vcpu, vm_paddr_t ptpphys, size_t len, void **cookie,
    vm_paddr_t *l1held, uint64_t entgpa, uint64_t gla, int ngflags, int *herr)
{
	void *ptr;
	uint64_t l1;
	int error;

	ptp_release(cookie);
	*herr = EFAULT;
	/* nested: le tabelle dell'L2 stanno a GPA dell'L2 (identita' per l'L1).
	 * La voce sta nella stessa pagina della base (PAE: base allineata a 32
	 * byte, non a pagina): pagina dalla traduzione, scostamento dalla base */
	error = vm_nested_gpa(vcpu, entgpa, VM_PROT_READ, gla, ngflags, &l1);
	if (error != 0) {
		*herr = error;
		return (NULL);
	}
	ptpphys = (l1 & ~(uint64_t)PAGE_MASK) | (ptpphys & PAGE_MASK);
	*l1held = ptpphys;	/* la pagina dell'L1 effettivamente tenuta */
	ptr = vm_gpa_hold(vcpu, ptpphys, len, VM_PROT_RW, cookie);
	return (ptr);
}

static int
ptp_ad_write_check(struct vcpu *vcpu, uint64_t ptegpa, uint64_t l1held,
    uint64_t gla)
{
	bool denied;
	int error;

	error = vm_nested_ptp_write(vcpu, ptegpa, l1held, gla, &denied);
	if (error == EAGAIN)
		return (2);
	if (error != 0)
		return (EFAULT);
	if (!denied)
		return (0);
	vm_restart_instruction(vcpu);
	return (1);
}

static int
ptp_pend_add(struct ptp_pend *p, int *n, uint64_t ptegpa, uint64_t l1page,
    uint64_t old, uint64_t bits, bool w32)
{
	int i;

	l1page &= ~(uint64_t)PAGE_MASK;
	for (i = 0; i < *n; i++) {
		if (p[i].ptegpa != ptegpa)
			continue;
		if (p[i].l1page != l1page || p[i].w32 != w32 || p[i].old != old) {
			atomic_add_long(&gla2gpa_pend_restart, 1);
			return (2);
		}
		p[i].bits |= bits;	/* stessa voce, stessa lettura: un solo CAS */
		return (0);
	}
	if (*n >= PTP_PEND_MAX)
		return (EFAULT);
	p[*n].ptegpa = ptegpa;
	p[*n].l1page = l1page;
	p[*n].old = old;
	p[*n].bits = bits;
	p[*n].w32 = w32;
	(*n)++;
	return (0);
}

static int
ptp_commit(struct vcpu *vcpu, struct ptp_pend *p, int n, uint64_t gla)
{
	void *ck, *pg;
	uint64_t off;
	int ad, i, ok;

	for (i = 0; i < n; i++) {
		ad = ptp_ad_write_check(vcpu, p[i].ptegpa, p[i].l1page, gla);
		if (ad != 0)
			return (ad);
		pg = vm_gpa_hold(vcpu, p[i].l1page, PAGE_SIZE, VM_PROT_RW, &ck);
		if (pg == NULL)
			return (EFAULT);
		off = p[i].ptegpa & PAGE_MASK;
		if (p[i].w32)
			ok = atomic_cmpset_32((volatile uint32_t *)((char *)pg + off),
			    (uint32_t)p[i].old, (uint32_t)(p[i].old | p[i].bits));
		else
			ok = atomic_cmpset_64((volatile uint64_t *)((char *)pg + off),
			    p[i].old, p[i].old | p[i].bits);
		vm_gpa_release(ck);
		if (!ok)
			return (2);
	}
	return (0);
}

static int
_vm_gla2gpa(struct vcpu *vcpu, struct vm_guest_paging *paging,
    uint64_t gla, int prot, uint64_t *gpa, int *guest_fault, bool check_only)
{
	int ad, herr, laflags, leaf, ngflags, nlevels, npend, pfcode, ptpshift;
	int ptpindex, retval, usermode, writable;
	u_int retries;
	uint64_t *ptpbase, l1gpa, ptpgpa, ptpl1, ptpphys, pte, pgsize;
	uint32_t *ptpbase32, pte32;
	struct ptp_pend pend[PTP_PEND_MAX];
	void *cookie;

	*guest_fault = 0;

	usermode = (paging->cpl == 3 ? 1 : 0);
	writable = prot & VM_PROT_WRITE;
	cookie = NULL;
	retval = 0;
	retries = 0;
	ptpgpa = ptpl1 = 0;
	/* H2: senza fault (nofault) nessuna violazione si registra */
	ngflags = check_only ? 0 : VM_NGPA_RECORD;
restart:
	ptpphys = paging->cr3;		/* root of the page tables */
	ptp_release(&cookie);
	if (retries++ > 0)
		maybe_yield();
	npend = 0;			/* H2-AD: nessuna scrittura annotata */
	/*
	 * Bit 9-11 della qualificazione di una violation sull'indirizzo
	 * finale: AND di U/S e R/W, OR di XD sulle voci del walk; senza
	 * paginazione l'indirizzo e' utente, scrivibile, eseguibile (SDM).
	 */
	laflags = VM_NGPA_LA_US | VM_NGPA_LA_RW;

	if (vie_canonical_check(paging->cpu_mode, gla)) {
		/*
		 * XXX assuming a non-stack reference otherwise a stack fault
		 * should be generated.
		 */
		if (!check_only)
			vm_inject_gp(vcpu);
		goto fault;
	}

	if (paging->paging_mode == PAGING_MODE_FLAT) {
		*gpa = gla;
		goto translate;
	}

	if (paging->paging_mode == PAGING_MODE_32) {
		nlevels = 2;
		while (--nlevels >= 0) {
			/* Zero out the lower 12 bits. */
			ptpphys &= ~0xfff;
			ptpgpa = ptpphys;	/* GPA dell'L2: per A/D */

			ptpshift = PAGE_SHIFT + nlevels * 10;
			ptpindex = (gla >> ptpshift) & 0x3FF;
			pgsize = 1UL << ptpshift;

			ptpbase32 = ptp_hold(vcpu, ptpphys, PAGE_SIZE,
			    &cookie, &ptpl1, ptpgpa + ptpindex * sizeof(pte32),
			    gla, ngflags, &herr);

			if (ptpbase32 == NULL)
				goto hold_failed;

			pte32 = ptpbase32[ptpindex];

			if ((pte32 & PG_V) == 0 ||
			    (usermode && (pte32 & PG_U) == 0) ||
			    (writable && (pte32 & PG_RW) == 0)) {
				if (!check_only) {
					pfcode = pf_error_code(usermode, prot, 0,
					    pte32);
					goto inject_pf;
				}
				goto fault;
			}
			if ((pte32 & PG_U) == 0)
				laflags &= ~VM_NGPA_LA_US;
			if ((pte32 & PG_RW) == 0)
				laflags &= ~VM_NGPA_LA_RW;

			/*
			 * Emulate the x86 MMU's management of the accessed
			 * and dirty flags. While the accessed flag is set
			 * at every level of the page table, the dirty flag
			 * is only set at the last level providing the guest
			 * physical address. H2-AD: annotati, scritti dopo la
			 * traduzione finale (vedi ptp_commit).
			 */
			/* XXX must be ignored if CR4.PSE=0 */
			leaf = (nlevels == 0 || (pte32 & PG_PS) != 0);
			if (!check_only && (pte32 & PG_A) == 0) {
				ad = ptp_pend_add(pend, &npend, ptpgpa +
				    ptpindex * sizeof(pte32), ptpl1, pte32,
				    PG_A, true);
				if (ad == 2)
					goto restart;
				if (ad != 0)
					goto error;
			}

			if (leaf)
				break;

			ptpphys = pte32;
		}

		/* Set the dirty bit in the page table entry if necessary */
		if (!check_only && writable && (pte32 & PG_M) == 0) {
			ad = ptp_pend_add(pend, &npend, ptpgpa +
			    ptpindex * sizeof(pte32), ptpl1, pte32, PG_M, true);
			if (ad == 2)
				goto restart;
			if (ad != 0)
				goto error;
		}

		/* Zero out the lower 'ptpshift' bits */
		pte32 >>= ptpshift; pte32 <<= ptpshift;
		*gpa = pte32 | (gla & (pgsize - 1));
		/* H2b: anche in modo 32 bit il GPA e' dell'L2 (prima 'done'
		 * saltava la traduzione EPT12) */
		goto translate;
	}

	if (paging->paging_mode == PAGING_MODE_PAE) {
		/* Zero out the lower 5 bits and the upper 32 bits */
		ptpphys &= 0xffffffe0UL;

		ptpindex = (gla >> 30) & 0x3;

		ptpbase = ptp_hold(vcpu, ptpphys, sizeof(*ptpbase) * 4,
		    &cookie, &ptpl1, ptpphys + ptpindex * sizeof(*ptpbase),
		    gla, ngflags, &herr);  /* PDPTE: nessun A/D da scrivere */
		if (ptpbase == NULL)
			goto hold_failed;

		pte = ptpbase[ptpindex];

		if ((pte & PG_V) == 0) {
			if (!check_only) {
				pfcode = pf_error_code(usermode, prot, 0, pte);
				goto inject_pf;
			}
			goto fault;
		}

		ptpphys = pte;

		nlevels = 2;
	} else if (paging->paging_mode == PAGING_MODE_64_LA57) {
		nlevels = 5;
	} else {
		nlevels = 4;
	}

	while (--nlevels >= 0) {
		/* Zero out the lower 12 bits and the upper 12 bits */
		ptpphys >>= 12; ptpphys <<= 24; ptpphys >>= 12;
		ptpgpa = ptpphys;		/* GPA dell'L2: per A/D */

		ptpshift = PAGE_SHIFT + nlevels * 9;
		ptpindex = (gla >> ptpshift) & 0x1FF;
		pgsize = 1UL << ptpshift;

		ptpbase = ptp_hold(vcpu, ptpphys, PAGE_SIZE, &cookie, &ptpl1,
		    ptpgpa + ptpindex * sizeof(pte), gla, ngflags, &herr);
		if (ptpbase == NULL)
			goto hold_failed;

		pte = ptpbase[ptpindex];

		if ((pte & PG_V) == 0 ||
		    (usermode && (pte & PG_U) == 0) ||
		    (writable && (pte & PG_RW) == 0)) {
			if (!check_only) {
				pfcode = pf_error_code(usermode, prot, 0, pte);
				goto inject_pf;
			}
			goto fault;
		}
		if ((pte & PG_U) == 0)
			laflags &= ~VM_NGPA_LA_US;
		if ((pte & PG_RW) == 0)
			laflags &= ~VM_NGPA_LA_RW;
		if ((pte & PG_NX) != 0)
			laflags |= VM_NGPA_LA_XD;

		/* Set the accessed bit in the page table entry: H2-AD,
		 * annotato e scritto dopo la traduzione finale */
		if (!check_only && (pte & PG_A) == 0) {
			ad = ptp_pend_add(pend, &npend, ptpgpa +
			    ptpindex * sizeof(pte), ptpl1, pte, PG_A, false);
			if (ad == 2)
				goto restart;
			if (ad != 0)
				goto error;
		}

		if (nlevels > 0 && (pte & PG_PS) != 0) {
			if (pgsize > 1 * GB) {
				if (!check_only) {
					pfcode = pf_error_code(usermode, prot, 1,
					    pte);
					goto inject_pf;
				}
				goto fault;
			}
			break;
		}

		ptpphys = pte;
	}

	/* Set the dirty bit in the page table entry if necessary */
	if (!check_only && writable && (pte & PG_M) == 0) {
		ad = ptp_pend_add(pend, &npend, ptpgpa + ptpindex * sizeof(pte),
		    ptpl1, pte, PG_M, false);
		if (ad == 2)
			goto restart;
		if (ad != 0)
			goto error;
	}

	/* Zero out the lower 'ptpshift' bits and the upper 12 bits */
	pte >>= ptpshift; pte <<= (ptpshift + 12); pte >>= 12;
	*gpa = pte | (gla & (pgsize - 1));
translate:
	/* nested: il risultato e' un GPA dell'L2, chi lo usa vuole quello
	 * dell'L1 (vm_copy_setup -> vm_gpa_hold). Identita' fuori da un L2.
	 * H2: se l'EPT dell'L1 lo nega, violation per l'L1 e fault (sopra).
	 * H2-AD: PRIMA di scrivere qualunque A/D annotato: col diniego non si
	 * scrive nulla. Il GPA tradotto qui e' quello restituito: una modifica
	 * di EPT12 successiva non e' vista, come per la traduzione originale
	 * (che seguiva le scritture) e come per l'hardware. */
	herr = vm_nested_gpa(vcpu, *gpa, prot, gla,
	    ngflags | VM_NGPA_FINAL | laflags, &l1gpa);
	if (herr == EJUSTRETURN)
		goto nested_fault;
	if (herr != 0) {
		retval = EFAULT;
		goto done;
	}
	if (npend > 0) {
		ad = ptp_commit(vcpu, pend, npend, gla);
		if (ad == 1)
			goto fault;
		if (ad == 2)
			goto restart;
		if (ad != 0)
			goto error;
	}
	*gpa = l1gpa;
done:
	ptp_release(&cookie);
	KASSERT(retval == 0 || retval == EFAULT, ("%s: unexpected retval %d",
	    __func__, retval));
	return (retval);
inject_pf:
	/* #PF del guest (mai con check_only): gli A annotati dei livelli gia'
	 * percorsi si scrivono prima, come faceva il walk originale */
	if (npend > 0) {
		ad = ptp_commit(vcpu, pend, npend, gla);
		if (ad == 1)
			goto fault;
		if (ad == 2)
			goto restart;
		if (ad != 0)
			goto error;
	}
	vm_inject_pf(vcpu, pfcode, gla);
	goto fault;
hold_failed:
	if (herr != EJUSTRETURN)
		goto error;
nested_fault:
	/* H2: EPT violation (o misconfiguration) registrata per l'L1, che la
	 * ricevera' prima del prossimo ingresso in L2: niente eccezione al
	 * guest, niente errore di vm_run; l'istruzione riparte. H2-AD: nessun
	 * A/D annotato e' stato scritto */
	vm_restart_instruction(vcpu);
	goto fault;
error:
	retval = EFAULT;
	goto done;
fault:
	*guest_fault = 1;
	goto done;
}


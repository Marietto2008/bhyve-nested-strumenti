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
ptp_hold(struct vcpu *vcpu, vm_paddr_t ptpphys, size_t len, void **cookie)
{
	void *ptr;

	ptp_release(cookie);
	ptr = vm_gpa_hold(vcpu, ptpphys, len, VM_PROT_RW, cookie);
	return (ptr);
}

static int
_vm_gla2gpa(struct vcpu *vcpu, struct vm_guest_paging *paging,
    uint64_t gla, int prot, uint64_t *gpa, int *guest_fault, bool check_only)
{
	int nlevels, pfcode, ptpshift, ptpindex, retval, usermode, writable;
	u_int retries;
	uint64_t *ptpbase, ptpphys, pte, pgsize;
	uint32_t *ptpbase32, pte32;
	void *cookie;

	*guest_fault = 0;

	usermode = (paging->cpl == 3 ? 1 : 0);
	writable = prot & VM_PROT_WRITE;
	cookie = NULL;
	retval = 0;
	retries = 0;
restart:
	ptpphys = paging->cr3;		/* root of the page tables */
	ptp_release(&cookie);
	if (retries++ > 0)
		maybe_yield();

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
		goto done;
	}

	if (paging->paging_mode == PAGING_MODE_32) {
		nlevels = 2;
		while (--nlevels >= 0) {
			/* Zero out the lower 12 bits. */
			ptpphys &= ~0xfff;

			ptpbase32 = ptp_hold(vcpu, ptpphys, PAGE_SIZE,
			    &cookie);

			if (ptpbase32 == NULL)
				goto error;

			ptpshift = PAGE_SHIFT + nlevels * 10;
			ptpindex = (gla >> ptpshift) & 0x3FF;
			pgsize = 1UL << ptpshift;

			pte32 = ptpbase32[ptpindex];

			if ((pte32 & PG_V) == 0 ||
			    (usermode && (pte32 & PG_U) == 0) ||
			    (writable && (pte32 & PG_RW) == 0)) {
				if (!check_only) {
					pfcode = pf_error_code(usermode, prot, 0,
					    pte32);
					vm_inject_pf(vcpu, pfcode, gla);
				}
				goto fault;
			}

			/*
			 * Emulate the x86 MMU's management of the accessed
			 * and dirty flags. While the accessed flag is set
			 * at every level of the page table, the dirty flag
			 * is only set at the last level providing the guest
			 * physical address.
			 */
			if (!check_only && (pte32 & PG_A) == 0) {
				if (atomic_cmpset_32(&ptpbase32[ptpindex],
				    pte32, pte32 | PG_A) == 0) {
					goto restart;
				}
			}

			/* XXX must be ignored if CR4.PSE=0 */
			if (nlevels > 0 && (pte32 & PG_PS) != 0)
				break;

			ptpphys = pte32;
		}

		/* Set the dirty bit in the page table entry if necessary */
		if (!check_only && writable && (pte32 & PG_M) == 0) {
			if (atomic_cmpset_32(&ptpbase32[ptpindex],
			    pte32, pte32 | PG_M) == 0) {
				goto restart;
			}
		}

		/* Zero out the lower 'ptpshift' bits */
		pte32 >>= ptpshift; pte32 <<= ptpshift;
		*gpa = pte32 | (gla & (pgsize - 1));
		goto done;
	}

	if (paging->paging_mode == PAGING_MODE_PAE) {
		/* Zero out the lower 5 bits and the upper 32 bits */
		ptpphys &= 0xffffffe0UL;

		ptpbase = ptp_hold(vcpu, ptpphys, sizeof(*ptpbase) * 4,
		    &cookie);
		if (ptpbase == NULL)
			goto error;

		ptpindex = (gla >> 30) & 0x3;

		pte = ptpbase[ptpindex];

		if ((pte & PG_V) == 0) {
			if (!check_only) {
				pfcode = pf_error_code(usermode, prot, 0, pte);
				vm_inject_pf(vcpu, pfcode, gla);
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

		ptpbase = ptp_hold(vcpu, ptpphys, PAGE_SIZE, &cookie);
		if (ptpbase == NULL)
			goto error;

		ptpshift = PAGE_SHIFT + nlevels * 9;
		ptpindex = (gla >> ptpshift) & 0x1FF;
		pgsize = 1UL << ptpshift;

		pte = ptpbase[ptpindex];

		if ((pte & PG_V) == 0 ||
		    (usermode && (pte & PG_U) == 0) ||
		    (writable && (pte & PG_RW) == 0)) {
			if (!check_only) {
				pfcode = pf_error_code(usermode, prot, 0, pte);
				vm_inject_pf(vcpu, pfcode, gla);
			}
			goto fault;
		}

		/* Set the accessed bit in the page table entry */
		if (!check_only && (pte & PG_A) == 0) {
			if (atomic_cmpset_64(&ptpbase[ptpindex],
			    pte, pte | PG_A) == 0) {
				goto restart;
			}
		}

		if (nlevels > 0 && (pte & PG_PS) != 0) {
			if (pgsize > 1 * GB) {
				if (!check_only) {
					pfcode = pf_error_code(usermode, prot, 1,
					    pte);
					vm_inject_pf(vcpu, pfcode, gla);
				}
				goto fault;
			}
			break;
		}

		ptpphys = pte;
	}

	/* Set the dirty bit in the page table entry if necessary */
	if (!check_only && writable && (pte & PG_M) == 0) {
		if (atomic_cmpset_64(&ptpbase[ptpindex], pte, pte | PG_M) == 0)
			goto restart;
	}

	/* Zero out the lower 'ptpshift' bits and the upper 12 bits */
	pte >>= ptpshift; pte <<= (ptpshift + 12); pte >>= 12;
	*gpa = pte | (gla & (pgsize - 1));
done:
	ptp_release(&cookie);
	KASSERT(retval == 0 || retval == EFAULT, ("%s: unexpected retval %d",
	    __func__, retval));
	return (retval);
error:
	retval = EFAULT;
	goto done;
fault:
	*guest_fault = 1;
	goto done;
}


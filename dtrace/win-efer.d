#pragma D option quiet
#pragma D option switchrate=4hz
/* Claude 20/10/2026: l'EFER di L1 (Hyper-V) catturato al VMLAUNCH.
 * vmx_vcpu.nested +0x2b8; vmx_nested.l1_efer +0x4660 (18016, da DWARF). */
int go; int done;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; }
vmm:vmx:nested:eptviol /go && done < 3/
{
	this->n = *(uintptr_t *)(arg0 + 0x2b8);
	this->efer = *(uint64_t *)(this->n + 0x4660);
	printf("l1_efer=%#lx  SCE=%d LME=%d LMA=%d NXE=%d\n", this->efer,
	    (int)(this->efer & 1), (int)((this->efer >> 8) & 1),
	    (int)((this->efer >> 10) & 1), (int)((this->efer >> 11) & 1));
	done++;
}

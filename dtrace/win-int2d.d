#pragma D option quiet
#pragma D option switchrate=4hz
/*
 * Claude 20/10/2026 -- la LUNGHEZZA d'istruzione usata da L0 per reiniettare
 * int 0x2d. vmx_exit_save_idtvec (vmx.c) scrive VMCS_ENTRY_INST_LENGTH =
 * vmexit->inst_length per gli interrupt software rimasti in IDT-vectoring.
 * struct vm_exit: exitcode +0, inst_length +4, rip +8, exit_reason +20.
 * Siti di int 0x2d in ntoskrnl (bassi 12 bit): 0x792, 0x7b5, 0x7c3.
 * NB: in uscita la lunghezza ha senso solo se l'uscita avviene durante la
 * consegna di un evento software (SDM 27.2.4); qui si legge comunque tutto.
 */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; printf("T0 walltimestamp=%d\n", walltimestamp); }

fbt:vmm-restore:nested_l2_exit:entry
/go && ((*(uint64_t *)(arg1 + 8) & 0xfff) == 0x7c3 || (*(uint64_t *)(arg1 + 8) & 0xfff) == 0x7b5 ||
        (*(uint64_t *)(arg1 + 8) & 0xfff) == 0x792)/
{
	printf("%10d EXIT VP%d rip=%#lx reason=%d inst_length=%d\n", (timestamp - t0) / 1000,
	    *(int *)(arg0 + 704), *(uint64_t *)(arg1 + 8),
	    *(uint32_t *)(arg1 + 20) & 0xffff, *(int *)(arg1 + 4));
	@len[*(uint32_t *)(arg1 + 20) & 0xffff, *(int *)(arg1 + 4)] = count();
}
vmm:vmx:nested:diag_entry { self->ei = arg1 & 0xffffffff; self->rip = arg2; self->us = (timestamp - t0) / 1000; }
vmm:vmx:nested:diag_exit
{
	printf("%10d INJ  VP%d ei=%#x rip=%#lx -> usc reason=%d idtvec=%#x rip=%#lx\n",
	    self->us, (int)arg0, (int)self->ei, self->rip, (int)(arg1 & 0xffff),
	    (int)(arg1 >> 32), arg3);
}
vmm:vmx:nested:diag_more
{
	printf("%10s       ENTRY_INST_LENGTH=%d act=%d\n", "", (int)(arg2 >> 32), (int)(arg2 & 0xffffffff));
}
END { printa("  uscite ai siti int 0x2d: reason %d inst_length %d : %@d\n", @len); }

#pragma D option quiet
#pragma D option bufpolicy=ring
#pragma D option bufsize=64m

/*
 * Gli ULTIMI eventi prima dello stallo, IN ORDINE (Claude 18/10/2026).
 * Buffer circolare: si ferma dtrace (SIGINT) a stallo avvenuto e restano
 * gli eventi piu' recenti. Esclusi i fault EPT (motivo 48, ~270k/s sulla
 * CPU1 che azzera la RAM) per non sommergere il resto.
 * Offset: vmx_vcpu.vcpuid +704; struct vcpu.vcpuid +36; vlapic.vcpuid +16,
 * apic_page +24; LAPIC icr_lo +768 icr_hi +784 lvt_timer +800 icr_timer +896.
 */
vmm:vmx:exit:entry
/(*(uint32_t *)(arg2 + 20) & 0xffff) != 48/
{
	printf("%d cpu%d USCITA motivo=%d rip=%#lx qual=%#lx\n", timestamp, (int)arg1,
	    *(uint32_t *)(arg2 + 20) & 0xffff, (long)*(uint64_t *)(arg2 + 8),
	    (long)*(uint64_t *)(arg2 + 24));
}
vmm:vmx:nested:enter_l2 { printf("%d cpu%d ENTRA-L2\n", timestamp, *(int *)(arg0 + 704)); }
vmm:vmx:nested:reflect { printf("%d cpu%d RIFLESSA-L1\n", timestamp, *(int *)(arg0 + 704)); }
vmm:vmx:nested:chkev /arg2 != 0/
{
	printf("%d cpu%d CHKEV vett=%#x pin12=%#lx\n", timestamp, *(int *)(arg0 + 704), (int)arg3, (long)arg1);
}
fbt:vmm-restore:vlapic_icrtmr_write_handler:entry
{
	this->p = *(uintptr_t *)(arg0 + 24);
	printf("%d cpu%d TIMER icr=%u lvt=%#x\n", timestamp, *(int *)(arg0 + 16),
	    *(uint32_t *)(this->p + 896), *(uint32_t *)(this->p + 800));
}
fbt:vmm-restore:vlapic_callout_handler:entry { printf("%d cpu%d TIMER-SCATTA\n", timestamp, *(int *)(arg0 + 16)); }
fbt:vmm-restore:vlapic_icrlo_write_handler:entry
{
	this->p = *(uintptr_t *)(arg0 + 24);
	printf("%d cpu%d IPI icr_lo=%#x icr_hi=%#x\n", timestamp, *(int *)(arg0 + 16),
	    *(uint32_t *)(this->p + 768), *(uint32_t *)(this->p + 784));
}
fbt:vmm-restore:lapic_set_intr:entry { printf("%d cpu%d PENDENTE vett=%#x\n", timestamp, *(int *)(arg0 + 36), (int)arg1); }
fbt:vmm-restore:vcpu_notify_event:entry { printf("%d cpu%d NOTIFY\n", timestamp, *(int *)(arg0 + 36)); }
fbt:vmm-restore:vhpet_mmio_write:entry
{
	printf("%d cpu%d HPET-W off=%#lx val=%#lx\n", timestamp, *(int *)(arg0 + 36), (long)(arg1 & 0x3ff), (long)arg2);
}
fbt:vmm-restore:vhpet_timer_interrupt:entry { printf("%d HPET-IRQ timer=%d\n", timestamp, (int)arg1); }
fbt:vmm-restore:vioapic_mmio_write:entry
{
	printf("%d cpu%d IOAPIC-W off=%#lx val=%#lx\n", timestamp, *(int *)(arg0 + 36), (long)(arg1 & 0xff), (long)arg2);
}
fbt:vmm-restore:vm_inject_extint:entry { printf("%d cpu%d EXTINT\n", timestamp, *(int *)(arg0 + 36)); }

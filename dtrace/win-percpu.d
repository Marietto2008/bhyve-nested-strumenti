#pragma D option quiet
#pragma D option bufsize=16m
#pragma D option aggsize=16m
#pragma D option switchrate=10hz

/*
 * Linea del tempo PER CPU, al secondo (Claude 18/10/2026). Bugcheck 0x101
 * CLOCK_WATCHDOG_TIMEOUT sul processore 1 della root: la CPU1 sparisce ~12 s
 * prima del crash. Qui: ingressi in L2, riflessioni, uscite sintetiche (per
 * vettore), HLT, notify, interrupt resi pendenti (per vettore), timer del
 * vlapic dell'L1 (scritture ICR e scatti), slow path, motivi d'uscita.
 * Offset: vmx_vcpu.vcpuid +704; struct vcpu.vcpuid +36; vlapic.vcpuid +16,
 * apic_page +24; LAPIC icr_timer +896, lvt_timer +800.
 */
vmm:vmx:nested:enter_l2	{ @in[*(int *)(arg0 + 704)] = count(); }
vmm:vmx:nested:reflect	{ @rf[*(int *)(arg0 + 704)] = count(); }
vmm:vmx:nested:chkev /arg2 != 0/ { @sy[*(int *)(arg0 + 704), (int)arg3] = count(); }
vmm:vmx:nested:slowpath	{ @sp[*(int *)(arg0 + 704)] = count(); }
vmm:vmx:exit:entry	{ @ex[(int)arg1, *(uint32_t *)(arg2 + 20) & 0xffff] = count(); }
fbt:vmm-restore:vcpu_notify_event:entry { @nt[*(int *)(arg0 + 36)] = count(); }
fbt:vmm-restore:lapic_set_intr:entry { @pi[*(int *)(arg0 + 36), (int)arg1] = count(); }
fbt:vmm-restore:vlapic_callout_handler:entry { @co[*(int *)(arg0 + 16)] = count(); }
fbt:vmm-restore:vlapic_icrtmr_write_handler:entry
{
	this->p = *(uintptr_t *)(arg0 + 24);
	@icr[*(int *)(arg0 + 16), *(uint32_t *)(this->p + 896),
	    *(uint32_t *)(this->p + 800)] = count();
}

tick-1s
{
	printf("=== %Y\n", walltimestamp);
	printa("in-L2 cpu%d %@d\n", @in);
	printa("rifl  cpu%d %@d\n", @rf);
	printa("chkev cpu%d vett %#x: %@d\n", @sy);
	printa("slow  cpu%d %@d\n", @sp);
	printa("notif cpu%d %@d\n", @nt);
	printa("pend  cpu%d vett %#x: %@d\n", @pi);
	printa("tmr-scatta cpu%d %@d\n", @co);
	printa("tmr-icr cpu%d icr=%u lvt=%#x: %@d\n", @icr);
	printa("usc   cpu%d motivo %d: %@d\n", @ex);
	trunc(@in); trunc(@rf); trunc(@sy); trunc(@sp); trunc(@nt); trunc(@pi);
	trunc(@co); trunc(@icr); trunc(@ex);
}

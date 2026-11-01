#pragma D option quiet
#pragma D option bufsize=8m
#pragma D option switchrate=1hz
/* Interrupt dei dispositivi di L0 (MSI, es. disco AHCI) e se raggiungono l'L2 sotto Hyper-V.
 * lapic_intr_msi(vm, addr, msg): vettore = msg&0xff, dest = (addr>>12)&0xff. */
int go; int64_t t0;
vmm:vmx:nested:compose /!go/ { go = 1; t0 = timestamp; }
fbt:vmm-restore:lapic_intr_msi:entry /go/ { printf("%10d MSI da L0: vettore=%#x dest=%#x (addr=%#lx msg=%#lx)\n",
	(timestamp-t0)/1000, (int)(arg2 & 0xff), (int)((arg1 >> 12) & 0xff), arg1, arg2); @msi[arg2 & 0xff] = count(); }
fbt:vmm-restore:vioapic_assert_irq:entry /go/ { printf("%10d IOAPIC pin %d assert\n", (timestamp-t0)/1000, (int)arg1); }
fbt:vmm-restore:vlapic_set_intr_ready:entry /go/ { @irr[arg1] = count(); }
fbt:vmm-restore:vcpu_notify_event:entry /go/ { @nt = count(); }
vmm:vmx:nested:chkev /go && arg2/ { printf("%10d t%d chkev: interrupt in attesa per Hyper-V, vettore=%d\n", (timestamp-t0)/1000, tid, (int)arg3); @ce[arg3] = count(); }
vmm:vmx:nested:compose /go && (arg1 & 0x80000000)/ { @ev[arg1 & 0xff] = count(); }
tick-3s /go/ { printf("--- %d ms:\n", (timestamp-t0)/1000000);
	printa("   MSI L0 vettore %#x: %@d\n", @msi); printa("   IRR vettore %#x: %@d\n", @irr);
	printa("   chkev->L1 vettore %d: %@d\n", @ce); printa("   iniettato in L2 vettore %#x: %@d\n", @ev);
	printa("   notify totali: %@d\n", @nt); }

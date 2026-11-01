#pragma D option quiet
#pragma D option bufsize=64m
#pragma D option switchrate=10hz
/* Windows 11 + Hyper-V (sonde SDT di ba27acc): eventi dell'L1 mentre gira la root e cosa
 * Hyper-V inietta. Stampa i CAMBI di decisione (non ogni controllo) e ogni ingresso con evento. */
int go; int64_t t0; uint64_t lpin; int lpend, lvec;
vmm:vmx:nested:compose /!go/ { go = 1; t0 = timestamp; }
vmm:vmx:nested:compose /go/ {
	printf("%9d INGRESSO L2: intr12=%#lx pin12=%#lx proc12=%#lx rflags=%#lx interr=%#lx%s\n",
	    (timestamp - t0)/1000, arg1, arg2, arg3, arg4 >> 32, arg4 & 0xffffffff,
	    (arg1 & 0x80000000) ? "  <-- EVENTO" : "");
}
vmm:vmx:nested:chkev /go && (arg1 != lpin || arg2 != lpend || arg3 != lvec)/ {
	printf("%9d chkev: pin12=%#lx in_attesa=%d vettore=%d\n", (timestamp - t0)/1000, arg1, arg2, arg3);
	lpin = arg1; lpend = arg2; lvec = arg3;
}
vmm:vmx:nested:chkev /go/ { @chk[arg2] = count(); }
fbt:vmm-restore:vlapic_callout_handler:entry /go/ { printf("%9d timer APIC di Hyper-V scatta\n", (timestamp - t0)/1000); }
vmm:vmx:nested:reflect /go/ { @rf = count(); }
tick-1s /go/ { printa("    controlli: in_attesa=%d -> %@d\n", @chk); printa("    riflessioni: %@d\n", @rf); }
tick-1s /go && timestamp - t0 > 6000000000/ { exit(0); }

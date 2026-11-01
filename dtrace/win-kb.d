#pragma D option quiet
#pragma D option switchrate=1hz
/* Claude 21/10/2026 -- prova A/B dell'INVEPT selettivo (parere #24): uscite EPT
 * violation dall'L2, INVEPT dell'L1, radici svuotate (solo col modulo nuovo:
 * sonda invept), ogni 60 s e cumulativo. */
int64_t t0;
BEGIN { t0 = timestamp; }
fbt::nested_l2_exit:entry /(*(uint32_t *)(arg1 + 0x14) & 0xffff) == 48/ { @c["EPT violation"] = count(); @m["EPT violation"] = count(); }
fbt::vmx_vept_invept:entry { @c["INVEPT"] = count(); @m["INVEPT"] = count(); }
vmm:vmx:nested:invept { @w = sum(arg3); @wt[(int)arg1] = count(); }
tick-60s
{
	printf("=== %d min %Y\n", (timestamp - t0) / 60000000000, walltimestamp);
	printa("  ultimo minuto %-16s %@d\n", @m); clear(@m);
	printa("  cumulativo    %-16s %@d\n", @c);
	printa("  radici svuotate %@d\n", @w);
	printa("  INVEPT tipo %d : %@d\n", @wt);
}

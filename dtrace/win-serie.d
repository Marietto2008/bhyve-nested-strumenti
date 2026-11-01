#pragma D option quiet
#pragma D option switchrate=2hz
/* Claude 20/10/2026: serie di regressione (pareri #21/#22). Leggera: #UD in L2, VMfail, ingressi. */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }
vmm:vmx:nested:enter_l2 { @ingr = count(); }
vmm:vmx:nested:ud_a { @ud = count(); printf("%d ms #UD in L2 VP%d\n", (timestamp - t0)/1000000, (int)arg0); }
fbt::nested_vmx_result:entry /arg1 != 0/ { @vf[(int)arg1] = count(); printf("%d ms VMFAIL err=%d\n", (timestamp - t0)/1000000, (int)arg1); }
fbt::nested_vmfail_invalid:entry { @vfi = count(); }
vmm:vmx:nested:vmcs12mem /arg2 >= 8/ { @memerr[(int)arg2] = count(); }
END { printa("ingressi %@d\n", @ingr); printa("ud %@d\n", @ud); printa("vmfail err=%d %@d\n", @vf); printa("vmfail_invalid %@d\n", @vfi); printa("memerr op=%d %@d\n", @memerr); }

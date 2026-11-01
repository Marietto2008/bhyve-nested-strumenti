#pragma D option quiet
#pragma D option switchrate=4hz
/*
 * Claude 20/10/2026 -- i PARAMETRI del bugcheck della root. La schermata blu
 * mostra solo il codice; Windows sotto Hyper-V scrive codice e 4 parametri
 * negli MSR di crash sintetici HV_X64_MSR_CRASH_P0..P4 (0x40000100-0x40000104)
 * e poi CRASH_CTL (0x40000105). Sono WRMSR dell'L2 riflessi all'L1: li vede
 * nested_l2_exit (vcpu: vcpuid +704, ctx +0x68: rdx +16, rcx +24, rax +48).
 * In piu', ogni MSR >= 0x40000100 scritto dalla root, per non perdere varianti.
 */
int go; int64_t t0;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; printf("T0 walltimestamp=%d\n", walltimestamp); }

fbt:vmm-restore:nested_l2_exit:entry
/go && (*(uint32_t *)(arg1 + 20) & 0xffff) == 32/
{
	this->rcx = *(uint64_t *)(arg0 + 0x68 + 24) & 0xffffffff;
	this->val = ((*(uint64_t *)(arg0 + 0x68 + 16) & 0xffffffff) << 32) |
	    (*(uint64_t *)(arg0 + 0x68 + 48) & 0xffffffff);
}
fbt:vmm-restore:nested_l2_exit:entry
/go && (*(uint32_t *)(arg1 + 20) & 0xffff) == 32 && this->rcx >= 0x40000100 && this->rcx <= 0x400001ff/
{
	printf("%10d VP%d WRMSR %#x = %#lx  rip=%#lx\n", (timestamp - t0) / 1000,
	    *(int *)(arg0 + 704), (int)this->rcx, this->val, *(uint64_t *)(arg1 + 8));
}
/* KeBugCheck spesso passa anche da un hypercall: codice nei bit 15:0 di RCX */
fbt:vmm-restore:nested_l2_exit:entry
/go && (*(uint32_t *)(arg1 + 20) & 0xffff) == 18/
{
	@hc[*(int *)(arg0 + 704), *(uint64_t *)(arg0 + 0x68 + 24) & 0xffff] = count();
}
vmm:vmx:nested:diag_exit { @tick_ult = max((timestamp - t0) / 1000); }
tick-5s /go/ { printa("  ultimo tick %@d us\n", @tick_ult); }
END { printa("  hypercall VP%d codice %#x : %@d\n", @hc); }

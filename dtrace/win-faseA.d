#pragma D option quiet
#pragma D option bufsize=32m
#pragma D option switchrate=2hz
#pragma D option dynvarsize=32m
/*
 * Claude 20/10/2026 -- Fase A del parere #23 di Astra: carico prolungato in WSL2,
 * 2 vCPU, baseline d6ee1c3. Ogni 60 s un riepilogo cumulativo:
 *  - VMfail Valid (per err e istruzione) / Invalid; VM-entry fallite; #UD in L2
 *  - VMCS12: salvati/caricati/sfratti (launched)/corrotti/non mappabili; nfields max
 *  - ingressi in L2, riflessioni all'L1, uscite da L2 per motivo
 *  - EPT: violazioni shadow e riempimenti
 *  - latenza dei rinvii degli interrupt dell'L1 PER EVENTO: dal primo rinvio di
 *    (vCPU, vettore) a vlapic_intr_accepted di quel vettore su quel vCPU
 *    (copre l'acknowledge-on-exit e l'iniezione successiva)
 * Offset: vmx_vcpu.vcpuid +0x2c0, .vcpu +8; vcpu.exitinfo +0x88; vm_exit.reason +0x14;
 * vlapic.vcpuid +0x10.  Prima: sysctl hw.vmm.vmx.diag_ud=1
 */
int go; int64_t t0;
int64_t aperto[int, int];

vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; printf("T0 wall=%Y\n", walltimestamp); }
vmm:vmx:nested:enter_l2 { @n["ingressi L2"] = count(); }
vmm:vmx:nested:reflect { @n["riflessioni all'L1"] = count(); }
vmm:vmx:nested:eptviol { @n["EPT violation shadow"] = count(); }
vmm:vmx:nested:shadow_fill { @n["shadow EPT fill"] = count(); }
vmm:vmx:nested:vmfail { @n["VM-entry fallite"] = count(); printf("%d s !!! VM-entry fallita\n", (timestamp - t0)/1000000000); }
vmm:vmx:nested:ud_a { @n["#UD in L2"] = count(); printf("%d s !!! #UD in L2 VP%d\n", (timestamp - t0)/1000000000, (int)arg0); }

fbt::vmx_nested_exit:entry { self->rs = *(uint32_t *)(*(uintptr_t *)(arg0 + 8) + 0x88 + 0x14) & 0xffff; }
fbt::nested_vmx_result:entry /arg1 != 0/
{ @vf[(int)arg1, self->rs] = count(); printf("%d s !!! VMfailValid err=%d istr=%d VP%d\n", (timestamp - t0)/1000000000, (int)arg1, self->rs, *(int *)(arg0 + 0x2c0)); }
fbt::nested_vmfail_invalid:entry { @n["VMfailInvalid"] = count(); printf("%d s !!! VMfailInvalid\n", (timestamp - t0)/1000000000); }

fbt::nested_l2_exit:entry { @l2x[*(uint32_t *)(arg1 + 0x14) & 0xffff] = count(); }

vmm:vmx:nested:vmcs12mem { @mem[(int)arg2] = count(); }
vmm:vmx:nested:vmcs12mem /arg2 >= 1 && arg2 <= 3/ { @nfmax = max((int)arg3); }
vmm:vmx:nested:vmcs12mem /arg2 == 2 && arg4 == 1/ { @n["sfratti di VMCS12 launched"] = count(); }
vmm:vmx:nested:vmcs12mem /arg2 >= 8/
{ printf("%d s !!! VMCS12 op=%d gpa=%#lx n=%d VP%d\n", (timestamp - t0)/1000000000, (int)arg2, arg1, (int)arg3, (int)arg0); }

/* latenza per evento dei rinvii */
vmm:vmx:nested:defer /go && aperto[(int)arg0, (int)arg3] == 0/
{ aperto[(int)arg0, (int)arg3] = timestamp; @rk[(int)arg1] = count(); }
fbt::vlapic_intr_accepted:entry /aperto[*(int *)(arg0 + 0x10), (int)arg1]/
{
	this->v = *(int *)(arg0 + 0x10);
	this->d = (timestamp - aperto[this->v, (int)arg1]) / 1000;
	@lat = quantize(this->d); @latmax = max(this->d); @latn = count();
	@latvec[(int)arg1] = max(this->d);
	if (this->d > 5000)
		printf("%d s RINVIO LUNGO VP%d vett=%#x %d us\n", (timestamp - t0)/1000000000, this->v, (int)arg1, this->d);
	aperto[this->v, (int)arg1] = 0;
}

tick-60s /go/
{
	printf("=== %d min  %Y\n", (timestamp - t0)/60000000000, walltimestamp);
	printa("  %-28s %@d\n", @n);
	printa("  VMfailValid err=%d istr=%d : %@d\n", @vf);
	printa("  VMCS12 op=%d : %@d\n", @mem);
	printa("  nfields max salvato %@d\n", @nfmax);
	printa("  rinvii kind=%d : %@d\n", @rk);
	printa("  rinvii chiusi %@d", @latn); printa("  latenza max %@d us\n", @latmax);
	printa("  latenza max vettore %#x : %@d us\n", @latvec);
	printa("  uscite da L2 motivo %d : %@d\n", @l2x);
}
tick-30min /go/ { printa("  distribuzione latenza rinvii (us): %@d\n", @lat); }

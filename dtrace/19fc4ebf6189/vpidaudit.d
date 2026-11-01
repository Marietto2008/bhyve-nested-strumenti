#pragma D option quiet
#pragma D option switchrate=10hz
#pragma D option aggrate=10hz
#pragma D option dynvarsize=16m
/* Claude 24/10/2026: COPIA per il modulo 19fc4ebf6189 (shadow VMCS v2): vmx_nested.vept_eptp12 +17792
 * (era +17760) ed exit_insn_info +0x46c8 (era +0x46a8), dal DWARF; vmx_vcpu invariato. */
/*
 * Claude 24/10/2026 -- parere #45 §2: audit passivo del ciclo di vita VPID01/VPID02 prima
 * della correzione delle false migrazioni. Per vCPU (vmx_vcpu.vcpuid +704):
 *  - CPU fisiche su cui entra in L2 (vmm:vmx:nested:enter_l2) e migrazioni VERE: CPU diversa
 *    dal precedente ingresso in L2 dello stesso vCPU;
 *  - cambi di VMCS12 corrente (vmx_nested.current_vmcs12 +16) fra due ingressi in L2
 *    consecutivi = Hyper-V passa a un altro VP sullo stesso LP; il VPID02 e' unico per vCPU;
 *  - INVVPID dell'L1 (motivo 53 nel percorso lento, vmx_nested_exit) e INVEPT (50).
 * Ogni 10 s i totali dell'intervallo; alla fine (o ogni 60 s) l'insieme cumulativo delle
 * CPU per vCPU e i VMCS12 distinti.
 * Offset dal DWARF del modulo 0572294: vmx_vcpu.nested +696, .vcpuid +704, .vcpu +8;
 * vcpu.exitinfo +136, vm_exit.u.vmx.exit_reason +20.
 */
int last12[int];
int lastc[int];
vmm:vmx:nested:enter_l2
{
	this->n = *(uintptr_t *)(arg0 + 696);
	this->m = *(uint64_t *)(this->n + 16);
	this->id = *(int *)(arg0 + 704);
	@ent[this->id] = count();
	@sw[this->id] = sum(last12[this->id] != 0 && last12[this->id] != (int)(this->m >> 12));
	last12[this->id] = (int)(this->m >> 12);
	@mig[this->id] = sum(lastc[this->id] != 0 && lastc[this->id] != cpu + 1);
	lastc[this->id] = cpu + 1;
	@cpus[this->id, cpu] = count();
	@vm12[this->id, this->m] = count();
}
fbt::vmx_nested_exit:entry
/(*(uint32_t *)(*(uintptr_t *)(arg0 + 8) + 136 + 20) & 0xffff) == 53/
{
	@inv[*(int *)(arg0 + 704)] = count();
}
fbt::vmx_nested_exit:entry
/(*(uint32_t *)(*(uintptr_t *)(arg0 + 8) + 136 + 20) & 0xffff) == 50/
{
	@invept[*(int *)(arg0 + 704)] = count();
}
tick-10s
{
	printf("T %d\n", walltimestamp);
	printa("  vcpu %d ingressi_L2 %@d cambi_vmcs12 %@d migrazioni_vere %@d\n", @ent, @sw, @mig);
	printa("  vcpu %d invvpid_L1 %@d\n", @inv);
	printa("  vcpu %d invept_L1 %@d\n", @invept);
	trunc(@ent); trunc(@sw); trunc(@mig); trunc(@inv); trunc(@invept);
}
tick-60s
{
	printf("C %d\n", walltimestamp);
	printa("  cpu vcpu %d cpu %d n %@d\n", @cpus);
	printa("  vmcs12 vcpu %d %#lx n %@d\n", @vm12);
}

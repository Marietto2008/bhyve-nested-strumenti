/*
 * Claude 25/10/2026 -- parere #50 §4: rendere discriminante vmx_vpid_crossvm_test. Per ogni stato
 * nested: VPID02 assegnato, riuso dello stesso numero da una VM precedente, CPU del primo ingresso
 * in L2 (vpid02_lastcpu1 == 0, quando il tracciamento esegue il flush del primo uso) e liberazione.
 * Offset dal DWARF del modulo 22ad8106199e (vmx_vcpu.nested +0x2b8, .vcpuid +0x2c0;
 * vmx_nested.in_l2 +0x1, .vpid2 +0x4588, .vpid_track +0x458f, .vpid02_off +0x4590,
 * .vpid02_lastcpu1 +0x4598). Valgono SOLO per questo modulo.
 */
#pragma D option quiet

int visto[int];

fbt:vmm-restore:vmx_nested_init:entry
{
	self->v = arg0;
}

fbt:vmm-restore:vmx_nested_init:return
/self->v/
{
	this->n = *(uint64_t *)(self->v + 0x2b8);
	this->vp = this->n ? *(uint16_t *)(this->n + 0x4588) : 0;
	printf("%Y init vcpu%d vpid02=%d track=%d off=%d riuso=%s cpu=%d\n", walltimestamp,
	    *(int *)(self->v + 0x2c0), this->vp,
	    this->n ? *(uint8_t *)(this->n + 0x458f) : 0,
	    this->n ? *(uint8_t *)(this->n + 0x4590) : 0,
	    visto[this->vp] ? "SI" : "no", cpu);
	visto[this->vp] = 1;
	self->v = 0;
}

fbt:vmm-restore:vmx_run:entry
{
	this->n = *(uint64_t *)(arg0 + 0x2b8);
}

fbt:vmm-restore:vmx_run:entry
/this->n && *(uint8_t *)(this->n + 0x1) && *(int *)(this->n + 0x4598) == 0/
{
	printf("%Y primo ingresso in L2: vpid02=%d cpu=%d\n", walltimestamp,
	    *(uint16_t *)(this->n + 0x4588), cpu);
}

fbt:vmm-restore:vmx_nested_free:entry
/ *(uint64_t *)(arg0 + 0x2b8) != 0 /
{
	printf("%Y libera vpid02=%d\n", walltimestamp,
	    *(uint16_t *)(*(uint64_t *)(arg0 + 0x2b8) + 0x4588));
}

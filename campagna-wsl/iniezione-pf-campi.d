#!/usr/sbin/dtrace -qs
/* Generato. Offset dal DWARF di vmx_nested.o ricompilato con -g (obj-diagpf-dwarf):
 * vmx_vcpu.nested +696, vmx_nested.current_vmcs12 +16, cache[4] +24 passo 4384,
 * vmcs12_cache.fields +32 (enc u32, val u64, passo 16), nfields +4128.
 * A ogni ingresso in L2 in cui l'L1 inietta un #PF: i campi del VMCS12 che
 * l'L1 ha letto dall'uscita precedente. */
#pragma D option bufsize=16m
#pragma D option dynvarsize=16m
vmm:vmx:nested:veptrefl
{ self->gpa = arg2; self->qual = arg3; self->t = timestamp; }

vmm:vmx:nested:compose
/(arg1 & 0x800007ff) == 0x8000030e/
{
	self->pf = 1;
	self->nst = *(uintptr_t *)(arg0 + 696);
	self->cur = *(uint64_t *)(self->nst + 16);
	self->c = (uintptr_t)0;
	self->c = *(uint64_t *)(self->nst + 24 + 4384*0) == self->cur ? self->nst + 24 + 4384*0 : self->c;
	self->c = *(uint64_t *)(self->nst + 24 + 4384*1) == self->cur ? self->nst + 24 + 4384*1 : self->c;
	self->c = *(uint64_t *)(self->nst + 24 + 4384*2) == self->cur ? self->nst + 24 + 4384*2 : self->c;
	self->c = *(uint64_t *)(self->nst + 24 + 4384*3) == self->cur ? self->nst + 24 + 4384*3 : self->c;
	self->nf = self->c ? *(int *)(self->c + 4128) : 0;
	printf("\n%Y.%09d INIEZIONE #PF info=%x vcpu%d vmcs12=%x nfields=%d | ultima veptrefl gpa=%x qual=%x %d us prima\n",
	    walltimestamp, walltimestamp % 1000000000, arg1, *(int *)(arg0 + 704), self->cur, self->nf,
	    self->gpa, self->qual, self->t ? (timestamp - self->t) / 1000 : -1);
}
vmm:vmx:nested:compose
/self->pf && self->nf > 0/
{ this->e = *(uint32_t *)(self->c + 32 + 16*0); }
vmm:vmx:nested:compose
/self->pf && self->nf > 0 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*0 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 1/
{ this->e = *(uint32_t *)(self->c + 32 + 16*1); }
vmm:vmx:nested:compose
/self->pf && self->nf > 1 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*1 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 2/
{ this->e = *(uint32_t *)(self->c + 32 + 16*2); }
vmm:vmx:nested:compose
/self->pf && self->nf > 2 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*2 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 3/
{ this->e = *(uint32_t *)(self->c + 32 + 16*3); }
vmm:vmx:nested:compose
/self->pf && self->nf > 3 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*3 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 4/
{ this->e = *(uint32_t *)(self->c + 32 + 16*4); }
vmm:vmx:nested:compose
/self->pf && self->nf > 4 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*4 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 5/
{ this->e = *(uint32_t *)(self->c + 32 + 16*5); }
vmm:vmx:nested:compose
/self->pf && self->nf > 5 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*5 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 6/
{ this->e = *(uint32_t *)(self->c + 32 + 16*6); }
vmm:vmx:nested:compose
/self->pf && self->nf > 6 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*6 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 7/
{ this->e = *(uint32_t *)(self->c + 32 + 16*7); }
vmm:vmx:nested:compose
/self->pf && self->nf > 7 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*7 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 8/
{ this->e = *(uint32_t *)(self->c + 32 + 16*8); }
vmm:vmx:nested:compose
/self->pf && self->nf > 8 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*8 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 9/
{ this->e = *(uint32_t *)(self->c + 32 + 16*9); }
vmm:vmx:nested:compose
/self->pf && self->nf > 9 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*9 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 10/
{ this->e = *(uint32_t *)(self->c + 32 + 16*10); }
vmm:vmx:nested:compose
/self->pf && self->nf > 10 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*10 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 11/
{ this->e = *(uint32_t *)(self->c + 32 + 16*11); }
vmm:vmx:nested:compose
/self->pf && self->nf > 11 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*11 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 12/
{ this->e = *(uint32_t *)(self->c + 32 + 16*12); }
vmm:vmx:nested:compose
/self->pf && self->nf > 12 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*12 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 13/
{ this->e = *(uint32_t *)(self->c + 32 + 16*13); }
vmm:vmx:nested:compose
/self->pf && self->nf > 13 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*13 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 14/
{ this->e = *(uint32_t *)(self->c + 32 + 16*14); }
vmm:vmx:nested:compose
/self->pf && self->nf > 14 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*14 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 15/
{ this->e = *(uint32_t *)(self->c + 32 + 16*15); }
vmm:vmx:nested:compose
/self->pf && self->nf > 15 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*15 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 16/
{ this->e = *(uint32_t *)(self->c + 32 + 16*16); }
vmm:vmx:nested:compose
/self->pf && self->nf > 16 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*16 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 17/
{ this->e = *(uint32_t *)(self->c + 32 + 16*17); }
vmm:vmx:nested:compose
/self->pf && self->nf > 17 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*17 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 18/
{ this->e = *(uint32_t *)(self->c + 32 + 16*18); }
vmm:vmx:nested:compose
/self->pf && self->nf > 18 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*18 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 19/
{ this->e = *(uint32_t *)(self->c + 32 + 16*19); }
vmm:vmx:nested:compose
/self->pf && self->nf > 19 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*19 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 20/
{ this->e = *(uint32_t *)(self->c + 32 + 16*20); }
vmm:vmx:nested:compose
/self->pf && self->nf > 20 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*20 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 21/
{ this->e = *(uint32_t *)(self->c + 32 + 16*21); }
vmm:vmx:nested:compose
/self->pf && self->nf > 21 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*21 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 22/
{ this->e = *(uint32_t *)(self->c + 32 + 16*22); }
vmm:vmx:nested:compose
/self->pf && self->nf > 22 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*22 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 23/
{ this->e = *(uint32_t *)(self->c + 32 + 16*23); }
vmm:vmx:nested:compose
/self->pf && self->nf > 23 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*23 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 24/
{ this->e = *(uint32_t *)(self->c + 32 + 16*24); }
vmm:vmx:nested:compose
/self->pf && self->nf > 24 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*24 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 25/
{ this->e = *(uint32_t *)(self->c + 32 + 16*25); }
vmm:vmx:nested:compose
/self->pf && self->nf > 25 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*25 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 26/
{ this->e = *(uint32_t *)(self->c + 32 + 16*26); }
vmm:vmx:nested:compose
/self->pf && self->nf > 26 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*26 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 27/
{ this->e = *(uint32_t *)(self->c + 32 + 16*27); }
vmm:vmx:nested:compose
/self->pf && self->nf > 27 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*27 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 28/
{ this->e = *(uint32_t *)(self->c + 32 + 16*28); }
vmm:vmx:nested:compose
/self->pf && self->nf > 28 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*28 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 29/
{ this->e = *(uint32_t *)(self->c + 32 + 16*29); }
vmm:vmx:nested:compose
/self->pf && self->nf > 29 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*29 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 30/
{ this->e = *(uint32_t *)(self->c + 32 + 16*30); }
vmm:vmx:nested:compose
/self->pf && self->nf > 30 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*30 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 31/
{ this->e = *(uint32_t *)(self->c + 32 + 16*31); }
vmm:vmx:nested:compose
/self->pf && self->nf > 31 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*31 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 32/
{ this->e = *(uint32_t *)(self->c + 32 + 16*32); }
vmm:vmx:nested:compose
/self->pf && self->nf > 32 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*32 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 33/
{ this->e = *(uint32_t *)(self->c + 32 + 16*33); }
vmm:vmx:nested:compose
/self->pf && self->nf > 33 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*33 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 34/
{ this->e = *(uint32_t *)(self->c + 32 + 16*34); }
vmm:vmx:nested:compose
/self->pf && self->nf > 34 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*34 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 35/
{ this->e = *(uint32_t *)(self->c + 32 + 16*35); }
vmm:vmx:nested:compose
/self->pf && self->nf > 35 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*35 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 36/
{ this->e = *(uint32_t *)(self->c + 32 + 16*36); }
vmm:vmx:nested:compose
/self->pf && self->nf > 36 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*36 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 37/
{ this->e = *(uint32_t *)(self->c + 32 + 16*37); }
vmm:vmx:nested:compose
/self->pf && self->nf > 37 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*37 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 38/
{ this->e = *(uint32_t *)(self->c + 32 + 16*38); }
vmm:vmx:nested:compose
/self->pf && self->nf > 38 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*38 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 39/
{ this->e = *(uint32_t *)(self->c + 32 + 16*39); }
vmm:vmx:nested:compose
/self->pf && self->nf > 39 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*39 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 40/
{ this->e = *(uint32_t *)(self->c + 32 + 16*40); }
vmm:vmx:nested:compose
/self->pf && self->nf > 40 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*40 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 41/
{ this->e = *(uint32_t *)(self->c + 32 + 16*41); }
vmm:vmx:nested:compose
/self->pf && self->nf > 41 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*41 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 42/
{ this->e = *(uint32_t *)(self->c + 32 + 16*42); }
vmm:vmx:nested:compose
/self->pf && self->nf > 42 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*42 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 43/
{ this->e = *(uint32_t *)(self->c + 32 + 16*43); }
vmm:vmx:nested:compose
/self->pf && self->nf > 43 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*43 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 44/
{ this->e = *(uint32_t *)(self->c + 32 + 16*44); }
vmm:vmx:nested:compose
/self->pf && self->nf > 44 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*44 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 45/
{ this->e = *(uint32_t *)(self->c + 32 + 16*45); }
vmm:vmx:nested:compose
/self->pf && self->nf > 45 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*45 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 46/
{ this->e = *(uint32_t *)(self->c + 32 + 16*46); }
vmm:vmx:nested:compose
/self->pf && self->nf > 46 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*46 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 47/
{ this->e = *(uint32_t *)(self->c + 32 + 16*47); }
vmm:vmx:nested:compose
/self->pf && self->nf > 47 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*47 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 48/
{ this->e = *(uint32_t *)(self->c + 32 + 16*48); }
vmm:vmx:nested:compose
/self->pf && self->nf > 48 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*48 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 49/
{ this->e = *(uint32_t *)(self->c + 32 + 16*49); }
vmm:vmx:nested:compose
/self->pf && self->nf > 49 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*49 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 50/
{ this->e = *(uint32_t *)(self->c + 32 + 16*50); }
vmm:vmx:nested:compose
/self->pf && self->nf > 50 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*50 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 51/
{ this->e = *(uint32_t *)(self->c + 32 + 16*51); }
vmm:vmx:nested:compose
/self->pf && self->nf > 51 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*51 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 52/
{ this->e = *(uint32_t *)(self->c + 32 + 16*52); }
vmm:vmx:nested:compose
/self->pf && self->nf > 52 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*52 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 53/
{ this->e = *(uint32_t *)(self->c + 32 + 16*53); }
vmm:vmx:nested:compose
/self->pf && self->nf > 53 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*53 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 54/
{ this->e = *(uint32_t *)(self->c + 32 + 16*54); }
vmm:vmx:nested:compose
/self->pf && self->nf > 54 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*54 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 55/
{ this->e = *(uint32_t *)(self->c + 32 + 16*55); }
vmm:vmx:nested:compose
/self->pf && self->nf > 55 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*55 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 56/
{ this->e = *(uint32_t *)(self->c + 32 + 16*56); }
vmm:vmx:nested:compose
/self->pf && self->nf > 56 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*56 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 57/
{ this->e = *(uint32_t *)(self->c + 32 + 16*57); }
vmm:vmx:nested:compose
/self->pf && self->nf > 57 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*57 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 58/
{ this->e = *(uint32_t *)(self->c + 32 + 16*58); }
vmm:vmx:nested:compose
/self->pf && self->nf > 58 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*58 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 59/
{ this->e = *(uint32_t *)(self->c + 32 + 16*59); }
vmm:vmx:nested:compose
/self->pf && self->nf > 59 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*59 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 60/
{ this->e = *(uint32_t *)(self->c + 32 + 16*60); }
vmm:vmx:nested:compose
/self->pf && self->nf > 60 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*60 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 61/
{ this->e = *(uint32_t *)(self->c + 32 + 16*61); }
vmm:vmx:nested:compose
/self->pf && self->nf > 61 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*61 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 62/
{ this->e = *(uint32_t *)(self->c + 32 + 16*62); }
vmm:vmx:nested:compose
/self->pf && self->nf > 62 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*62 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 63/
{ this->e = *(uint32_t *)(self->c + 32 + 16*63); }
vmm:vmx:nested:compose
/self->pf && self->nf > 63 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*63 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 64/
{ this->e = *(uint32_t *)(self->c + 32 + 16*64); }
vmm:vmx:nested:compose
/self->pf && self->nf > 64 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*64 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 65/
{ this->e = *(uint32_t *)(self->c + 32 + 16*65); }
vmm:vmx:nested:compose
/self->pf && self->nf > 65 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*65 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 66/
{ this->e = *(uint32_t *)(self->c + 32 + 16*66); }
vmm:vmx:nested:compose
/self->pf && self->nf > 66 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*66 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 67/
{ this->e = *(uint32_t *)(self->c + 32 + 16*67); }
vmm:vmx:nested:compose
/self->pf && self->nf > 67 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*67 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 68/
{ this->e = *(uint32_t *)(self->c + 32 + 16*68); }
vmm:vmx:nested:compose
/self->pf && self->nf > 68 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*68 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 69/
{ this->e = *(uint32_t *)(self->c + 32 + 16*69); }
vmm:vmx:nested:compose
/self->pf && self->nf > 69 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*69 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 70/
{ this->e = *(uint32_t *)(self->c + 32 + 16*70); }
vmm:vmx:nested:compose
/self->pf && self->nf > 70 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*70 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 71/
{ this->e = *(uint32_t *)(self->c + 32 + 16*71); }
vmm:vmx:nested:compose
/self->pf && self->nf > 71 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*71 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 72/
{ this->e = *(uint32_t *)(self->c + 32 + 16*72); }
vmm:vmx:nested:compose
/self->pf && self->nf > 72 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*72 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 73/
{ this->e = *(uint32_t *)(self->c + 32 + 16*73); }
vmm:vmx:nested:compose
/self->pf && self->nf > 73 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*73 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 74/
{ this->e = *(uint32_t *)(self->c + 32 + 16*74); }
vmm:vmx:nested:compose
/self->pf && self->nf > 74 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*74 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 75/
{ this->e = *(uint32_t *)(self->c + 32 + 16*75); }
vmm:vmx:nested:compose
/self->pf && self->nf > 75 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*75 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 76/
{ this->e = *(uint32_t *)(self->c + 32 + 16*76); }
vmm:vmx:nested:compose
/self->pf && self->nf > 76 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*76 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 77/
{ this->e = *(uint32_t *)(self->c + 32 + 16*77); }
vmm:vmx:nested:compose
/self->pf && self->nf > 77 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*77 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 78/
{ this->e = *(uint32_t *)(self->c + 32 + 16*78); }
vmm:vmx:nested:compose
/self->pf && self->nf > 78 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*78 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 79/
{ this->e = *(uint32_t *)(self->c + 32 + 16*79); }
vmm:vmx:nested:compose
/self->pf && self->nf > 79 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*79 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 80/
{ this->e = *(uint32_t *)(self->c + 32 + 16*80); }
vmm:vmx:nested:compose
/self->pf && self->nf > 80 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*80 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 81/
{ this->e = *(uint32_t *)(self->c + 32 + 16*81); }
vmm:vmx:nested:compose
/self->pf && self->nf > 81 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*81 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 82/
{ this->e = *(uint32_t *)(self->c + 32 + 16*82); }
vmm:vmx:nested:compose
/self->pf && self->nf > 82 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*82 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 83/
{ this->e = *(uint32_t *)(self->c + 32 + 16*83); }
vmm:vmx:nested:compose
/self->pf && self->nf > 83 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*83 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 84/
{ this->e = *(uint32_t *)(self->c + 32 + 16*84); }
vmm:vmx:nested:compose
/self->pf && self->nf > 84 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*84 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 85/
{ this->e = *(uint32_t *)(self->c + 32 + 16*85); }
vmm:vmx:nested:compose
/self->pf && self->nf > 85 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*85 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 86/
{ this->e = *(uint32_t *)(self->c + 32 + 16*86); }
vmm:vmx:nested:compose
/self->pf && self->nf > 86 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*86 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 87/
{ this->e = *(uint32_t *)(self->c + 32 + 16*87); }
vmm:vmx:nested:compose
/self->pf && self->nf > 87 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*87 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 88/
{ this->e = *(uint32_t *)(self->c + 32 + 16*88); }
vmm:vmx:nested:compose
/self->pf && self->nf > 88 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*88 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 89/
{ this->e = *(uint32_t *)(self->c + 32 + 16*89); }
vmm:vmx:nested:compose
/self->pf && self->nf > 89 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*89 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 90/
{ this->e = *(uint32_t *)(self->c + 32 + 16*90); }
vmm:vmx:nested:compose
/self->pf && self->nf > 90 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*90 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 91/
{ this->e = *(uint32_t *)(self->c + 32 + 16*91); }
vmm:vmx:nested:compose
/self->pf && self->nf > 91 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*91 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 92/
{ this->e = *(uint32_t *)(self->c + 32 + 16*92); }
vmm:vmx:nested:compose
/self->pf && self->nf > 92 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*92 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 93/
{ this->e = *(uint32_t *)(self->c + 32 + 16*93); }
vmm:vmx:nested:compose
/self->pf && self->nf > 93 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*93 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 94/
{ this->e = *(uint32_t *)(self->c + 32 + 16*94); }
vmm:vmx:nested:compose
/self->pf && self->nf > 94 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*94 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 95/
{ this->e = *(uint32_t *)(self->c + 32 + 16*95); }
vmm:vmx:nested:compose
/self->pf && self->nf > 95 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*95 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 96/
{ this->e = *(uint32_t *)(self->c + 32 + 16*96); }
vmm:vmx:nested:compose
/self->pf && self->nf > 96 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*96 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 97/
{ this->e = *(uint32_t *)(self->c + 32 + 16*97); }
vmm:vmx:nested:compose
/self->pf && self->nf > 97 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*97 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 98/
{ this->e = *(uint32_t *)(self->c + 32 + 16*98); }
vmm:vmx:nested:compose
/self->pf && self->nf > 98 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*98 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 99/
{ this->e = *(uint32_t *)(self->c + 32 + 16*99); }
vmm:vmx:nested:compose
/self->pf && self->nf > 99 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*99 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 100/
{ this->e = *(uint32_t *)(self->c + 32 + 16*100); }
vmm:vmx:nested:compose
/self->pf && self->nf > 100 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*100 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 101/
{ this->e = *(uint32_t *)(self->c + 32 + 16*101); }
vmm:vmx:nested:compose
/self->pf && self->nf > 101 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*101 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 102/
{ this->e = *(uint32_t *)(self->c + 32 + 16*102); }
vmm:vmx:nested:compose
/self->pf && self->nf > 102 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*102 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 103/
{ this->e = *(uint32_t *)(self->c + 32 + 16*103); }
vmm:vmx:nested:compose
/self->pf && self->nf > 103 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*103 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 104/
{ this->e = *(uint32_t *)(self->c + 32 + 16*104); }
vmm:vmx:nested:compose
/self->pf && self->nf > 104 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*104 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 105/
{ this->e = *(uint32_t *)(self->c + 32 + 16*105); }
vmm:vmx:nested:compose
/self->pf && self->nf > 105 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*105 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 106/
{ this->e = *(uint32_t *)(self->c + 32 + 16*106); }
vmm:vmx:nested:compose
/self->pf && self->nf > 106 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*106 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 107/
{ this->e = *(uint32_t *)(self->c + 32 + 16*107); }
vmm:vmx:nested:compose
/self->pf && self->nf > 107 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*107 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 108/
{ this->e = *(uint32_t *)(self->c + 32 + 16*108); }
vmm:vmx:nested:compose
/self->pf && self->nf > 108 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*108 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 109/
{ this->e = *(uint32_t *)(self->c + 32 + 16*109); }
vmm:vmx:nested:compose
/self->pf && self->nf > 109 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*109 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 110/
{ this->e = *(uint32_t *)(self->c + 32 + 16*110); }
vmm:vmx:nested:compose
/self->pf && self->nf > 110 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*110 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 111/
{ this->e = *(uint32_t *)(self->c + 32 + 16*111); }
vmm:vmx:nested:compose
/self->pf && self->nf > 111 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*111 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 112/
{ this->e = *(uint32_t *)(self->c + 32 + 16*112); }
vmm:vmx:nested:compose
/self->pf && self->nf > 112 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*112 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 113/
{ this->e = *(uint32_t *)(self->c + 32 + 16*113); }
vmm:vmx:nested:compose
/self->pf && self->nf > 113 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*113 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 114/
{ this->e = *(uint32_t *)(self->c + 32 + 16*114); }
vmm:vmx:nested:compose
/self->pf && self->nf > 114 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*114 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 115/
{ this->e = *(uint32_t *)(self->c + 32 + 16*115); }
vmm:vmx:nested:compose
/self->pf && self->nf > 115 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*115 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 116/
{ this->e = *(uint32_t *)(self->c + 32 + 16*116); }
vmm:vmx:nested:compose
/self->pf && self->nf > 116 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*116 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 117/
{ this->e = *(uint32_t *)(self->c + 32 + 16*117); }
vmm:vmx:nested:compose
/self->pf && self->nf > 117 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*117 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 118/
{ this->e = *(uint32_t *)(self->c + 32 + 16*118); }
vmm:vmx:nested:compose
/self->pf && self->nf > 118 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*118 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 119/
{ this->e = *(uint32_t *)(self->c + 32 + 16*119); }
vmm:vmx:nested:compose
/self->pf && self->nf > 119 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*119 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 120/
{ this->e = *(uint32_t *)(self->c + 32 + 16*120); }
vmm:vmx:nested:compose
/self->pf && self->nf > 120 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*120 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 121/
{ this->e = *(uint32_t *)(self->c + 32 + 16*121); }
vmm:vmx:nested:compose
/self->pf && self->nf > 121 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*121 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 122/
{ this->e = *(uint32_t *)(self->c + 32 + 16*122); }
vmm:vmx:nested:compose
/self->pf && self->nf > 122 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*122 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 123/
{ this->e = *(uint32_t *)(self->c + 32 + 16*123); }
vmm:vmx:nested:compose
/self->pf && self->nf > 123 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*123 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 124/
{ this->e = *(uint32_t *)(self->c + 32 + 16*124); }
vmm:vmx:nested:compose
/self->pf && self->nf > 124 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*124 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 125/
{ this->e = *(uint32_t *)(self->c + 32 + 16*125); }
vmm:vmx:nested:compose
/self->pf && self->nf > 125 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*125 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 126/
{ this->e = *(uint32_t *)(self->c + 32 + 16*126); }
vmm:vmx:nested:compose
/self->pf && self->nf > 126 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*126 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 127/
{ this->e = *(uint32_t *)(self->c + 32 + 16*127); }
vmm:vmx:nested:compose
/self->pf && self->nf > 127 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*127 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 128/
{ this->e = *(uint32_t *)(self->c + 32 + 16*128); }
vmm:vmx:nested:compose
/self->pf && self->nf > 128 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*128 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 129/
{ this->e = *(uint32_t *)(self->c + 32 + 16*129); }
vmm:vmx:nested:compose
/self->pf && self->nf > 129 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*129 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 130/
{ this->e = *(uint32_t *)(self->c + 32 + 16*130); }
vmm:vmx:nested:compose
/self->pf && self->nf > 130 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*130 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 131/
{ this->e = *(uint32_t *)(self->c + 32 + 16*131); }
vmm:vmx:nested:compose
/self->pf && self->nf > 131 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*131 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 132/
{ this->e = *(uint32_t *)(self->c + 32 + 16*132); }
vmm:vmx:nested:compose
/self->pf && self->nf > 132 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*132 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 133/
{ this->e = *(uint32_t *)(self->c + 32 + 16*133); }
vmm:vmx:nested:compose
/self->pf && self->nf > 133 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*133 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 134/
{ this->e = *(uint32_t *)(self->c + 32 + 16*134); }
vmm:vmx:nested:compose
/self->pf && self->nf > 134 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*134 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 135/
{ this->e = *(uint32_t *)(self->c + 32 + 16*135); }
vmm:vmx:nested:compose
/self->pf && self->nf > 135 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*135 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 136/
{ this->e = *(uint32_t *)(self->c + 32 + 16*136); }
vmm:vmx:nested:compose
/self->pf && self->nf > 136 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*136 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 137/
{ this->e = *(uint32_t *)(self->c + 32 + 16*137); }
vmm:vmx:nested:compose
/self->pf && self->nf > 137 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*137 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 138/
{ this->e = *(uint32_t *)(self->c + 32 + 16*138); }
vmm:vmx:nested:compose
/self->pf && self->nf > 138 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*138 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 139/
{ this->e = *(uint32_t *)(self->c + 32 + 16*139); }
vmm:vmx:nested:compose
/self->pf && self->nf > 139 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*139 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 140/
{ this->e = *(uint32_t *)(self->c + 32 + 16*140); }
vmm:vmx:nested:compose
/self->pf && self->nf > 140 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*140 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 141/
{ this->e = *(uint32_t *)(self->c + 32 + 16*141); }
vmm:vmx:nested:compose
/self->pf && self->nf > 141 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*141 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 142/
{ this->e = *(uint32_t *)(self->c + 32 + 16*142); }
vmm:vmx:nested:compose
/self->pf && self->nf > 142 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*142 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 143/
{ this->e = *(uint32_t *)(self->c + 32 + 16*143); }
vmm:vmx:nested:compose
/self->pf && self->nf > 143 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*143 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 144/
{ this->e = *(uint32_t *)(self->c + 32 + 16*144); }
vmm:vmx:nested:compose
/self->pf && self->nf > 144 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*144 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 145/
{ this->e = *(uint32_t *)(self->c + 32 + 16*145); }
vmm:vmx:nested:compose
/self->pf && self->nf > 145 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*145 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 146/
{ this->e = *(uint32_t *)(self->c + 32 + 16*146); }
vmm:vmx:nested:compose
/self->pf && self->nf > 146 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*146 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 147/
{ this->e = *(uint32_t *)(self->c + 32 + 16*147); }
vmm:vmx:nested:compose
/self->pf && self->nf > 147 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*147 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 148/
{ this->e = *(uint32_t *)(self->c + 32 + 16*148); }
vmm:vmx:nested:compose
/self->pf && self->nf > 148 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*148 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 149/
{ this->e = *(uint32_t *)(self->c + 32 + 16*149); }
vmm:vmx:nested:compose
/self->pf && self->nf > 149 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*149 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 150/
{ this->e = *(uint32_t *)(self->c + 32 + 16*150); }
vmm:vmx:nested:compose
/self->pf && self->nf > 150 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*150 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 151/
{ this->e = *(uint32_t *)(self->c + 32 + 16*151); }
vmm:vmx:nested:compose
/self->pf && self->nf > 151 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*151 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 152/
{ this->e = *(uint32_t *)(self->c + 32 + 16*152); }
vmm:vmx:nested:compose
/self->pf && self->nf > 152 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*152 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 153/
{ this->e = *(uint32_t *)(self->c + 32 + 16*153); }
vmm:vmx:nested:compose
/self->pf && self->nf > 153 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*153 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 154/
{ this->e = *(uint32_t *)(self->c + 32 + 16*154); }
vmm:vmx:nested:compose
/self->pf && self->nf > 154 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*154 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 155/
{ this->e = *(uint32_t *)(self->c + 32 + 16*155); }
vmm:vmx:nested:compose
/self->pf && self->nf > 155 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*155 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 156/
{ this->e = *(uint32_t *)(self->c + 32 + 16*156); }
vmm:vmx:nested:compose
/self->pf && self->nf > 156 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*156 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 157/
{ this->e = *(uint32_t *)(self->c + 32 + 16*157); }
vmm:vmx:nested:compose
/self->pf && self->nf > 157 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*157 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 158/
{ this->e = *(uint32_t *)(self->c + 32 + 16*158); }
vmm:vmx:nested:compose
/self->pf && self->nf > 158 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*158 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 159/
{ this->e = *(uint32_t *)(self->c + 32 + 16*159); }
vmm:vmx:nested:compose
/self->pf && self->nf > 159 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*159 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 160/
{ this->e = *(uint32_t *)(self->c + 32 + 16*160); }
vmm:vmx:nested:compose
/self->pf && self->nf > 160 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*160 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 161/
{ this->e = *(uint32_t *)(self->c + 32 + 16*161); }
vmm:vmx:nested:compose
/self->pf && self->nf > 161 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*161 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 162/
{ this->e = *(uint32_t *)(self->c + 32 + 16*162); }
vmm:vmx:nested:compose
/self->pf && self->nf > 162 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*162 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 163/
{ this->e = *(uint32_t *)(self->c + 32 + 16*163); }
vmm:vmx:nested:compose
/self->pf && self->nf > 163 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*163 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 164/
{ this->e = *(uint32_t *)(self->c + 32 + 16*164); }
vmm:vmx:nested:compose
/self->pf && self->nf > 164 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*164 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 165/
{ this->e = *(uint32_t *)(self->c + 32 + 16*165); }
vmm:vmx:nested:compose
/self->pf && self->nf > 165 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*165 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 166/
{ this->e = *(uint32_t *)(self->c + 32 + 16*166); }
vmm:vmx:nested:compose
/self->pf && self->nf > 166 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*166 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 167/
{ this->e = *(uint32_t *)(self->c + 32 + 16*167); }
vmm:vmx:nested:compose
/self->pf && self->nf > 167 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*167 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 168/
{ this->e = *(uint32_t *)(self->c + 32 + 16*168); }
vmm:vmx:nested:compose
/self->pf && self->nf > 168 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*168 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 169/
{ this->e = *(uint32_t *)(self->c + 32 + 16*169); }
vmm:vmx:nested:compose
/self->pf && self->nf > 169 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*169 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 170/
{ this->e = *(uint32_t *)(self->c + 32 + 16*170); }
vmm:vmx:nested:compose
/self->pf && self->nf > 170 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*170 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 171/
{ this->e = *(uint32_t *)(self->c + 32 + 16*171); }
vmm:vmx:nested:compose
/self->pf && self->nf > 171 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*171 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 172/
{ this->e = *(uint32_t *)(self->c + 32 + 16*172); }
vmm:vmx:nested:compose
/self->pf && self->nf > 172 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*172 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 173/
{ this->e = *(uint32_t *)(self->c + 32 + 16*173); }
vmm:vmx:nested:compose
/self->pf && self->nf > 173 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*173 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 174/
{ this->e = *(uint32_t *)(self->c + 32 + 16*174); }
vmm:vmx:nested:compose
/self->pf && self->nf > 174 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*174 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 175/
{ this->e = *(uint32_t *)(self->c + 32 + 16*175); }
vmm:vmx:nested:compose
/self->pf && self->nf > 175 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*175 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 176/
{ this->e = *(uint32_t *)(self->c + 32 + 16*176); }
vmm:vmx:nested:compose
/self->pf && self->nf > 176 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*176 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 177/
{ this->e = *(uint32_t *)(self->c + 32 + 16*177); }
vmm:vmx:nested:compose
/self->pf && self->nf > 177 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*177 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 178/
{ this->e = *(uint32_t *)(self->c + 32 + 16*178); }
vmm:vmx:nested:compose
/self->pf && self->nf > 178 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*178 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 179/
{ this->e = *(uint32_t *)(self->c + 32 + 16*179); }
vmm:vmx:nested:compose
/self->pf && self->nf > 179 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*179 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 180/
{ this->e = *(uint32_t *)(self->c + 32 + 16*180); }
vmm:vmx:nested:compose
/self->pf && self->nf > 180 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*180 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 181/
{ this->e = *(uint32_t *)(self->c + 32 + 16*181); }
vmm:vmx:nested:compose
/self->pf && self->nf > 181 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*181 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 182/
{ this->e = *(uint32_t *)(self->c + 32 + 16*182); }
vmm:vmx:nested:compose
/self->pf && self->nf > 182 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*182 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 183/
{ this->e = *(uint32_t *)(self->c + 32 + 16*183); }
vmm:vmx:nested:compose
/self->pf && self->nf > 183 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*183 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 184/
{ this->e = *(uint32_t *)(self->c + 32 + 16*184); }
vmm:vmx:nested:compose
/self->pf && self->nf > 184 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*184 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 185/
{ this->e = *(uint32_t *)(self->c + 32 + 16*185); }
vmm:vmx:nested:compose
/self->pf && self->nf > 185 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*185 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 186/
{ this->e = *(uint32_t *)(self->c + 32 + 16*186); }
vmm:vmx:nested:compose
/self->pf && self->nf > 186 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*186 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 187/
{ this->e = *(uint32_t *)(self->c + 32 + 16*187); }
vmm:vmx:nested:compose
/self->pf && self->nf > 187 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*187 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 188/
{ this->e = *(uint32_t *)(self->c + 32 + 16*188); }
vmm:vmx:nested:compose
/self->pf && self->nf > 188 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*188 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 189/
{ this->e = *(uint32_t *)(self->c + 32 + 16*189); }
vmm:vmx:nested:compose
/self->pf && self->nf > 189 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*189 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 190/
{ this->e = *(uint32_t *)(self->c + 32 + 16*190); }
vmm:vmx:nested:compose
/self->pf && self->nf > 190 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*190 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 191/
{ this->e = *(uint32_t *)(self->c + 32 + 16*191); }
vmm:vmx:nested:compose
/self->pf && self->nf > 191 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*191 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 192/
{ this->e = *(uint32_t *)(self->c + 32 + 16*192); }
vmm:vmx:nested:compose
/self->pf && self->nf > 192 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*192 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 193/
{ this->e = *(uint32_t *)(self->c + 32 + 16*193); }
vmm:vmx:nested:compose
/self->pf && self->nf > 193 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*193 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 194/
{ this->e = *(uint32_t *)(self->c + 32 + 16*194); }
vmm:vmx:nested:compose
/self->pf && self->nf > 194 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*194 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 195/
{ this->e = *(uint32_t *)(self->c + 32 + 16*195); }
vmm:vmx:nested:compose
/self->pf && self->nf > 195 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*195 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 196/
{ this->e = *(uint32_t *)(self->c + 32 + 16*196); }
vmm:vmx:nested:compose
/self->pf && self->nf > 196 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*196 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 197/
{ this->e = *(uint32_t *)(self->c + 32 + 16*197); }
vmm:vmx:nested:compose
/self->pf && self->nf > 197 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*197 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 198/
{ this->e = *(uint32_t *)(self->c + 32 + 16*198); }
vmm:vmx:nested:compose
/self->pf && self->nf > 198 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*198 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 199/
{ this->e = *(uint32_t *)(self->c + 32 + 16*199); }
vmm:vmx:nested:compose
/self->pf && self->nf > 199 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*199 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 200/
{ this->e = *(uint32_t *)(self->c + 32 + 16*200); }
vmm:vmx:nested:compose
/self->pf && self->nf > 200 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*200 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 201/
{ this->e = *(uint32_t *)(self->c + 32 + 16*201); }
vmm:vmx:nested:compose
/self->pf && self->nf > 201 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*201 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 202/
{ this->e = *(uint32_t *)(self->c + 32 + 16*202); }
vmm:vmx:nested:compose
/self->pf && self->nf > 202 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*202 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 203/
{ this->e = *(uint32_t *)(self->c + 32 + 16*203); }
vmm:vmx:nested:compose
/self->pf && self->nf > 203 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*203 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 204/
{ this->e = *(uint32_t *)(self->c + 32 + 16*204); }
vmm:vmx:nested:compose
/self->pf && self->nf > 204 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*204 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 205/
{ this->e = *(uint32_t *)(self->c + 32 + 16*205); }
vmm:vmx:nested:compose
/self->pf && self->nf > 205 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*205 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 206/
{ this->e = *(uint32_t *)(self->c + 32 + 16*206); }
vmm:vmx:nested:compose
/self->pf && self->nf > 206 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*206 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 207/
{ this->e = *(uint32_t *)(self->c + 32 + 16*207); }
vmm:vmx:nested:compose
/self->pf && self->nf > 207 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*207 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 208/
{ this->e = *(uint32_t *)(self->c + 32 + 16*208); }
vmm:vmx:nested:compose
/self->pf && self->nf > 208 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*208 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 209/
{ this->e = *(uint32_t *)(self->c + 32 + 16*209); }
vmm:vmx:nested:compose
/self->pf && self->nf > 209 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*209 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 210/
{ this->e = *(uint32_t *)(self->c + 32 + 16*210); }
vmm:vmx:nested:compose
/self->pf && self->nf > 210 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*210 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 211/
{ this->e = *(uint32_t *)(self->c + 32 + 16*211); }
vmm:vmx:nested:compose
/self->pf && self->nf > 211 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*211 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 212/
{ this->e = *(uint32_t *)(self->c + 32 + 16*212); }
vmm:vmx:nested:compose
/self->pf && self->nf > 212 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*212 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 213/
{ this->e = *(uint32_t *)(self->c + 32 + 16*213); }
vmm:vmx:nested:compose
/self->pf && self->nf > 213 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*213 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 214/
{ this->e = *(uint32_t *)(self->c + 32 + 16*214); }
vmm:vmx:nested:compose
/self->pf && self->nf > 214 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*214 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 215/
{ this->e = *(uint32_t *)(self->c + 32 + 16*215); }
vmm:vmx:nested:compose
/self->pf && self->nf > 215 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*215 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 216/
{ this->e = *(uint32_t *)(self->c + 32 + 16*216); }
vmm:vmx:nested:compose
/self->pf && self->nf > 216 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*216 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 217/
{ this->e = *(uint32_t *)(self->c + 32 + 16*217); }
vmm:vmx:nested:compose
/self->pf && self->nf > 217 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*217 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 218/
{ this->e = *(uint32_t *)(self->c + 32 + 16*218); }
vmm:vmx:nested:compose
/self->pf && self->nf > 218 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*218 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 219/
{ this->e = *(uint32_t *)(self->c + 32 + 16*219); }
vmm:vmx:nested:compose
/self->pf && self->nf > 219 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*219 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 220/
{ this->e = *(uint32_t *)(self->c + 32 + 16*220); }
vmm:vmx:nested:compose
/self->pf && self->nf > 220 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*220 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 221/
{ this->e = *(uint32_t *)(self->c + 32 + 16*221); }
vmm:vmx:nested:compose
/self->pf && self->nf > 221 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*221 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 222/
{ this->e = *(uint32_t *)(self->c + 32 + 16*222); }
vmm:vmx:nested:compose
/self->pf && self->nf > 222 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*222 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 223/
{ this->e = *(uint32_t *)(self->c + 32 + 16*223); }
vmm:vmx:nested:compose
/self->pf && self->nf > 223 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*223 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 224/
{ this->e = *(uint32_t *)(self->c + 32 + 16*224); }
vmm:vmx:nested:compose
/self->pf && self->nf > 224 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*224 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 225/
{ this->e = *(uint32_t *)(self->c + 32 + 16*225); }
vmm:vmx:nested:compose
/self->pf && self->nf > 225 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*225 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 226/
{ this->e = *(uint32_t *)(self->c + 32 + 16*226); }
vmm:vmx:nested:compose
/self->pf && self->nf > 226 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*226 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 227/
{ this->e = *(uint32_t *)(self->c + 32 + 16*227); }
vmm:vmx:nested:compose
/self->pf && self->nf > 227 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*227 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 228/
{ this->e = *(uint32_t *)(self->c + 32 + 16*228); }
vmm:vmx:nested:compose
/self->pf && self->nf > 228 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*228 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 229/
{ this->e = *(uint32_t *)(self->c + 32 + 16*229); }
vmm:vmx:nested:compose
/self->pf && self->nf > 229 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*229 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 230/
{ this->e = *(uint32_t *)(self->c + 32 + 16*230); }
vmm:vmx:nested:compose
/self->pf && self->nf > 230 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*230 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 231/
{ this->e = *(uint32_t *)(self->c + 32 + 16*231); }
vmm:vmx:nested:compose
/self->pf && self->nf > 231 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*231 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 232/
{ this->e = *(uint32_t *)(self->c + 32 + 16*232); }
vmm:vmx:nested:compose
/self->pf && self->nf > 232 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*232 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 233/
{ this->e = *(uint32_t *)(self->c + 32 + 16*233); }
vmm:vmx:nested:compose
/self->pf && self->nf > 233 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*233 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 234/
{ this->e = *(uint32_t *)(self->c + 32 + 16*234); }
vmm:vmx:nested:compose
/self->pf && self->nf > 234 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*234 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 235/
{ this->e = *(uint32_t *)(self->c + 32 + 16*235); }
vmm:vmx:nested:compose
/self->pf && self->nf > 235 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*235 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 236/
{ this->e = *(uint32_t *)(self->c + 32 + 16*236); }
vmm:vmx:nested:compose
/self->pf && self->nf > 236 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*236 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 237/
{ this->e = *(uint32_t *)(self->c + 32 + 16*237); }
vmm:vmx:nested:compose
/self->pf && self->nf > 237 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*237 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 238/
{ this->e = *(uint32_t *)(self->c + 32 + 16*238); }
vmm:vmx:nested:compose
/self->pf && self->nf > 238 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*238 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 239/
{ this->e = *(uint32_t *)(self->c + 32 + 16*239); }
vmm:vmx:nested:compose
/self->pf && self->nf > 239 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*239 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 240/
{ this->e = *(uint32_t *)(self->c + 32 + 16*240); }
vmm:vmx:nested:compose
/self->pf && self->nf > 240 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*240 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 241/
{ this->e = *(uint32_t *)(self->c + 32 + 16*241); }
vmm:vmx:nested:compose
/self->pf && self->nf > 241 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*241 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 242/
{ this->e = *(uint32_t *)(self->c + 32 + 16*242); }
vmm:vmx:nested:compose
/self->pf && self->nf > 242 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*242 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 243/
{ this->e = *(uint32_t *)(self->c + 32 + 16*243); }
vmm:vmx:nested:compose
/self->pf && self->nf > 243 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*243 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 244/
{ this->e = *(uint32_t *)(self->c + 32 + 16*244); }
vmm:vmx:nested:compose
/self->pf && self->nf > 244 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*244 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 245/
{ this->e = *(uint32_t *)(self->c + 32 + 16*245); }
vmm:vmx:nested:compose
/self->pf && self->nf > 245 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*245 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 246/
{ this->e = *(uint32_t *)(self->c + 32 + 16*246); }
vmm:vmx:nested:compose
/self->pf && self->nf > 246 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*246 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 247/
{ this->e = *(uint32_t *)(self->c + 32 + 16*247); }
vmm:vmx:nested:compose
/self->pf && self->nf > 247 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*247 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 248/
{ this->e = *(uint32_t *)(self->c + 32 + 16*248); }
vmm:vmx:nested:compose
/self->pf && self->nf > 248 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*248 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 249/
{ this->e = *(uint32_t *)(self->c + 32 + 16*249); }
vmm:vmx:nested:compose
/self->pf && self->nf > 249 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*249 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 250/
{ this->e = *(uint32_t *)(self->c + 32 + 16*250); }
vmm:vmx:nested:compose
/self->pf && self->nf > 250 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*250 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 251/
{ this->e = *(uint32_t *)(self->c + 32 + 16*251); }
vmm:vmx:nested:compose
/self->pf && self->nf > 251 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*251 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 252/
{ this->e = *(uint32_t *)(self->c + 32 + 16*252); }
vmm:vmx:nested:compose
/self->pf && self->nf > 252 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*252 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 253/
{ this->e = *(uint32_t *)(self->c + 32 + 16*253); }
vmm:vmx:nested:compose
/self->pf && self->nf > 253 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*253 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 254/
{ this->e = *(uint32_t *)(self->c + 32 + 16*254); }
vmm:vmx:nested:compose
/self->pf && self->nf > 254 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*254 + 8)); }
vmm:vmx:nested:compose
/self->pf && self->nf > 255/
{ this->e = *(uint32_t *)(self->c + 32 + 16*255); }
vmm:vmx:nested:compose
/self->pf && self->nf > 255 && (this->e == 0x4016 || this->e == 0x4018 || this->e == 0x401a || this->e == 0x4402 || this->e == 0x4404 || this->e == 0x4406 || this->e == 0x4408 || this->e == 0x440a || this->e == 0x6400 || this->e == 0x640a || this->e == 0x2400 || this->e == 0x681e || this->e == 0x6802 || this->e == 0x6820 || this->e == 0x4824 || this->e == 0x6800 || this->e == 0x6804)/
{ printf("  enc %04x = %x\n", this->e, *(uint64_t *)(self->c + 32 + 16*255 + 8)); }
vmm:vmx:nested:compose
/self->pf/
{ self->pf = 0; }

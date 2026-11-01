#pragma D option quiet
#pragma D option bufsize=32m
#pragma D option switchrate=2hz
/* Claude 19/10/2026 — Astra: registri del guest all'invio di 0xff (contesto
 * vicino allo spin di cpu1). self->vv = vmx_vcpu (da exit:entry); ctx a +0x68:
 * rdi+0, rsi+8, rdx+16, rcx+24, r8+32, r9+40, rax+48, rbx+56, rbp+64.
 * vlapic.vcpuid+16, apic_page+24, icrlo 0x300. */
int go; int64_t t0; int done;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }
vmm:vmx:exit:entry /go/ { self->vv = arg0; self->rip = *(uint64_t *)((uintptr_t)arg2 + 8); }
fbt:vmm-restore:vlapic_icrlo_write_handler:entry /go && self->vv && done < 40/
{
	this->p = *(uintptr_t *)(arg0 + 24);
	this->vec = *(uint32_t *)(this->p + 0x300) & 0xff;
	if (this->vec == 0xff) {
		this->c = self->vv + 0x68;
		done++;
		printf("%10d cpu%d 0xff-send rip=%#lx rdi=%#lx rsi=%#lx rcx=%#lx rax=%#lx r8=%#lx rbp=%#lx\n",
		    (timestamp - t0)/1000, *(int *)(arg0 + 16), self->rip,
		    *(uint64_t *)(this->c + 0), *(uint64_t *)(this->c + 8),
		    *(uint64_t *)(this->c + 24), *(uint64_t *)(this->c + 48),
		    *(uint64_t *)(this->c + 32), *(uint64_t *)(this->c + 64));
	}
}
tick-5s /go/ { printf("--- %d s ---\n", (timestamp - t0)/1000000000); }

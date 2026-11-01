#pragma D option quiet
#pragma D option bufsize=32m
#pragma D option switchrate=2hz
/* Claude 19/10/2026 — leggo i GPR vivi del guest all'uscita PAUSE (reason 40)
 * di cpu1 durante lo spin. Se rdi/rcx sono valori sensati, puntano alla
 * struttura che lo spin esamina ([rdi+0x104b8]->rcx; [rcx+0x38]...).
 * arg0=vmx_vcpu, ctx a +0x68 (rdi+0, rsi+8, rcx+24, rax+48). arg1=vcpuid,
 * arg2=vmexit (+20 reason). nested +696, in_l2 +1. */
int go; int64_t t0; int done;
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }
vmm:vmx:exit:entry
/go && (*(uint32_t *)((uintptr_t)arg2 + 20) & 0xffff) == 40 && done < 30/
{
	this->c = arg0 + 0x68;
	this->n = *(uintptr_t *)(arg0 + 696);
	done++;
	printf("%10d cpu%d PAUSE in_l2=%d rdi=%#lx rsi=%#lx rcx=%#lx rax=%#lx\n",
	    (timestamp - t0)/1000, (int)arg1, this->n ? *(uint8_t *)(this->n + 1) : -1,
	    *(uint64_t *)(this->c + 0), *(uint64_t *)(this->c + 8),
	    *(uint64_t *)(this->c + 24), *(uint64_t *)(this->c + 48));
}
tick-5s /go/ { printf("--- %d s ---\n", (timestamp - t0)/1000000000); }

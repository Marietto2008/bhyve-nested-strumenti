/* livello-annidato.c -- claude 14/11/2026: per ogni vCPU di una VM, VM_REG_GUEST_NESTED_LEVEL (1 = L1, 2 = L2)
 * e RIP, in sola lettura (vm_get_register). Uso: livello-annidato vm2 [ncpu] */
#include <sys/types.h>
#include <machine/vmm.h>
#include <vmmapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
int main(int argc, char **argv)
{
	struct vmctx *ctx;
	int n = argc > 2 ? atoi(argv[2]) : 8;
	if (argc < 2 || (ctx = vm_open(argv[1])) == NULL) { fprintf(stderr, "vm_open: %s\n", strerror(errno)); return 1; }
	for (int i = 0; i < n; i++) {
		struct vcpu *v = vm_vcpu_open(ctx, i);
		uint64_t liv = 0, rip = 0;
		int e1 = vm_get_register(v, VM_REG_GUEST_NESTED_LEVEL, &liv);
		int e2 = vm_get_register(v, VM_REG_GUEST_RIP, &rip);
		printf("vCPU %d: livello %s%lu RIP %#lx%s\n", i, e1 ? "?" : "", (unsigned long)liv, (unsigned long)rip, e2 ? " (lettura RIP fallita)" : "");
		vm_vcpu_close(v);
	}
	return 0;
}

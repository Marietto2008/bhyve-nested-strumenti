#pragma D option quiet
#pragma D option switchrate=10hz
/*
 * Claude 20/10/2026 -- Astra #17 Fase A/B: il GPA del FETCH dell'istruzione a
 * user-RIP 0x7ff..43xx, e la qualificazione delle EPT violation che la
 * precedono. nested:eptviol(vcpu, eptp_hw, eptp_shadow, gpa, qual) scatta
 * dentro nested_l2_exit; il RIP di L2 viene da nested_l2_exit:entry (vm_exit
 * rip +8). qual: bit0 R, bit1 W, bit2 X(fetch), bit7 GLA valido.
 */
int go; int64_t t0; uint64_t rip[int];
vmm:vmx:nested:enter_l2 /!go/ { go = 1; t0 = timestamp; }
fbt:vmm-restore:nested_l2_exit:entry /go/ { rip[*(int *)(arg0 + 704)] = *(uint64_t *)(arg1 + 8); }

vmm:vmx:nested:eptviol /go/
{
	this->cpu = *(int *)(arg0 + 704);
	this->r = rip[this->cpu];
	this->acc = (arg4 & 1 ? "R" : "") ;
}
/* fetch (bit2) a un RIP utente della zona incriminata: stampa il GPA una volta */
vmm:vmx:nested:eptviol
/go && (arg4 & 4) && rip[*(int *)(arg0 + 704)] >= 0x7ff000000000 && rip[*(int *)(arg0 + 704)] < 0x800000000000/
{
	printf("FETCH rip=%#lx gpa=%#lx qual=%#lx\n", rip[this->cpu], arg3, arg4);
}
/* qualunque EPT violation nella zona utente: per la cronologia R/W/X */
vmm:vmx:nested:eptviol
/go && rip[*(int *)(arg0 + 704)] >= 0x7ff000000000 && rip[*(int *)(arg0 + 704)] < 0x800000000000/
{
	printf("EV    rip=%#lx gpa=%#lx qual=%#lx acc=%s%s%s gla_valid=%d\n",
	    rip[this->cpu], arg3, arg4,
	    arg4 & 1 ? "R" : "-", arg4 & 2 ? "W" : "-", arg4 & 4 ? "X" : "-",
	    (int)((arg4 >> 7) & 1));
}

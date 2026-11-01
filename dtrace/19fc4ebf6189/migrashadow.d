/*
 * Claude 25/10/2026 -- parere #48 §10 passo 04. migrapull.d ha mostrato che la migrazione forzata
 * con cpuset non cade mai fra la chiusura dello shadow (fine vmx_run) e lo slow path: il thread
 * cambia CPU al critical_exit dopo un'uscita per yield, e il vmx_run successivo riapre lo shadow
 * sull'altra CPU. Qui si conta proprio quello: lo shadow chiuso (VMCLEAR) su una CPU e riaperto,
 * con le scritture hardware dell'L1 ancora dentro, su un'altra (vmx_shvmcs_enter), oltre ai casi
 * dello slow path.
 */
fbt:vmm-restore:vmx_shvmcs_run_end:entry
{
	ultima[arg0] = cpu + 1;		/* 0 = mai visto */
	@ev["shadow chiuso a fine vmx_run"] = count();
}

fbt:vmm-restore:vmx_shvmcs_enter:entry
/ultima[arg0] != 0 && ultima[arg0] != cpu + 1/
{
	@ev["shadow RIAPERTO su un'altra cpu"] = count();
	ultima[arg0] = 0;
}

fbt:vmm-restore:vmx_nested_exit:entry
/ultima[arg0] != 0 && ultima[arg0] != cpu + 1/
{
	@ev["slow path su un'altra cpu"] = count();
}

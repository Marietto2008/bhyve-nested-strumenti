/*
 * Claude 25/10/2026 -- parere #48 §10 passo 04: conferma che la migrazione forzata cade FRA le
 * scritture hardware dell'L1 nello shadow e la copia di ritorno. vmx_shvmcs_run_end chiude un
 * vmx_run in cui l'L1 ha girato con lo shadow (e quindi ha potuto fare VMWRITE hardware) sulla CPU
 * corrente; il successivo vmx_nested_exit (slow path, dove avviene la copia di ritorno a
 * VMLAUNCH/VMRESUME/VMPTRLD/VMCLEAR/VMXOFF) gira sulla CPU che conta qui.
 * Una sola sonda per evento, nessun printf nel percorso caldo.
 */
fbt:vmm-restore:vmx_shvmcs_run_end:entry
{
	ultima[arg0] = cpu + 1;		/* 0 = mai visto */
	@ev["run_end con shadow"] = count();
}

fbt:vmm-restore:vmx_nested_exit:entry
/ultima[arg0] != 0 && ultima[arg0] != cpu + 1/
{
	@ev["slow path su un'ALTRA cpu dopo uno shadow vivo"] = count();
}

fbt:vmm-restore:vmx_nested_exit:entry
/ultima[arg0] != 0 && ultima[arg0] == cpu + 1/
{
	@ev["slow path sulla stessa cpu"] = count();
}

#pragma D option quiet
#pragma D option switchrate=2hz
#pragma D option aggrate=2hz
#pragma D option aggsize=32m
/*
 * Claude 24/10/2026 -- parere #39 §6.1/§7.1: dove va il tempo dei thread vCPU, SENZA
 * lockstat (che agiva tenendo il mutex e gonfiava la contesa). Solo profile-199 su ogni
 * CPU: se il thread interrotto e' un vCPU di bhyve, si aggrega lo stack del kernel a 12
 * livelli. In analisi: guest (campione in vmx_call_isr), attesa sul mutex pmap
 * (pmap_extract_and_hold -> __mtx_lock_*), e per questa il chiamante (dentro o fuori da
 * vmx_vept_invept). Nessuna altra sonda. Stampa cumulativa ogni 10 minuti (END non e'
 * affidabile con dtrace in sottofondo).
 */
profile-199
/execname == "bhyve" && strstr(stringof(curthread->td_name), "vcpu") != NULL/
{
	@s[stack(12)] = count();
	@n = count();
}
tick-10min
{
	printf("##### cumulativo %Y\n", walltimestamp);
	printa("campioni %@d\n", @n);
	printa("%k\n  =%@d\n", @s);
}

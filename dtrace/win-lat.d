#pragma D option quiet
#pragma D option switchrate=2hz
#pragma D option dynvarsize=16m
/*
 * Claude 20/10/2026 -- parere #23: latenza PER EVENTO dei rinvii degli
 * interrupt dell'L1 mentre il vCPU e' in L2. Apertura: primo rinvio di
 * (vCPU, vettore) (sonda defer). Chiusura: uscita EXTERNAL INTERRUPT sintetica
 * riflessa a Hyper-V con quel vettore (acknowledge-on-exit, misurato attivo:
 * synth_intr_info valido). vlapic_intr_accepted NON e' strumentabile con fbt
 * (inizia con un salto di coda, nessun prologo).
 * In piu': pause dei vCPU dell'host (thread vcpu fuori da vmx_run > 100 ms) e
 * ogni rinvio > 5 ms con l'ora assoluta, da confrontare coi buchi degli
 * orologi del guest.
 * Offset (DWARF d6ee1c3): vmx_vcpu.nested +0x2b8, .vcpu +8, .vcpuid +0x2c0;
 * vmx_nested.synth +17771, .synth_intr_info +17772; vcpu.exitinfo +0x88;
 * vm_exit.reason +0x14.
 */
int64_t aperto[int, int];
int64_t t0;

BEGIN { t0 = timestamp; }

vmm:vmx:nested:defer /aperto[(int)arg0, (int)arg3] == 0/
{ aperto[(int)arg0, (int)arg3] = timestamp; @aperti = count(); }

/* Claude 22/10/2026 (parere #31 §3): le variabili this-> non sono garantite
 * fra uno scatto e l'altro: si azzerano a ogni scatto. */
vmm:vmx:nested:reflect { this->info = 0; this->v = -1; this->vec = -1; }

vmm:vmx:nested:reflect
/(*(uint32_t *)(*(uintptr_t *)(arg0 + 8) + 0x88 + 0x14) & 0xffff) == 1 &&
 *(uint8_t *)(*(uintptr_t *)(arg0 + 0x2b8) + 17771) != 0/
{
	this->v = *(int *)(arg0 + 0x2c0);
	this->info = *(uint32_t *)(*(uintptr_t *)(arg0 + 0x2b8) + 17772);
	this->vec = (int)(this->info & 0xff);
	@extint = count();
}

/* chiusura senza un'apertura registrata da QUESTA traccia: contata, mai una
 * latenza (prima dava valori di ore: timestamp - 0 o un'apertura residua) */
vmm:vmx:nested:reflect
/this->info != 0 && aperto[this->v, this->vec] != 0 && aperto[this->v, this->vec] < t0/
{ @unmatched = count(); aperto[this->v, this->vec] = 0; }

vmm:vmx:nested:reflect
/this->info != 0 && aperto[this->v, this->vec] >= t0/
{
	this->d = (timestamp - aperto[this->v, this->vec]) / 1000;
	@lat = quantize(this->d); @latmax = max(this->d); @chiusi = count();
	@latvec[this->vec] = max(this->d);
	if (this->d > 5000)
		printf("%Y RINVIO LUNGO VP%d vett=%#x %d us\n", walltimestamp,
		    this->v, this->vec, this->d);
	aperto[this->v, this->vec] = 0;
}

/* pause dei vCPU: thread fuori da vmx_run per piu' di 100 ms */
fbt::vmx_run:return { self->out = timestamp; }
fbt::vmx_run:entry /self->out && timestamp - self->out > 100000000/
{
	printf("%Y PAUSA vCPU thread %d: %d ms fuori da vmx_run\n", walltimestamp,
	    tid, (timestamp - self->out) / 1000000);
}

tick-60s
{
	printf("=== %d min %Y\n", (timestamp - t0) / 60000000000, walltimestamp);
	printa("  rinvii aperti %@d", @aperti); printa("  chiusi %@d", @chiusi);
	printa("  ext-int riflessi %@d", @extint); printa("  latenza max %@d us\n", @latmax);
	printa("  chiusure senza apertura (unmatched_close) %@d\n", @unmatched);
	printa("  latenza max vettore %#x : %@d us\n", @latvec);
}
tick-10min { printa("  distribuzione latenza (us): %@d\n", @lat); }

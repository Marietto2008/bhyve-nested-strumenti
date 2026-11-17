#!/usr/sbin/dtrace -s
/*
 * leggi-blocco.d -- una passata, sola lettura. Scritto sui sorgenti FreeBSD stable/15 (L2).
 *
 * Stampa: il thread fermo in uno sleep a tempo, il suo callout (td_slpcallout), se il callout
 * e' davvero nel secchio della ruota dove dovrebbe stare, e per ogni CPU lo stato di
 * callout_cpu (cc_cpu), pcpu_state (timerstate), hardclocktime e pcputicks.
 *
 * Uso: cambiare TID qui sotto, poi   dtrace -s leggi-blocco.d
 *
 * Tempi: sbintime stampati come secondi.millisecondi di uptime.
 *        -1.999 vale -1 (tick non programmato); 2147483647.999 vale SBT_MAX (nessun evento).
 * "ora" e' th_offset dell'ultimo tc_windup: e' indietro di al piu' un tick (1 s a sistema fermo).
 *
 * Le variabili per-CPU statiche si raggiungono con
 *     (tipo *)(dpcpu_off[cpu] + (uintptr_t)&pcpu_entry_NOME)
 * La conversione a uintptr_t PRIMA della somma e' obbligatoria: "dpcpu_off[i] + &pcpu_entry_x"
 * e' aritmetica dei puntatori e moltiplica dpcpu_off per sizeof(*x).
 *
 * NON PROVATO su un sistema vero. Se dtrace rifiuta un simbolo, il messaggio dice quale.
 */
#pragma D option quiet

inline int TID = 100251;

BEGIN
{
	th = kernel`timehands;
	t_now = ((int64_t)th->th_offset.sec << 32) | (th->th_offset.frac >> 32);
	printf("ora %d.%03d  th_offset_count %u  th_generation %u  callwheelmask 0x%x\n",
	    (t_now) >> 32, (((t_now) & 0xffffffff) * 1000) >> 32,
	    th->th_offset_count, th->th_generation, kernel`callwheelmask);
	td = kernel`tidhashtbl[TID & kernel`tidhash].lh_first;
}
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }
BEGIN /td != NULL && td->td_tid != TID/ { td = td->td_hash.le_next; }

BEGIN
/td == NULL/
{
	printf("tid %d non trovato\n", TID);
}

BEGIN
/td != NULL/
{
	c = &td->td_slpcallout;
	printf("\nthread %d (%s) td %p\n", td->td_tid, td->td_proc->p_comm, td);
	printf("  td_state %d (1 = inibito)  td_inhibitors 0x%x (0x2 = dorme)  td_flags 0x%x (TDF_TIMEOUT = 0x10)\n",
	    td->td_state, td->td_inhibitors, td->td_flags);
	printf("  td_priority %d  td_lastcpu %d  td_slptick %d  wmesg %s  wchan %p\n",
	    td->td_priority, td->td_lastcpu, td->td_slptick,
	    td->td_wmesg != NULL ? stringof(td->td_wmesg) : "-", td->td_wchan);
	printf("  td_sleeptimo %d.%03d\n", (td->td_sleeptimo) >> 32, (((td->td_sleeptimo) & 0xffffffff) * 1000) >> 32);
	printf("  callout %p  c_time %d.%03d  c_precision 0x%x  c_cpu %d  c_func %a  c_arg %p\n",
	    c, (c->c_time) >> 32, (((c->c_time) & 0xffffffff) * 1000) >> 32, c->c_precision, c->c_cpu, c->c_func, c->c_arg);
	printf("  c_iflags 0x%x: PENDING %d PROCESSED %d DFRMIGRATION %d DIRECT %d   c_flags 0x%x: ACTIVE %d\n",
	    c->c_iflags, (c->c_iflags & 0x4) != 0, (c->c_iflags & 0x80) != 0,
	    (c->c_iflags & 0x40) != 0, (c->c_iflags & 0x100) != 0,
	    c->c_flags, (c->c_flags & 0x2) != 0);

	/* il secchio dove callout_cc_add l'ha messo: callout_hash(c_time) & callwheelmask */
	cc = (struct callout_cpu *)(kernel`dpcpu_off[c->c_cpu] + (uintptr_t)&kernel`pcpu_entry_cc_cpu);
	b = (c->c_time >> 24) & kernel`callwheelmask;
	e = cc->cc_callwheel[b].lh_first;
	depth = 0;
	printf("  ruota di cpu%d: cc %p  secchio %d  primo elemento %p\n", c->c_cpu, cc, b, e);
}
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }
BEGIN /td != NULL && e != NULL && e != c/ { e = e->c_links.le.le_next; depth++; }

BEGIN
/td != NULL/
{
	printf("  callout nel suo secchio: %s (elementi percorsi %d)\n",
	    e == c ? "SI" : "NO", depth);
	printf("\n");
}

BEGIN
{
	this->cc = (struct callout_cpu *)(kernel`dpcpu_off[0] + (uintptr_t)&kernel`pcpu_entry_cc_cpu);
	this->st = (struct pcpu_state *)(kernel`dpcpu_off[0] + (uintptr_t)&kernel`pcpu_entry_timerstate);
	this->hct = *(int64_t *)(kernel`dpcpu_off[0] + (uintptr_t)&kernel`pcpu_entry_hardclocktime);
	this->pt = *(long *)(kernel`dpcpu_off[0] + (uintptr_t)&kernel`pcpu_entry_pcputicks);
	printf("cpu0 cc %p  cc_lastscan %d.%03d  cc_firstevent %d.%03d  cc_bucket %d  in corso [0] %p [1] %p\n",
	    this->cc, (this->cc->cc_lastscan) >> 32, (((this->cc->cc_lastscan) & 0xffffffff) * 1000) >> 32, (this->cc->cc_firstevent) >> 32, (((this->cc->cc_firstevent) & 0xffffffff) * 1000) >> 32, this->cc->cc_bucket,
	    this->cc->cc_exec_entity[0].cc_curr, this->cc->cc_exec_entity[1].cc_curr);
	printf("     now %d.%03d  nextevent %d.%03d  nexttick %d.%03d  nexthard %d.%03d\n",
	    (this->st->now) >> 32, (((this->st->now) & 0xffffffff) * 1000) >> 32, (this->st->nextevent) >> 32, (((this->st->nextevent) & 0xffffffff) * 1000) >> 32, (this->st->nexttick) >> 32, (((this->st->nexttick) & 0xffffffff) * 1000) >> 32, (this->st->nexthard) >> 32, (((this->st->nexthard) & 0xffffffff) * 1000) >> 32);
	printf("     nextstat %d.%03d  nextcall %d.%03d  nextcallopt %d.%03d  idle %d handle %d ipi %d action %d\n",
	    (this->st->nextstat) >> 32, (((this->st->nextstat) & 0xffffffff) * 1000) >> 32, (this->st->nextcall) >> 32, (((this->st->nextcall) & 0xffffffff) * 1000) >> 32, (this->st->nextcallopt) >> 32, (((this->st->nextcallopt) & 0xffffffff) * 1000) >> 32,
	    this->st->idle, this->st->handle, this->st->ipi, this->st->action);
	printf("     hardclocktime %d.%03d  pcputicks %d\n", (this->hct) >> 32, (((this->hct) & 0xffffffff) * 1000) >> 32, this->pt);
}

BEGIN
{
	this->cc = (struct callout_cpu *)(kernel`dpcpu_off[1] + (uintptr_t)&kernel`pcpu_entry_cc_cpu);
	this->st = (struct pcpu_state *)(kernel`dpcpu_off[1] + (uintptr_t)&kernel`pcpu_entry_timerstate);
	this->hct = *(int64_t *)(kernel`dpcpu_off[1] + (uintptr_t)&kernel`pcpu_entry_hardclocktime);
	this->pt = *(long *)(kernel`dpcpu_off[1] + (uintptr_t)&kernel`pcpu_entry_pcputicks);
	printf("cpu1 cc %p  cc_lastscan %d.%03d  cc_firstevent %d.%03d  cc_bucket %d  in corso [0] %p [1] %p\n",
	    this->cc, (this->cc->cc_lastscan) >> 32, (((this->cc->cc_lastscan) & 0xffffffff) * 1000) >> 32, (this->cc->cc_firstevent) >> 32, (((this->cc->cc_firstevent) & 0xffffffff) * 1000) >> 32, this->cc->cc_bucket,
	    this->cc->cc_exec_entity[0].cc_curr, this->cc->cc_exec_entity[1].cc_curr);
	printf("     now %d.%03d  nextevent %d.%03d  nexttick %d.%03d  nexthard %d.%03d\n",
	    (this->st->now) >> 32, (((this->st->now) & 0xffffffff) * 1000) >> 32, (this->st->nextevent) >> 32, (((this->st->nextevent) & 0xffffffff) * 1000) >> 32, (this->st->nexttick) >> 32, (((this->st->nexttick) & 0xffffffff) * 1000) >> 32, (this->st->nexthard) >> 32, (((this->st->nexthard) & 0xffffffff) * 1000) >> 32);
	printf("     nextstat %d.%03d  nextcall %d.%03d  nextcallopt %d.%03d  idle %d handle %d ipi %d action %d\n",
	    (this->st->nextstat) >> 32, (((this->st->nextstat) & 0xffffffff) * 1000) >> 32, (this->st->nextcall) >> 32, (((this->st->nextcall) & 0xffffffff) * 1000) >> 32, (this->st->nextcallopt) >> 32, (((this->st->nextcallopt) & 0xffffffff) * 1000) >> 32,
	    this->st->idle, this->st->handle, this->st->ipi, this->st->action);
	printf("     hardclocktime %d.%03d  pcputicks %d\n", (this->hct) >> 32, (((this->hct) & 0xffffffff) * 1000) >> 32, this->pt);
}

BEGIN
{
	this->cc = (struct callout_cpu *)(kernel`dpcpu_off[2] + (uintptr_t)&kernel`pcpu_entry_cc_cpu);
	this->st = (struct pcpu_state *)(kernel`dpcpu_off[2] + (uintptr_t)&kernel`pcpu_entry_timerstate);
	this->hct = *(int64_t *)(kernel`dpcpu_off[2] + (uintptr_t)&kernel`pcpu_entry_hardclocktime);
	this->pt = *(long *)(kernel`dpcpu_off[2] + (uintptr_t)&kernel`pcpu_entry_pcputicks);
	printf("cpu2 cc %p  cc_lastscan %d.%03d  cc_firstevent %d.%03d  cc_bucket %d  in corso [0] %p [1] %p\n",
	    this->cc, (this->cc->cc_lastscan) >> 32, (((this->cc->cc_lastscan) & 0xffffffff) * 1000) >> 32, (this->cc->cc_firstevent) >> 32, (((this->cc->cc_firstevent) & 0xffffffff) * 1000) >> 32, this->cc->cc_bucket,
	    this->cc->cc_exec_entity[0].cc_curr, this->cc->cc_exec_entity[1].cc_curr);
	printf("     now %d.%03d  nextevent %d.%03d  nexttick %d.%03d  nexthard %d.%03d\n",
	    (this->st->now) >> 32, (((this->st->now) & 0xffffffff) * 1000) >> 32, (this->st->nextevent) >> 32, (((this->st->nextevent) & 0xffffffff) * 1000) >> 32, (this->st->nexttick) >> 32, (((this->st->nexttick) & 0xffffffff) * 1000) >> 32, (this->st->nexthard) >> 32, (((this->st->nexthard) & 0xffffffff) * 1000) >> 32);
	printf("     nextstat %d.%03d  nextcall %d.%03d  nextcallopt %d.%03d  idle %d handle %d ipi %d action %d\n",
	    (this->st->nextstat) >> 32, (((this->st->nextstat) & 0xffffffff) * 1000) >> 32, (this->st->nextcall) >> 32, (((this->st->nextcall) & 0xffffffff) * 1000) >> 32, (this->st->nextcallopt) >> 32, (((this->st->nextcallopt) & 0xffffffff) * 1000) >> 32,
	    this->st->idle, this->st->handle, this->st->ipi, this->st->action);
	printf("     hardclocktime %d.%03d  pcputicks %d\n", (this->hct) >> 32, (((this->hct) & 0xffffffff) * 1000) >> 32, this->pt);
}

BEGIN
{
	this->cc = (struct callout_cpu *)(kernel`dpcpu_off[3] + (uintptr_t)&kernel`pcpu_entry_cc_cpu);
	this->st = (struct pcpu_state *)(kernel`dpcpu_off[3] + (uintptr_t)&kernel`pcpu_entry_timerstate);
	this->hct = *(int64_t *)(kernel`dpcpu_off[3] + (uintptr_t)&kernel`pcpu_entry_hardclocktime);
	this->pt = *(long *)(kernel`dpcpu_off[3] + (uintptr_t)&kernel`pcpu_entry_pcputicks);
	printf("cpu3 cc %p  cc_lastscan %d.%03d  cc_firstevent %d.%03d  cc_bucket %d  in corso [0] %p [1] %p\n",
	    this->cc, (this->cc->cc_lastscan) >> 32, (((this->cc->cc_lastscan) & 0xffffffff) * 1000) >> 32, (this->cc->cc_firstevent) >> 32, (((this->cc->cc_firstevent) & 0xffffffff) * 1000) >> 32, this->cc->cc_bucket,
	    this->cc->cc_exec_entity[0].cc_curr, this->cc->cc_exec_entity[1].cc_curr);
	printf("     now %d.%03d  nextevent %d.%03d  nexttick %d.%03d  nexthard %d.%03d\n",
	    (this->st->now) >> 32, (((this->st->now) & 0xffffffff) * 1000) >> 32, (this->st->nextevent) >> 32, (((this->st->nextevent) & 0xffffffff) * 1000) >> 32, (this->st->nexttick) >> 32, (((this->st->nexttick) & 0xffffffff) * 1000) >> 32, (this->st->nexthard) >> 32, (((this->st->nexthard) & 0xffffffff) * 1000) >> 32);
	printf("     nextstat %d.%03d  nextcall %d.%03d  nextcallopt %d.%03d  idle %d handle %d ipi %d action %d\n",
	    (this->st->nextstat) >> 32, (((this->st->nextstat) & 0xffffffff) * 1000) >> 32, (this->st->nextcall) >> 32, (((this->st->nextcall) & 0xffffffff) * 1000) >> 32, (this->st->nextcallopt) >> 32, (((this->st->nextcallopt) & 0xffffffff) * 1000) >> 32,
	    this->st->idle, this->st->handle, this->st->ipi, this->st->action);
	printf("     hardclocktime %d.%03d  pcputicks %d\n", (this->hct) >> 32, (((this->hct) & 0xffffffff) * 1000) >> 32, this->pt);
}

BEGIN
{
	this->cc = (struct callout_cpu *)(kernel`dpcpu_off[4] + (uintptr_t)&kernel`pcpu_entry_cc_cpu);
	this->st = (struct pcpu_state *)(kernel`dpcpu_off[4] + (uintptr_t)&kernel`pcpu_entry_timerstate);
	this->hct = *(int64_t *)(kernel`dpcpu_off[4] + (uintptr_t)&kernel`pcpu_entry_hardclocktime);
	this->pt = *(long *)(kernel`dpcpu_off[4] + (uintptr_t)&kernel`pcpu_entry_pcputicks);
	printf("cpu4 cc %p  cc_lastscan %d.%03d  cc_firstevent %d.%03d  cc_bucket %d  in corso [0] %p [1] %p\n",
	    this->cc, (this->cc->cc_lastscan) >> 32, (((this->cc->cc_lastscan) & 0xffffffff) * 1000) >> 32, (this->cc->cc_firstevent) >> 32, (((this->cc->cc_firstevent) & 0xffffffff) * 1000) >> 32, this->cc->cc_bucket,
	    this->cc->cc_exec_entity[0].cc_curr, this->cc->cc_exec_entity[1].cc_curr);
	printf("     now %d.%03d  nextevent %d.%03d  nexttick %d.%03d  nexthard %d.%03d\n",
	    (this->st->now) >> 32, (((this->st->now) & 0xffffffff) * 1000) >> 32, (this->st->nextevent) >> 32, (((this->st->nextevent) & 0xffffffff) * 1000) >> 32, (this->st->nexttick) >> 32, (((this->st->nexttick) & 0xffffffff) * 1000) >> 32, (this->st->nexthard) >> 32, (((this->st->nexthard) & 0xffffffff) * 1000) >> 32);
	printf("     nextstat %d.%03d  nextcall %d.%03d  nextcallopt %d.%03d  idle %d handle %d ipi %d action %d\n",
	    (this->st->nextstat) >> 32, (((this->st->nextstat) & 0xffffffff) * 1000) >> 32, (this->st->nextcall) >> 32, (((this->st->nextcall) & 0xffffffff) * 1000) >> 32, (this->st->nextcallopt) >> 32, (((this->st->nextcallopt) & 0xffffffff) * 1000) >> 32,
	    this->st->idle, this->st->handle, this->st->ipi, this->st->action);
	printf("     hardclocktime %d.%03d  pcputicks %d\n", (this->hct) >> 32, (((this->hct) & 0xffffffff) * 1000) >> 32, this->pt);
}

BEGIN
{
	this->cc = (struct callout_cpu *)(kernel`dpcpu_off[5] + (uintptr_t)&kernel`pcpu_entry_cc_cpu);
	this->st = (struct pcpu_state *)(kernel`dpcpu_off[5] + (uintptr_t)&kernel`pcpu_entry_timerstate);
	this->hct = *(int64_t *)(kernel`dpcpu_off[5] + (uintptr_t)&kernel`pcpu_entry_hardclocktime);
	this->pt = *(long *)(kernel`dpcpu_off[5] + (uintptr_t)&kernel`pcpu_entry_pcputicks);
	printf("cpu5 cc %p  cc_lastscan %d.%03d  cc_firstevent %d.%03d  cc_bucket %d  in corso [0] %p [1] %p\n",
	    this->cc, (this->cc->cc_lastscan) >> 32, (((this->cc->cc_lastscan) & 0xffffffff) * 1000) >> 32, (this->cc->cc_firstevent) >> 32, (((this->cc->cc_firstevent) & 0xffffffff) * 1000) >> 32, this->cc->cc_bucket,
	    this->cc->cc_exec_entity[0].cc_curr, this->cc->cc_exec_entity[1].cc_curr);
	printf("     now %d.%03d  nextevent %d.%03d  nexttick %d.%03d  nexthard %d.%03d\n",
	    (this->st->now) >> 32, (((this->st->now) & 0xffffffff) * 1000) >> 32, (this->st->nextevent) >> 32, (((this->st->nextevent) & 0xffffffff) * 1000) >> 32, (this->st->nexttick) >> 32, (((this->st->nexttick) & 0xffffffff) * 1000) >> 32, (this->st->nexthard) >> 32, (((this->st->nexthard) & 0xffffffff) * 1000) >> 32);
	printf("     nextstat %d.%03d  nextcall %d.%03d  nextcallopt %d.%03d  idle %d handle %d ipi %d action %d\n",
	    (this->st->nextstat) >> 32, (((this->st->nextstat) & 0xffffffff) * 1000) >> 32, (this->st->nextcall) >> 32, (((this->st->nextcall) & 0xffffffff) * 1000) >> 32, (this->st->nextcallopt) >> 32, (((this->st->nextcallopt) & 0xffffffff) * 1000) >> 32,
	    this->st->idle, this->st->handle, this->st->ipi, this->st->action);
	printf("     hardclocktime %d.%03d  pcputicks %d\n", (this->hct) >> 32, (((this->hct) & 0xffffffff) * 1000) >> 32, this->pt);
}

BEGIN
{
	this->cc = (struct callout_cpu *)(kernel`dpcpu_off[6] + (uintptr_t)&kernel`pcpu_entry_cc_cpu);
	this->st = (struct pcpu_state *)(kernel`dpcpu_off[6] + (uintptr_t)&kernel`pcpu_entry_timerstate);
	this->hct = *(int64_t *)(kernel`dpcpu_off[6] + (uintptr_t)&kernel`pcpu_entry_hardclocktime);
	this->pt = *(long *)(kernel`dpcpu_off[6] + (uintptr_t)&kernel`pcpu_entry_pcputicks);
	printf("cpu6 cc %p  cc_lastscan %d.%03d  cc_firstevent %d.%03d  cc_bucket %d  in corso [0] %p [1] %p\n",
	    this->cc, (this->cc->cc_lastscan) >> 32, (((this->cc->cc_lastscan) & 0xffffffff) * 1000) >> 32, (this->cc->cc_firstevent) >> 32, (((this->cc->cc_firstevent) & 0xffffffff) * 1000) >> 32, this->cc->cc_bucket,
	    this->cc->cc_exec_entity[0].cc_curr, this->cc->cc_exec_entity[1].cc_curr);
	printf("     now %d.%03d  nextevent %d.%03d  nexttick %d.%03d  nexthard %d.%03d\n",
	    (this->st->now) >> 32, (((this->st->now) & 0xffffffff) * 1000) >> 32, (this->st->nextevent) >> 32, (((this->st->nextevent) & 0xffffffff) * 1000) >> 32, (this->st->nexttick) >> 32, (((this->st->nexttick) & 0xffffffff) * 1000) >> 32, (this->st->nexthard) >> 32, (((this->st->nexthard) & 0xffffffff) * 1000) >> 32);
	printf("     nextstat %d.%03d  nextcall %d.%03d  nextcallopt %d.%03d  idle %d handle %d ipi %d action %d\n",
	    (this->st->nextstat) >> 32, (((this->st->nextstat) & 0xffffffff) * 1000) >> 32, (this->st->nextcall) >> 32, (((this->st->nextcall) & 0xffffffff) * 1000) >> 32, (this->st->nextcallopt) >> 32, (((this->st->nextcallopt) & 0xffffffff) * 1000) >> 32,
	    this->st->idle, this->st->handle, this->st->ipi, this->st->action);
	printf("     hardclocktime %d.%03d  pcputicks %d\n", (this->hct) >> 32, (((this->hct) & 0xffffffff) * 1000) >> 32, this->pt);
}

BEGIN
{
	this->cc = (struct callout_cpu *)(kernel`dpcpu_off[7] + (uintptr_t)&kernel`pcpu_entry_cc_cpu);
	this->st = (struct pcpu_state *)(kernel`dpcpu_off[7] + (uintptr_t)&kernel`pcpu_entry_timerstate);
	this->hct = *(int64_t *)(kernel`dpcpu_off[7] + (uintptr_t)&kernel`pcpu_entry_hardclocktime);
	this->pt = *(long *)(kernel`dpcpu_off[7] + (uintptr_t)&kernel`pcpu_entry_pcputicks);
	printf("cpu7 cc %p  cc_lastscan %d.%03d  cc_firstevent %d.%03d  cc_bucket %d  in corso [0] %p [1] %p\n",
	    this->cc, (this->cc->cc_lastscan) >> 32, (((this->cc->cc_lastscan) & 0xffffffff) * 1000) >> 32, (this->cc->cc_firstevent) >> 32, (((this->cc->cc_firstevent) & 0xffffffff) * 1000) >> 32, this->cc->cc_bucket,
	    this->cc->cc_exec_entity[0].cc_curr, this->cc->cc_exec_entity[1].cc_curr);
	printf("     now %d.%03d  nextevent %d.%03d  nexttick %d.%03d  nexthard %d.%03d\n",
	    (this->st->now) >> 32, (((this->st->now) & 0xffffffff) * 1000) >> 32, (this->st->nextevent) >> 32, (((this->st->nextevent) & 0xffffffff) * 1000) >> 32, (this->st->nexttick) >> 32, (((this->st->nexttick) & 0xffffffff) * 1000) >> 32, (this->st->nexthard) >> 32, (((this->st->nexthard) & 0xffffffff) * 1000) >> 32);
	printf("     nextstat %d.%03d  nextcall %d.%03d  nextcallopt %d.%03d  idle %d handle %d ipi %d action %d\n",
	    (this->st->nextstat) >> 32, (((this->st->nextstat) & 0xffffffff) * 1000) >> 32, (this->st->nextcall) >> 32, (((this->st->nextcall) & 0xffffffff) * 1000) >> 32, (this->st->nextcallopt) >> 32, (((this->st->nextcallopt) & 0xffffffff) * 1000) >> 32,
	    this->st->idle, this->st->handle, this->st->ipi, this->st->action);
	printf("     hardclocktime %d.%03d  pcputicks %d\n", (this->hct) >> 32, (((this->hct) & 0xffffffff) * 1000) >> 32, this->pt);
}

BEGIN
{
	exit(0);
}

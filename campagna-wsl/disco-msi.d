#!/usr/sbin/dtrace -qs
/*
 * Parere Opus 005 §3.1: I/O del disco da un capo all'altro, per secondo.
 * Solo kernel, nessun -p. MSI iniettati per origine e (addr, data); chiamate
 * di I/O di bhyve (backend dei dischi) con latenza; esiti VEPT_MMIO per pagina.
 */
#pragma D option dynvarsize=16m
fbt:vmm-restore:pptintr:entry { self->ppt = 1; }
fbt:vmm-restore:pptintr:return { self->ppt = 0; }
fbt:vmm-restore:lapic_intr_msi:entry
{ @msi[self->ppt ? "ppt" : execname, arg1, arg2 & 0xffff] = count(); }

syscall::pread:entry, syscall::pwrite:entry, syscall::preadv:entry, syscall::pwritev:entry
/execname == "bhyve"/
{ self->ts = timestamp; }
syscall::pread:return, syscall::pwrite:return, syscall::preadv:return, syscall::pwritev:return
/self->ts/
{ this->us = (timestamp - self->ts) / 1000; @io[probefunc] = count(); @iomax[probefunc] = max(this->us);
  @lat[probefunc] = quantize(this->us); self->ts = 0; }

fbt:vmm-restore:vmx_vept_fault:entry { self->p = arg3; }
fbt:vmm-restore:vmx_vept_fault:return /self->p && arg1 == 3/ { @mmio[*(uint64_t *)self->p >> 12] = count(); }
fbt:vmm-restore:vmx_vept_fault:return { self->p = 0; }

tick-1s
{
	printf("--- %Y\n", walltimestamp);
	printa("msi %-6s addr=%x data=%x: %@d\n", @msi);
	printa("io %-8s: %@d (max %@d us)\n", @io, @iomax);
	trunc(@mmio, 6);
	printa("mmio pagina %x000: %@d\n", @mmio);
	trunc(@msi); trunc(@io); trunc(@iomax); trunc(@mmio);
}
END { printa(@lat); }

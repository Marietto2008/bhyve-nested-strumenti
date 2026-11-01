#pragma D option quiet
pid$target::pm1_status_handler:entry { self->eax = arg4; self->in = arg1; }
pid$target::pm1_status_handler:return /self->eax/ { @v[self->in, *(uint32_t *)copyin(self->eax, 4)] = count(); self->eax = 0; }
pid$target::pm1_control_handler:entry { @c[arg1] = count(); }
tick-2s { printa("status in=%d val=%#x: %@d\n", @v); printa("control in=%d: %@d\n", @c); exit(0); }

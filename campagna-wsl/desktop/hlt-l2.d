#pragma D option quiet
/* hlt-l2.d -- Claude 04/11/2026: un HLT dell'L2 viene mai gestito da L0 invece che riflesso a Hyper-V? */
vmm:vmx:exit:entry { self->l2 = 0; self->fall = 0; }
fbt:vmm-restore:nested_l2_exit:entry { self->l2 = 1; }
fbt:vmm-restore:nested_l2_exit:return { self->fall = (arg1 == 0); @u[arg1 == 0 ? "uscite L2 lasciate ai rami di L0" : "uscite L2 instradate dal nested"] = count(); }
vmm:vmx:exit:halt /self->l2 && self->fall/ { @h["HLT dell'L2 GESTITO DA L0"] = count(); }
vmm:vmx:exit:halt /self->l2 && !self->fall/ { @h["HLT dell'L2 (instradato dal nested?)"] = count(); }
vmm:vmx:exit:halt /!self->l2/ { @h["HLT dell'L1"] = count(); }
tick-30s { printf("%Y\n", walltimestamp); printa("  %-40s %@d\n", @u); printa("  %-40s %@d\n", @h); clear(@u); clear(@h); }
tick-240s { exit(0); }

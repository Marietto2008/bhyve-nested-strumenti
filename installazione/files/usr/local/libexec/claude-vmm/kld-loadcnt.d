/* kld-loadcnt.d -- Claude 31/10/2026, #168 par. 3. Per il kld $$1: id e lf->loadcnt (contatore GLOBALE dei caricamenti,
 * kern_linker.c:709, mai riusato; l id invece si riusa). Elenco percorso fino in fondo (FINE_ELENCO=si) o nulla vale.
 * Generato (256 passi srotolati: D non ha cicli). Sola lettura: una sonda BEGIN. */
#pragma D option quiet
BEGIN { this->lf = (struct linker_file *)`linker_files.tqh_first; this->n = 0; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN /this->lf != NULL && stringof(this->lf->filename) == $$1/ { printf("KLD %s id=%d loadcnt=%d\n", stringof(this->lf->filename), this->lf->id, this->lf->loadcnt); }
BEGIN /this->lf != NULL/ { this->lf = this->lf->link.tqe_next; this->n++; }
BEGIN { printf("FINE_ELENCO=%s visitati=%d globale=%d\n", this->lf == NULL ? "si" : "NO", this->n, `loadcnt); exit(0); }

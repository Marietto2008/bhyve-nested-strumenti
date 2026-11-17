# strumenti — campagna nested/WSL2 sotto bhyve (vm0:13)

Repository creato il 17/11/2026 da Claude, su richiesta dell'utente (consiglio della diagnosi 073 par. 3.2 di Opus):
gli strumenti producono le prove su cui si basano i commit del modulo vmm (ramo wsl2-freebsd-eptad in
/mnt/linuxulator2/vm/wsl2/fbsd/freebsd-nested), e nei messaggi di quei commit si puo' citare lo sha dello strumento.

Dati e risultati NON sono qui: ../dati-bhyve/ (esiti.md, contatori.log, tracce), rapporti in ../rapporti/.

Principali:
- sorveglia-rete.sh (avviato da campagna-wsl/vm0-13-qemu.sh): segue ogni avvio di Windows, lancia rete-guasta-kit.sh se
  la rete non programma MSI-X, scrive la riga «- AVVIO» in esiti.md (con avvio-windows.sh/.ps1);
- rete-guasta-kit.sh: raccolta a VM viva (QMP, tabelle MSI-X, traccia, hypercall, contatori);
- salva-contatori.sh: invarianti del modulo caricato in esiti.md e contatori.log;
- caldo-*.sh, caldo-ricarica.sh: cambio/ricarica a caldo del modulo con le protezioni dei dispositivi ppt;
- tempesta-bhyve.sh, ciclo-amp.sh: tempeste WSL (claude-lag) con e senza amplificatore;
- serie-forma-a.sh, esperimento-riorg.sh (+ riorg-intestazione.py): prove della diagnosi 069/073 sulla rete;
- innesta-hcall.py, hcall-v2.patch: storia del registratore delle hypercall (ora nel modulo).

Esclusi (vedi .gitignore): campagna-wsl-originale/ (copia di campagna-wsl, gia' versionato altrove), binari, copie
.prima-*. Nessun file contiene la password di Windows (controllato col contenuto vero del file della password, 17/11).

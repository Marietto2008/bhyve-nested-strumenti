# Giro lungo sotto KVM (risposta di Fable al 023, §3) — promemoria per la sessione sotto Linux

Claude, 11/11/2026. Scopo: sapere se il panic con la stessa firma (`lapic_et_start`, #PF err 0x10, CR2 = RIP, RIP fermo,
non reiniettato) esiste anche con un L0 diverso. **Un solo panic sotto KVM chiude il lavoro su L0 per questo guasto.**
Per uno zero servono almeno 12 giri (240 min di tempesta), meglio 24 (una notte), con i criteri di validità rispettati.

## 1. Parità (prima di contare)
- QEMU 8.2.2 + KVM, lanciatore `lanciatori/avvia-win11-kvm.sh` con `CPU=...`:
  - **niente APICv verso l'L1**: `-cpu host,-vmx-apicv-xapic,-vmx-apicv-x2apic,-vmx-apicv-register,-vmx-apicv-vid,-vmx-posted-intr`
    (verificare i nomi con `-cpu help` / QMP; in alternativa `kvm_intel enable_apicv=0`, già N su questo host);
  - **nessuna illuminazione `hv-*`**, soprattutto niente `hv-evmcs` (non deve esserci nella riga di comando);
  - stessi 8 vCPU (1 socket, 8 core), 32 GB, stessa immagine Windows (copia in `/mnt/linuxulator2/vm/IMG`), stesso VHD
    ro7d (sha), `claude-lag 1200 100`, nessun pinning.
- **Diff degli MSR IA32_VMX_*** visti dall'L1 sotto i due L0: lettura dall'interno di un L1 Linux (rdmsr 0x480-0x492)
  sotto KVM e sotto bhyve con la stessa configurazione, oppure QMP sotto KVM contro `vmx_nested_init_msrs` sotto bhyve.
  Le differenze che restano vanno nel 024.
- **Criterio di validità del giro:** episodi 48 su fee00320/fee00380 a ~0,5 M al minuto (come bhyve a 1 s) e circa
  **6 «fermi» per svuotamento** (sotto bhyve 4,9-6,8). Se sono zero o di un altro ordine di grandezza, il giro non conta.

## 2. Conteggio
- `strumenti/kvm-episodi.bt` (schema di Fable, da provare: controllare i campi nei file `format`).
- Registratore di volo: traccia in memoria (buffer ad anello per CPU) di `kvm_page_fault`, `kvm_nested_vmexit_inject`,
  `kvm_nested_vmenter`, con trigger `traceoff` su `kvm_nested_vmenter` filtrato
  `event_inj == 0x80000b0e && (nested_rip == 0xffffffff8120b847 || nested_rip == 0xffffffff8120b831)`.
  Verificare che con la traccia accesa gli episodi al minuto non cambino.
- Riportare la distribuzione di `exit_info1` (qualificazione riflessa): sotto bhyve è 0xd82.

## 3. Condizioni
- Svuotamento a **1 s** (`svuota-vmmem.ps1 -PausaMs 1000`), **PTI forzato** nell'L2 (`AVVIO=prova-wsl-vhd-pti.ps1`
  in `tempesta-kvm.sh`, ricordando che sotto FreeBSD la variabile si chiamava PS1 e ora è AVVIO).
- Svuotamento ritardato di 120 s rispetto all'avvio di FreeBSD (`SVUOTA_RITARDO`), come sotto bhyve.

## 4. Arresto
- Al primo panic con la stessa firma: fermarsi, salvare console, traccia di volo e mappe bpftrace.
- Per lo zero: 12-24 giri validi. Riportare i panic su tre denominatori: minuti, episodi, svuotamenti.

## 5. Da riportare nel 024
Diff MSR IA32_VMX_*, distribuzione di exit_info1, episodi al minuto, fermi per svuotamento, conteggi @e0c, esito.

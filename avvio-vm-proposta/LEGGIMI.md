# Proposta (NON applicata): script di avvio VM che non distruggono le VM degli altri

29/10/2026, Claude. Gli originali **non sono stati toccati**. Qui ci sono le copie modificate (`nested/`, `nuovi/`) e
l'helper `vm-propria.sh`. Si applicano solo con il consenso dell'utente.

## Perché

Con due VM accese insieme (per esempio la NVIDIA a Windows e la Radeon a un'altra VM), oggi lanciare la seconda
**distrugge** la prima:

| script | cosa fa oggi |
|---|---|
| 7 varianti nested `12-Windows-11-*` (anche quella di default di `winrun.py`) | **due** cicli «destroying ghost vms»: `bhyvectl --destroy` su **ogni** VM di `/dev/vmm` per cui non trova un `vncviewer`. Il confronto è `grep "${session#vm}"` sugli argomenti di vncviewer: per `vm2` cerca «2», che c'è in `localhost:12`, quindi la salva **per caso** |
| le 5 varianti `-senza-gpu*` | in più `bhyvectl --vm=vm2 --destroy` senza condizioni: `vm2` è la VM di QEMU (KUT) |
| `vm-script-NUOVI/12-Windows-11-vm12` | il ciclo «ghost», più `kldunload` di **ogni** modulo vmm e `kldload` a **ogni** avvio: un cambio di modulo a caldo senza nessuna protezione, contro il suo stesso `LEGGIMI.txt` §3 |
| `vm-script-NUOVI/33-qemu-nvidia-ubuntu`, `35-qemu-amd-ubuntu` | `for v in $(ls /dev/vmm/)`: `bhyvectl --destroy` su **ogni** VM. Controllano solo che non giri un altro QEMU, non le VM bhyve: con Windows (`vm0:12`) acceso, lo uccidono |

Distruggere una VM viva che ha una GPU in passthrough è il caso peggiore per la Radeon (reset bug).

## Cosa cambia

- **`vm-propria.sh NOME`**: tocca **solo** `/dev/vmm/NOME`.
  - Se è aperto, la VM è viva: rc 1, non la tocca.
  - Se è chiuso, è un residuo: lo distrugge.
  - Non tocca mai altri nodi.
- **Varianti nested:** `bhyvectl --vm=vm0:12 --destroy` diventa `vm-propria.sh vm0:12 || exit 1`. Tolti i due cicli
  «ghost» e, nelle `-senza-gpu*`, il destroy di `vm2`.
- **`NUOVI/12-Windows-11-vm12`:** come sopra. Tolti anche `kldunload` e `kldload`: per cambiare modulo c'è
  `nested-work/caldo/modulo-caldo.sh`. Il Secondary Bus Reset su `4/0/x` resta.
- **`NUOVI/33`, `35`:** il ciclo su tutto `/dev/vmm` diventa `vm-propria.sh vm2`.

Righe diverse: 26–28 per ogni variante nested, 18 per `NUOVI/12`, 8 per `33` e per `35`. Sintassi verificata con
`sh -n`.

## Limite che resta: QEMU ha il nome fisso `vm2`

`qemu-old/accel/bhyve/bhyve-all.c` r.338 ha `#define VM_NAME "vm2"`. `do_open()` (rr.3563–3576) fa `vm_open("vm2")`
e, se la VM esiste, la **distrugge** («Close last VM if it exists»).

Quindi:
- **Windows su bhyve (`vm0:12`) + una VM QEMU (`vm2`)**: possibili insieme, con questa proposta;
- **due VM QEMU insieme** (per esempio Ubuntu con la Radeon e la KUT): **no**. La seconda distrugge la prima.

Serve un nome configurabile in QEMU (per esempio `-accel bhyve,vmname=…`) e una `do_open` che non distrugga una VM
aperta. È una modifica al codice di QEMU, fuori da questa proposta.

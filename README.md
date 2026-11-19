# bhyve-nested-strumenti

**English:** to reproduce the nested-virtualization work on your own machine, start from
[`kit/README.md`](kit/README.md) (build, one-command smoke test, known issues, reference results).

Script, lanciatori, sonde DTrace e patch del progetto di **virtualizzazione annidata
su bhyve e QEMU+bhyve** (host FreeBSD 16-CURRENT, Intel VMX): Windows 11 con Hyper-V e
WSL2 come L1, FreeBSD dentro WSL2 e Linux come L2.

Ogni ramo è un repository di lavoro a sé stante:

| ramo | contenuto |
|---|---|
| `wsl2-freebsd` | il lavoro principale: `campagna-wsl` (lanciatori di Windows vm0:13, sorveglianza della rete, script PowerShell lato Windows, sonde DTrace), `caldo` (scambio a caldo del modulo vmm), `collaudi`, `kut` (kvm-unit-tests), `wslinit` |
| `wsl2-linux` | la stessa base con L2 Linux |
| `wsl2-base` | la base comune dei due rami precedenti |
| `strumenti` | confronto KVM/bhyve: avvio di Windows, cattura del guasto di rete, esperimenti sul registro, contatori |
| `lanciatori` | i lanciatori delle VM L1 e L2, con e senza nesting |
| `patch-wsl2-freebsd` | serie di patch del kernel FreeBSD ospite di WSL2, di WSL e di WSLg |

Gli indirizzi della rete locale sono sostituiti da segnaposto (`IP-HOST`,
`IP-WINDOWS-A`, `IP-WINDOWS-B`, `IP-LAN`, `RETE-LAN.`): vanno rimessi quelli propri.

## Il resto del progetto

| repository | ramo | contenuto |
|---|---|---|
| [freebsd-src](https://github.com/Marietto2008/freebsd-src) | `vmm-nested-16` | vmm con VMX annidato (ramo di riferimento) |
| | `vmm-nested-16-lavoro` | la linea di lavoro, con i trapianti da KVM |
| | `vmm-nested-16-archivio-*` | rami laterali conservati |
| | `wsl2-freebsd-guest*` | il kernel FreeBSD ospite di WSL2 (Hyper-V, virtio-fs, WSLg) |
| | `vmm-qemu-mods-16-ottobre2026` | la base senza nesting |
| [qemu](https://github.com/Marietto2008/qemu) | `accel-vmm-freebsd-nested` | QEMU con l'acceleratore bhyve, per il nested |
| | `accel-vmm-freebsd-ottobre2026` | la base senza nesting |
| [kvm-unit-tests](https://github.com/Marietto2008/kvm-unit-tests) | `bhyve-nested` | i test VMX |
| [WSL](https://github.com/Marietto2008/WSL) | `freebsd` | WSL con l'avvio UEFI di un kernel non Linux anche su x86 |

I rami senza nesting restano separati e intatti: bhyve e QEMU si usano anche senza
virtualizzazione annidata.

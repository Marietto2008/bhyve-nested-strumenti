# Inventario delle modifiche all'host, da dichiarare con nuageinit(7)

Iniziato il 31/10/2026, su richiesta dell'utente. L'host verrà reinstallato più volte, su dischi e PC Intel diversi, con un `#cloud-config` di `nuageinit(7)` (`man 7 nuageinit`). **Ogni modifica all'host entra qui nel momento in cui la si fa.**

**Colonne:**

- **Ambito:** `comune` (ogni installazione), `macchina` (dipende dall'hardware di quel PC) oppure `profilo Claude` (solo sulle macchine dove lavora un agente Claude Code: NON nel cloud-config comune; profilo facoltativo da aggiungere a parte).
- **Voce cloud-config:** la forma con cui si dichiarerà.
- **Sorgente:** il file nel workspace da cui `write_files` prende il contenuto. I file stanno sotto `installazione/files/`, nello stesso percorso che avranno sull'host.

**Fuori inventario per regola:** i hook e la memoria di Claude Code (`~/.claude`). Non sono dell'host e nessuna funzione dell'host dipende da loro.

**Profilo Claude (01/11/2026, decisione dell'utente):** le voci 1–3 (utente `collaudo` e la sua regola sudoers) esistono solo perché su questa macchina lavora un agente Claude Code. Servono ai collaudi automatici dell'agente, e l'host non ne dipende. NON vanno nel cloud-config comune: al più in un profilo facoltativo, aggiunto solo dove gira Claude. Lo stesso vale, se mai verranno installati, per il gettone e i wrapper di root (`vmm-azione`, `vmm-lettura`, `vmm-gettone`).

## Voci

| # | data | cosa | percorso, proprietario, permessi | ambito | voce cloud-config | sorgente / nota |
|---|---|---|---|---|---|---|
| 1 | 31/10/2026 | utente e gruppo `collaudo`, senza password di login, senza sudo: esegue collaudi e mutanti | uid/gid 1003 oggi; il numero **non** è richiesto dagli strumenti, che usano il nome | **profilo Claude** | `users: - name: collaudo, gecos: "Claude collaudi senza sudo", primary_group: collaudo, homedir: <workspace>/collaudi, shell: /bin/sh, lock_passwd: true` | creato con `pw groupadd` e `pw useradd -w no` |
| 2 | 31/10/2026 | cartella home di `collaudo` | `<workspace>/collaudi`, `collaudo:collaudo`, 0755 | **profilo Claude** | creata da `users` (`homedir`); il workspace va dichiarato prima (voce 5) | — |
| 3 | 31/10/2026 | regola sudoers: marietto può diventare **solo** `collaudo` | `/usr/local/etc/sudoers.d/claude-collaudo`, `root:wheel`, 0440 | **profilo Claude** | `write_files: - path: /usr/local/etc/sudoers.d/claude-collaudo, permissions: '0440', owner: root:wheel, defer: true` (dopo il pacchetto `sudo` e l'utente) | `installazione/files/usr/local/etc/sudoers.d/claude-collaudo`, sha `0faac2c4045c15c8fcf3cb20c889f1558edd72466f12588cb74c34040cd111a7` |
| 4 | precedente | modulo `vmm-restore.ko` nested, costruito da noi | `/boot/kernel/vmm-restore.ko`, sha `149fa57e4e38c765ece111601eaf94ea785627844db215d2285e27888733d6b9` | comune | **da progettare:** pacchetto nostro o repository con sha verificato (`packages` o `runcmd`), non base64 | 3,7 MB; sorgente: clone `27125f00` |
| 5 | precedente | workspace `nested-work` | oggi `/mnt/linuxulator2/vm/wsl2/linux` sul pool `linuxulator2` | macchina | dataset ZFS e percorso da un **solo** file di configurazione | 65+ righe degli strumenti hanno il percorso fisso: da raccogliere |
| 6 | precedente | `loader.conf`: `vmm_load="YES"`, `vmm_name="vmm-restore"` | `/boot/loader.conf` | comune | `write_files` con `append: true` | — |
| 7 | precedente | `loader.conf`: `vm.pmap.ept_ipat=0` (DMA della GPU AMD in bhyve) | `/boot/loader.conf` | comune | `write_files` con `append: true` | vedi la memoria `reference_bhyve_iommu_snoop` |
| 8 | precedente | `loader.conf`: `pptdevs="3/0/0 3/0/1 4/0/0 4/0/1 4/0/2 4/0/3"` | `/boot/loader.conf` | **macchina** | `write_files` con `append: true`, nel cloud-config **di quella macchina** | gli indirizzi PCI cambiano da PC a PC |

## Preparato ma NON installato (parere Opus «wrapper di root», 01/11/2026)

Le sorgenti stanno sotto `installazione/files/`, nello stesso percorso che avranno sull'host. I wrapper caricano **solo** la libreria installata; gli sha dei programmi che `vmm-lettura` esegue senza gettone sono scritti **nella libreria installata**. Cambiarli è una reinstallazione.

| cosa | percorso, proprietario, permessi | ambito | voce cloud-config |
|---|---|---|---|
| `vmm-azione`, `vmm-lettura`, `vmm-gettone` | `/usr/local/sbin/`, `root:wheel`, 0555 | profilo Claude | `write_files`, `defer: true` |
| `gettone-lib.sh`, `sonde-opnd-v2.d`, `kld-loadcnt.d`, `ptpad-fbt-ripfix-nested.d` | `/usr/local/libexec/claude-vmm/`, `root:wheel`, 0444 | profilo Claude | `write_files` |
| `claude-vmm.conf` (`area_di_lavoro=…`) | `/usr/local/etc/claude-vmm.conf`, `root:wheel`, 0444 | **macchina** | `write_files` nel cloud-config di quella macchina |
| stato del wrapper (originali del kenv, copie degli artefatti) | `/var/db/claude-vmm-azione/`, `root:wheel`, 0700 | profilo Claude | creato dal wrapper al primo uso; dichiarabile vuoto con `runcmd: install -d -m 700` |
| registro del wrapper | `/var/log/claude-vmm-azione.log`, root | profilo Claude | creato dal wrapper |
| regole sudoers ridotte (decisione dell'utente) | `/usr/local/etc/sudoers.d/` | profilo Claude | `write_files`; sorgente `nested-work/gettone/sudoers-proposta.txt` |

## Da completare

- [ ] Rileggere tutto `/boot/loader.conf` e `/etc/rc.conf` e inventariare le altre voci che riguardano il progetto, dividendole fra comuni e per macchina.
- [ ] I pacchetti usati dagli strumenti (`sudo`, `python3`, …) come lista `packages`.
- [ ] Il file di configurazione unico del workspace (voce 5).
- [ ] Il pacchetto o repository per i binari nostri (voce 4).
- [ ] Generare il `#cloud-config` comune e quello per macchina da questo inventario, e collaudarli su una VM bhyve con un disco `cidata` prima di usarli su un PC vero.

# Full report and raw data

- `2026-11-18_nested_virtualization_performance_EN.md` — the long report (history since 20 Oct plus the
  18 Nov campaign). `RESULTS.md` one level up is the short version.
- `data/` — the raw output of every run (`banco-*.txt`, `winsat` logs) and the generated tables
  (`tabelle-20261118.md`). Runs whose result was invalid are not included.
- `banco-tabella.py data/` — regenerates the tables from the raw files; `banco-livello.sh` — the per-level
  driver that produced them (benchmark + 1 GB fsync write + network to the host).

File names and labels are in Italian: `riposo` = idle, `winaccesa` = with Windows running, `senza/con nesting` =
without/with VMX exposed, `rete_scarico/invio` = network download/upload, `disco_scrittura` = disk write.

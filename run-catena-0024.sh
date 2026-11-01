#!/bin/sh
# Claude 24/10/2026 -- pareri #39 e #40: tre corse in fila, ciascuna solo a VM spenta.
B=/mnt/linuxulator2/vm/nested-work
aspetta_vm_spenta() { k=0; while pgrep -x bhyve >/dev/null; do sleep 10; k=$((k+1)); [ $k -gt 60 ] && { echo "bhyve ancora vivo, mi fermo"; exit 1; }; done; sleep 20; }
aspetta_vm_spenta
echo "== psamp4 $(date +%T)"; sh $B/run-psamp4.sh
aspetta_vm_spenta
echo "== famB2 $(date +%T)"; sh $B/run-famB2.sh
aspetta_vm_spenta
echo "== gap3 $(date +%T)"; sh $B/run-gap3.sh 480
echo "== FINE CATENA $(date +%T)"

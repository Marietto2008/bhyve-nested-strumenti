sysctl vm.pmap.pti vm.pmap.pcid_enabled vm.pmap.invpcid_works kern.eventtimer.timer kern.eventtimer.periodic hw.mds_disable_state 2>&1; dmesg | grep -i -e pti -e "page table isolation" | head -3

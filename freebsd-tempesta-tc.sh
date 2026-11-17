sysctl kern.timecounter.hardware=Hyper-V > /dev/console
sysctl kern.timecounter.hardware kern.timecounter.choice kern.eventtimer.timer > /dev/console
/usr/local/bin/claude-lag 1200 100 | tee /dev/console

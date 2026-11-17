sysctl kern.eventtimer.timer=Hyper-V > /dev/console
sysctl kern.eventtimer.timer kern.eventtimer.choice > /dev/console
/usr/local/bin/claude-lag 1200 100 | tee /dev/console

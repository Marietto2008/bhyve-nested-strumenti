mkdir -p /tmp/wslg-runtime; : > /tmp/wslg-runtime/weston.log
env WESTON_RDP_DEBUG_LEVEL=5 wslg-avvia rail > /tmp/wslg-avvia.log 2>&1 & true
sleep 30
env DISPLAY=:0 xclock > /tmp/xclock.log 2>&1 & true
sleep 90
grep -n -i -E 'gfx|surface|window|frame|commit|error|fail|codec|map' /tmp/wslg-runtime/weston.log | grep -v 'ClientGetAppidReq\|ClientSysparam' | tail -110
wc -l /tmp/wslg-runtime/weston.log
echo ==== wslg-avvia.log; cat /tmp/wslg-avvia.log
echo ==== weston.log fine; tail -40 /tmp/wslg-runtime/weston.log

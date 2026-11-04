echo ==== prima; ls -la /tmp/.X11-unix/ /tmp/.X*-lock 2>&1; for f in /tmp/.X*-lock; do [ -f $f ] && echo $f pid=$(cat $f); done
mkdir -p /tmp/wslg-runtime; : > /tmp/wslg-runtime/weston.log
wslg-avvia rail > /tmp/wslg-avvia.log 2>&1 & true
sleep 30
env DISPLAY=:0 xclock > /tmp/xclock.log 2>&1 & true
sleep 60
echo ==== xclock.log; cat /tmp/xclock.log
echo ==== weston xwayland; grep -i -E 'xwayland|xserver|display :' /tmp/wslg-runtime/weston.log
echo ==== wslg-avvia.log; cat /tmp/wslg-avvia.log

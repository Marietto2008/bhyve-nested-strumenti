cat /tmp/wslg-avvia.log | grep -v -e xkbcomp -e Warning -e Using -e '^>' ; echo ==== weston; grep -v -e 'ClientSysparam' -e 'gfxredir_caps' /tmp/wslg-runtime/weston.log | tail -60

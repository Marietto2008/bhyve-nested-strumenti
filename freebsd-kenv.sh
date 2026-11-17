kenv | grep -i -e pmap -e rootdev -e console -e boot_ -e loader | head -20; ls /boot/loader.conf* /boot/loader.conf.d 2>&1; cat /boot/loader.conf 2>&1 | head -30

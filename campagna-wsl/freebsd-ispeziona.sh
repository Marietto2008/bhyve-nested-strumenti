echo ==== utente; id marietto; grep -A3 '^\[user\]' /etc/wsl.conf; grep marietto /etc/master.passwd | cut -d: -f1,2 | sed 's/:\$.*/:HASH/'
echo ==== pacchetti; pkg info -e xdm && echo xdm; pkg info -e xephyr && echo xephyr; pkg info -e xfce && echo xfce; pkg info -e xfce4-session && echo xfce4-session; pkg info -e dbus && echo dbus; pkg info -e lightdm && echo lightdm
echo ==== spazio; df -h / | tail -1
echo ==== pam; ls /etc/pam.d/ | tr '\n' ' '
echo; echo ==== rete; host -t a pkg.freebsd.org 2>&1 | head -1

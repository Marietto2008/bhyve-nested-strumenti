#!/bin/sh
# freebsd-prepara.sh -- Claude 04/11/2026. Una volta, come root: xdm + Xephyr + XFCE, password di marietto (a),
# ~/.xsession con XFCE, /usr/local/sbin/claude-desktop.
env ASSUME_ALWAYS_YES=yes pkg install -y xdm sessreg xephyr xfce xfce4-terminal xauth xrdb xsetroot xdpyinfo \
	xorg-fonts-truetype > /var/log/claude-pkg.log 2>&1
echo pkg=$?; tail -3 /var/log/claude-pkg.log
echo a | pw usermod marietto -h 0 && echo 'password di marietto: a'
fetch -q -o /home/marietto/.xsession http://IP-HOST:8765/xsession
chmod 755 /home/marietto/.xsession && chown marietto:marietto /home/marietto/.xsession
fetch -q -o /usr/local/sbin/claude-desktop http://IP-HOST:8765/claude-desktop-freebsd && chmod 755 /usr/local/sbin/claude-desktop
ls -l /usr/local/sbin/claude-desktop; which Xephyr xdm startxfce4 xdpyinfo

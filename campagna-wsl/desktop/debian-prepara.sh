#!/bin/sh
# debian-prepara.sh -- Claude 04/11/2026. Una volta, come root: xdm + Xephyr + XFCE, utente marietto (password a),
# ~/.xsession con XFCE, /usr/local/sbin/claude-desktop. Il servizio xdm resta SPENTO (mascherato): in WSL lo schermo
# :0 e' di WSLg, xdm va solo sul display di Xephyr lanciato da claude-desktop.
export DEBIAN_FRONTEND=noninteractive
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d && chmod 755 /usr/sbin/policy-rc.d
apt-get update -q > /var/log/claude-apt.log 2>&1
apt-get install -y -q --no-install-recommends xdm xserver-xephyr xfce4 xfce4-terminal dbus-x11 x11-utils \
	x11-xserver-utils xauth fonts-dejavu-core xfonts-base adwaita-icon-theme curl >> /var/log/claude-apt.log 2>&1
echo apt=$?; tail -2 /var/log/claude-apt.log
mv /usr/sbin/policy-rc.d /root/policy-rc.d.claude
systemctl mask xdm.service; systemctl is-enabled xdm.service
id marietto > /dev/null 2>&1 || useradd -m -s /bin/bash marietto
echo marietto:a | chpasswd && echo 'password di marietto: a'
curl -s -o /home/marietto/.xsession http://IP-HOST:8765/xsession
chmod 755 /home/marietto/.xsession && chown marietto:marietto /home/marietto/.xsession
curl -s -o /usr/local/sbin/claude-desktop http://IP-HOST:8765/claude-desktop-debian && chmod 755 /usr/local/sbin/claude-desktop
ls -l /usr/local/sbin/claude-desktop; which Xephyr xdm startxfce4 xdpyinfo

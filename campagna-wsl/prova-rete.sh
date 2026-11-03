echo ==== ifconfig; ifconfig -a
echo ==== rotte; netstat -rn -f inet
echo ==== resolv.conf; cat /etc/resolv.conf
echo ==== ping gateway; ping -c 2 -t 5 $(netstat -rn -f inet | awk '/^default/{print $2}')
echo ==== ping 1.1.1.1; ping -c 2 -t 5 1.1.1.1
echo ==== dns; host -W 5 www.freebsd.org
echo ==== fetch; fetch -T 10 -o - http://ip-api.com/line/?fields=query,country,isp 2>&1 | head -5

uname -sr
ping -c 10 1.1.1.1 | tail -3
fetch -o /dev/null http://speedtest.tele2.net/10MB.zip 2>&1 | tail -1

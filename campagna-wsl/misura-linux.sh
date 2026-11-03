uname -sr
ping -c 10 1.1.1.1 | tail -3
command -v curl wget fetch
curl -s -o /dev/null -w 'curl 10MB: %{speed_download} B/s in %{time_total} s\n' http://speedtest.tele2.net/10MB.zip

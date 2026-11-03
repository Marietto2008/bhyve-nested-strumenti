daemon -f sh -c 'while :; do uname -a | nc -l -N 8080; done'
sleep 3
sockstat -46 -l -P tcp | grep -w 8080

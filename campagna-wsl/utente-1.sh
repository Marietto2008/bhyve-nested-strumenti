id
pw usershow marietto >/dev/null 2>&1 || pw useradd marietto -m -G wheel -s /bin/sh -c Marietto
printf %s\\n [user] default=marietto > /etc/wsl.conf
cat /etc/wsl.conf
pw usershow marietto

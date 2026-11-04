env ASSUME_ALWAYS_YES=yes pkg install -f -y sessreg > /var/log/claude-pkg-sessreg.log 2>&1; echo pkg=$?; sync; ls -l /usr/local/bin/sessreg; pkg check -s xdm xfce 2>&1 | tail -3

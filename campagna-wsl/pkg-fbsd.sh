date
env ASSUME_ALWAYS_YES=yes pkg bootstrap -f 2>&1 | tail -3
pkg -v
env ASSUME_ALWAYS_YES=yes pkg update 2>&1 | tail -3
pkg search -q ^htop- | head -2
df -h / | tail -1
date

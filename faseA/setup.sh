#!/bin/bash
# Claude 20/10/2026 fase A (parere #23): rete e pacchetti in Debian/WSL2
exec > /mnt/c/claude/faseA/setup.log 2>&1
set -x
date -u; uname -a; nproc; free -m
ip -4 addr show eth0; cat /etc/resolv.conf
getent hosts deb.debian.org
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y stress-ng build-essential bc flex bison libssl-dev libelf-dev wget xz-utils python3 cpio
gcc --version | head -1; stress-ng --version
df -h / /mnt/c
echo SETUP-FINE

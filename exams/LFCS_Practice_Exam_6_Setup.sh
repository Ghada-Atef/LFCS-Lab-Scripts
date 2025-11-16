#!/bin/bash
# =====================================================================
# LFCS Practice Exam 6 – Environment Setup (Cross-Distro Safe Edition)
# (FINAL v2 - Adds -y to pvcreate to make it non-interactive)
# =====================================================================

set -e
echo "==============================================================="
echo "🔧 Starting environment setup for LFCS Practice Exam 6..."
echo "==============================================================="

# -------------------------
# Cross-Distribution Detection
# -------------------------
if [ -f /etc/redhat-release ]; then
    DISTRO="rhel"
    PKG_INSTALL="sudo dnf install -y"
    VERIFY_PKG="dnf-plugins-core"
    SEMANAGE_PKG="policycoreutils-python-utils"
    NETCAT_PKG="nmap-ncat"
    NC_QUIT_FLAG=""
elif [ -f /etc/debian_version ]; then
    DISTRO="debian"
    PKG_INSTALL="sudo apt install -y"
    VERIFY_PKG="debsums"
    SEMANAGE_PKG="semanage-utils"
    NETCAT_PKG="netcat-openbsd"
    NC_QUIT_FLAG="-q 1"
else
    echo "⚠️  Unsupported distribution. Use RHEL/Alma/Rocky or Ubuntu."
    exit 1
fi
echo "[*] Detected distribution: $DISTRO"

# -------------------------
# Install minimal required packages
# -------------------------
echo "[*] Installing required packages..."
$PKG_INSTALL git openssl mdadm xfsprogs rsync $NETCAT_PKG \
    podman $VERIFY_PKG $SEMANAGE_PKG nginx zip iotop sysstat \
    chrony policycoreutils-python-utils || true

# -------------------------
# Task 1 – Software Package Validation
# -------------------------
echo "[*] Task 1: Simulating 'coreutils' corruption..."
chmod 700 /usr/bin/ls || true

# -------------------------
# Task 3 – Package Ownership
# -------------------------
echo "[*] Task 3: Ensuring 'zip' package is installed..."
$PKG_INSTALL zip || true
podman pull alpine >/dev/null 2>&1 || true

# -------------------------
# Task 4 – SELinux Port Labeling
# -------------------------
echo "[*] Task 4: Configuring Nginx to fail on non-standard port 8088..."
sed -i 's/listen       80;/listen       8088;/g' /etc/nginx/nginx.conf || true
sed -i 's/listen       \[::\]:80;/listen       \[::\]:8088;/g' /etc/nginx/nginx.conf || true
systemctl restart nginx || echo "Nginx failed to start, as expected for Task 4."

# -------------------------
# Task 7 – Advanced Packet Filtering
# -------------------------
echo "[*] Task 7: Adding IP 198.51.100.10 to loopback for rule testing..."
ip addr add 198.51.100.10/24 dev lo || true

# -------------------------
# Task 9 – Detailed Socket Investigation
# -------------------------
echo "[*] Task 9: Starting a listener on port 9988..."
( while true; do echo -e "HTTP/1.1 200 OK\r\n\r\n" | nc -l -p 9988 $NC_QUIT_FLAG; done ) &

# -------------------------
# Task 11 – LVM Management
# -------------------------
echo "[*] Task 11: Preparing LVM setup for /dev/sdb..."
if [ -b /dev/sdb ] && ! lsblk -no MOUNTPOINTS "/dev/sdb" | grep -q "/"; then
    (echo n; echo p; echo 1; echo ; echo -1G; echo w) | fdisk /dev/sdb >/dev/null 2>&1 || true
    (echo n; echo p; echo 2; echo ; echo ; echo w) | fdisk /dev/sdb >/dev/null 2>&1 || true
    partprobe /dev/sdb || true
    # FIX: Add -y to pvcreate to automatically wipe signatures
    pvcreate -y /dev/sdb1 || true
    vgcreate vg-main /dev/sdb1 || true
else
    echo "⚠️  /dev/sdb not found or is in use — skipping LVM setup for Task 11."
fi

# -------------------------
# Task 12 – Disk Space Troubleshooting
# -------------------------
echo "[*] Task 12: Creating partition /dev/sde1..."
if [ -b /dev/sde ] && ! lsblk -no MOUNTPOINTS "/dev/sde" | grep -q "/"; then
    (echo n; echo p; echo 1; echo ; echo ; echo w) | fdisk /dev/sde >/dev/null 2>&1 || true
    partprobe /dev/sde || true
    # The partition is left unformatted for the student
else
    echo "⚠️  /dev/sde not found or is in use — skipping partition setup for Task 12."
fi

# -------------------------
# Task 13 – Monitor I/O Performance
# -------------------------
echo "[*] Task 13: Starting continuous background I/O..."
( while true; do
    dd if=/dev/zero of=/tmp/io_load.tmp bs=1M count=20 status=none
    rm -f /tmp/io_load.tmp
    sleep 1
  done ) &

# -------------------------
# Task 14 – RAID Array Recovery
# -------------------------
echo "[*] Task 14: Creating degraded /dev/md1 and spare /dev/sdc1..."
if [ -b /dev/sdd ] && [ -b /dev/sdc ]; then
    if lsblk -no MOUNTPOINTS "/dev/sdd" | grep -q "/" || lsblk -no MOUNTPOINTS "/dev/sdc" | grep -q "/"; then
        echo "⚠️  /dev/sdd or /dev/sdc is in use. Skipping Task 14."
    else
        (echo n; echo p; echo 1; echo ; echo ; echo w) | fdisk /dev/sdd >/dev/null 2>&1 || true
        (echo n; echo p; echo 1; echo ; echo ; echo w) | fdisk /dev/sdc >/dev/null 2>&1 || true
        partprobe /dev/sdd || true
        partprobe /dev/sdc || true
        mdadm --stop /dev/md1 >/dev/null 2>&1 || true
        mdadm --zero-superblock /dev/sdd1 >/dev/null 2>&1 || true
        mdadm --zero-superblock /dev/sdc1 >/dev/null 2>&1 || true
        yes | sudo mdadm --create /dev/md1 --level=1 --raid-devices=2 /dev/sdd1 missing --force || true
    fi
else
    echo "⚠️  /dev/sdc or /dev/sdd not found — skipping RAID setup for Task 14."
fi

# -------------------------
# Task 15 – Certificate and Key Matching
# -------------------------
echo "[*] Task 15: Creating matching key/cert in /etc/pki/tls/..."
mkdir -p /etc/pki/tls/{private,certs}
openssl req -x509 -nodes -newkey rsa:2048 \
 -keyout /etc/pki/tls/private/server.key \
 -out /etc/pki/tls/certs/server.crt \
 -days 365 -subj "/CN=lfcs.local" >/dev/null 2>&1 || true

# -------------------------
# Task 17 – Git Branch Management
# -------------------------
echo "[*] Task 17: Preparing Git repo for rebase exercise..."
mkdir -p /opt/lfcs_repo
cd /opt/lfcs_repo
if [ ! -d ".git" ]; then
    git init >/dev/null 2>&1
    git config --global user.email "lab@example.com"
    git config --global user.name "Lab User"
    echo "Initial" > file.txt
    git add file.txt && git commit -m "Initial" >/dev/null 2>&1
    git checkout -b new-login-form >/dev/null 2>&1
    echo "WIP on login form" > login.txt
    git add login.txt && git commit -m "Login form feature" >/dev/null 2>&1
    git checkout main >/dev/null 2>&1
    echo "Main update" > main_update.txt
    git add main_update.txt && git commit -m "Main update" >/dev/null 2>&1
    git checkout new-login-form >/dev/null 2>&1
else
    echo "⚠️ Git repo already exists. Skipping init."
fi
cd /

# -------------------------
# Task 18 – File Searching and Archiving
# -------------------------
echo "[*] Task 18: Creating recently modified files..."
DEFAULT_USER=$(id -un 1000 2>/dev/null || logname 2>/dev/null || echo "rocky")
mkdir -p /home/$DEFAULT_USER
touch /home/$DEFAULT_USER/recent_report.log
touch /home/$DEFAULT_USER/old_file.log
touch -d "2 days ago" /home/$DEFAULT_USER/old_file.log || true

# -------------------------
# Task 19 – User Account Management
# -------------------------
echo "[*] Task 19: Creating user 'temp_worker'..."
if ! id temp_worker >/dev/null 2>&1; then
    useradd -m temp_worker || true
    echo "temp_worker:password" | chpasswd || true
fi

# -------------------------
# Finalization
# -------------------------
echo "[*] Finalizing and reloading systemd services..."
systemctl daemon-reload || true

echo ""
echo "==============================================================="
echo "✅ LFCS Practice Exam 6 environment setup complete!"
echo "==============================================================="
echo "You can now proceed with the tasks in the LFCS Practice Exam 6."
echo "==============================================================="

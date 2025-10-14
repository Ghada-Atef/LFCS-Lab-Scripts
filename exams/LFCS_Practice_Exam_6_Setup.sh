#!/bin/bash
# =====================================================================
# LFCS Practice Exam 6 – Environment Setup (Cross-Distro Safe Edition)
# =====================================================================

set -euo pipefail
echo "==============================================================="
echo "🔧 Starting environment setup for LFCS Practice Exam 6..."
echo "==============================================================="

# -------------------------
# Cross-Distribution Detection
# -------------------------
if [ -f /etc/redhat-release ]; then
    DISTRO="rhel"
    PKG_INSTALL="sudo dnf install -y"
    FIREWALL_CMD="firewall-cmd"
    NOGROUP="nobody:nobody"
    NFS_SERVICE="nfs-server"
elif [ -f /etc/debian_version ]; then
    DISTRO="debian"
    PKG_INSTALL="sudo apt install -y"
    FIREWALL_CMD="ufw"
    NOGROUP="nobody:nogroup"
    NFS_SERVICE="nfs-kernel-server"
else
    echo "⚠️  Unsupported distribution. Use RHEL/Alma/Rocky or Ubuntu."
    exit 1
fi
echo "[*] Detected distribution: $DISTRO"

# -------------------------
# Basic pre-checks
# -------------------------
if ! command -v systemctl >/dev/null 2>&1; then
    echo "❌  systemd not detected. This lab requires systemd-based systems."
    exit 1
fi

# -------------------------
# Install minimal required packages (best-effort)
# -------------------------
echo "[*] Installing required packages (best-effort)..."
$PKG_INSTALL git openssl nmap-util mdadm xfsprogs rsync netcat-openbsd || true

# -------------------------
# Task 1 – Safe package/file-validation exercise
# Instead of corrupting system binaries, create a safe test file to verify package checks.
# -------------------------
echo "[*] Task 1: Preparing safe package/file verification scenario..."
TEST_DIR="/opt/lfcs_verify"
mkdir -p "$TEST_DIR"
# create a benign file that the verification exercise can reference
echo "This file simulates a modified package file for verification tasks." > "${TEST_DIR}/modified-file.txt"
chmod 644 "${TEST_DIR}/modified-file.txt"

# -------------------------
# Task 2 – System Target Management
# (Do NOT change default target; provide a safe copy and instructions)
# -------------------------
echo "[*] Task 2: Preparing target-management exercise (non-destructive)..."
# create a helper file indicating how to safely switch targets during exercise
cat > "${TEST_DIR}/target_switch_instructions.txt" <<'EOF'
Safe exercise: To test default target changes without affecting the base system,
use 'systemctl isolate graphical.target' from a non-root user session OR create a transient unit.
Do NOT permanently set-default in this lab unless you want the change persisted.
EOF

# -------------------------
# Task 3 – Ensure zip package exists (or simulate)
# -------------------------
echo "[*] Task 3: Ensuring zip is available..."
if ! command -v zip >/dev/null 2>&1; then
    $PKG_INSTALL zip || true
fi

# -------------------------
# Task 4 – SELinux user constraints exercise (create user)
# -------------------------
echo "[*] Task 4: Creating user 'intern_user' for SELinux exercise..."
if ! id intern_user >/dev/null 2>&1; then
    useradd -m intern_user || true
fi

# -------------------------
# Task 7 – Add IP for advanced packet filtering test (if interface exists)
# -------------------------
echo "[*] Task 7: Adding example IP 198.51.100.10 to eth1 if present..."
if ip link show eth1 >/dev/null 2>&1; then
    ip addr add 198.51.100.10/24 dev eth1 || true
else
    echo "⚠️  eth1 not present — skipping IP addition for Task 7."
fi

# -------------------------
# Task 9 – Socket listener on a specific port for ss/sshd troubleshooting
# -------------------------
echo "[*] Task 9: Starting a listener on port 9988..."
( while true; do echo -e "HTTP/1.1 200 OK\r\n\r\n" | nc -l -p 9988 -q 1; done ) &

# -------------------------
# Task 11 – LVM management (create small VG if /dev/sdb1 exists)
# -------------------------
echo "[*] Task 11: Preparing LVM scenario if /dev/sdb exists..."
if [ -b /dev/sdb ]; then
    if ! vgs vg-main >/dev/null 2>&1; then
        pvcreate /dev/sdb >/dev/null 2>&1 || true
        vgcreate vg-main /dev/sdb >/dev/null 2>&1 || true
    fi
    # create a small partition if not present
    if ! lvs vg-main/lv-test >/dev/null 2>&1; then
        lvcreate -n lv-test -L 1G vg-main >/dev/null 2>&1 || true
        mkfs.ext4 /dev/vg-main/lv-test >/dev/null 2>&1 || true
        mkdir -p /mnt/lv-test && mount /dev/vg-main/lv-test /mnt/lv-test >/dev/null 2>&1 || true
    fi
else
    echo "⚠️  /dev/sdb not found — skipping LVM creation."
fi

# -------------------------
# Task 12 – Disk partitioning for /dev/sde (safe: only if block exists)
# -------------------------
echo "[*] Task 12: Partition /dev/sde if present (safe checks)..."
if [ -b /dev/sde ]; then
    # create single partition non-destructively if no partitions exist
    if ! lsblk /dev/sde | grep -q sde1; then
        (echo n; echo p; echo 1; echo; echo; echo w) | fdisk /dev/sde || true
        partprobe || true
    else
        echo "⚠️  /dev/sde already partitioned — skipping fdisk."
    fi
else
    echo "⚠️  /dev/sde not found — skipping partitioning."
fi

# -------------------------
# Task 13 – I/O load generator (non-permanent, background)
# -------------------------
echo "[*] Task 13: Starting a controlled background disk I/O generator (temporary)..."
# run short dd in background to create measurable I/O without harming the system
( dd if=/dev/zero of=/tmp/io_load.tmp bs=1M count=128 status=none && sleep 5 && rm -f /tmp/io_load.tmp ) &

# -------------------------
# Task 14 – RAID array (create a degraded array only if devices exist)
# -------------------------
echo "[*] Task 14: Creating degraded RAID1 on available loop devices (safe mode)..."
# Safe approach: create loop files and use them for RAID instead of real disks
LOOP1="/tmp/raidloop1.img"
LOOP2="/tmp/raidloop2.img"
if [ ! -f "$LOOP1" ]; then
    fallocate -l 50M "$LOOP1" || true
fi
if [ ! -f "$LOOP2" ]; then
    fallocate -l 50M "$LOOP2" || true
fi
losetup -fP "$LOOP1" >/dev/null 2>&1 || true
losetup -fP "$LOOP2" >/dev/null 2>&1 || true
LO1=$(losetup -j "$LOOP1" | cut -d: -f1 || echo "")
LO2=$(losetup -j "$LOOP2" | cut -d: -f1 || echo "")
if [ -n "$LO1" ] && [ -n "$LO2" ]; then
    mdadm --create /dev/md1 --level=1 --raid-devices=2 "$LO1" missing --force >/dev/null 2>&1 || true
    # leave it degraded by design
fi

# -------------------------
# Task 15 – Certificates (create private key and CSR)
# -------------------------
echo "[*] Task 15: Creating a test private key and self-signed cert..."
mkdir -p /opt/lfcs_keys
openssl genpkey -algorithm RSA -out /opt/lfcs_keys/server.key 2048 >/dev/null 2>&1 || true
openssl req -x509 -new -nodes -key /opt/lfcs_keys/server.key -days 365 \
    -subj "/CN=lfcs.local" -out /opt/lfcs_keys/server.crt >/dev/null 2>&1 || true

# -------------------------
# Task 17 – Git branch exercise
# -------------------------
echo "[*] Task 17: Preparing Git repo for rebase/merge exercises..."
if [ -d /opt/lfcs_repo ]; then
    cd /opt/lfcs_repo || true
else
    mkdir -p /opt/lfcs_repo
    cd /opt/lfcs_repo
    git init >/dev/null 2>&1 || true
    echo "Initial" > file.txt
    git add file.txt && git commit -m "Initial" || true
fi
git checkout -b new-login-form >/dev/null 2>&1 || true
echo "WIP on login form" > login.txt
git add login.txt && git commit -m "Login form feature" || true
git checkout main >/dev/null 2>&1 || true
echo "Main update" > main_update.txt
git add main_update.txt && git commit -m "Main update" || true
git checkout new-login-form >/dev/null 2>&1 || true
cd / || true

# -------------------------
# Task 18 – Recent files simulation
# -------------------------
echo "[*] Task 18: Creating recently modified files in default user home..."
DEFAULT_USER=$(logname 2>/dev/null || echo "root")
mkdir -p "/home/${DEFAULT_USER}"
touch "/home/${DEFAULT_USER}/report-$(date +%F).log"
touch "/home/${DEFAULT_USER}/data.csv"

# -------------------------
# Task 19 – Lock/unlock account exercise
# -------------------------
echo "[*] Task 19: Creating temp_worker user to lock/unlock..."
if ! id temp_worker >/dev/null 2>&1; then
    useradd -m temp_worker || true
    # set password using chpasswd portable method
    echo "temp_worker:password" | chpasswd || true
fi

# -------------------------
# Finalization: reload systemd and give summary
# -------------------------
echo "[*] Finalizing and reloading systemd services..."
systemctl daemon-reload || true

echo ""
echo "==============================================================="
echo "✅ LFCS Practice Exam 6 environment setup complete!"
echo "Summary of notable actions:"
echo " - Safe test files created under ${TEST_DIR}"
echo " - I/O, listeners, and Git repo prepared"
echo " - RAID simulated using loopback devices (degraded by design)"
echo " - Certificates created under /opt/lfcs_keys"
echo " - LVM/partitioning attempted only if block devices present"
echo "==============================================================="
echo "You can now proceed with the tasks in the LFCS Practice Exam 6."
echo "==============================================================="
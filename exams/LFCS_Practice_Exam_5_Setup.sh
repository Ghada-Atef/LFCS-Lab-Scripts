#!/bin/bash
# =====================================================================
# LFCS Practice Exam 5 – Environment Setup (Cross-Distro Safe Edition)
# =====================================================================

set -e
echo "==============================================================="
echo "🧩 Starting environment setup for LFCS Practice Exam 5..."
echo "==============================================================="

# ---------------------------------------------------------------------
# Cross-Distribution Detection
# ---------------------------------------------------------------------
if [ -f /etc/redhat-release ]; then
    DISTRO="rhel"
    PKG_INSTALL="sudo dnf install -y"
    FIREWALL_CMD="firewall-cmd"
    NOGROUP="nobody:nobody"
    NFS_SERVICE="nfs-server"
    SYSSTAT_PKG="sysstat"
    DOSFS_PKG="dosfstools"
elif [ -f /etc/debian_version ]; then
    DISTRO="debian"
    PKG_INSTALL="sudo apt install -y"
    FIREWALL_CMD="ufw"
    NOGROUP="nobody:nogroup"
    NFS_SERVICE="nfs-kernel-server"
    SYSSTAT_PKG="sysstat"
    DOSFS_PKG="dosfstools"
else
    echo "⚠️ Unsupported distribution. Use RHEL, AlmaLinux, Rocky, or Ubuntu."
    exit 1
fi
echo "[*] Detected Linux Distribution: $DISTRO"

# ---------------------------------------------------------------------
# Pre-Checks
# ---------------------------------------------------------------------
if ! command -v systemctl >/dev/null; then
    echo "❌ systemd is required but not found. Aborting setup."
    exit 1
fi

# ---------------------------------------------------------------------
# Install Required Packages
# ---------------------------------------------------------------------
echo "[*] Installing required tools..."
$PKG_INSTALL nginx git podman net-tools nfs-utils mdadm $SYSSTAT_PKG $DOSFS_PKG autofs || true

# ---------------------------------------------------------------------
# Task 2 – Container Resource Management
# ---------------------------------------------------------------------
echo "[*] Task 2: Creating dummy 'compute-intensive' container and pre-pulling images..."
if command -v podman >/dev/null; then
    podman rm -f compute-intensive >/dev/null 2>&1 || true
    podman run -d --name compute-intensive alpine sleep 3600 || true
    podman pull ubuntu:latest || true
else
    echo "⚠️ Podman not installed; skipping container setup."
fi

# ---------------------------------------------------------------------
# Task 3 – Local Package Installation
# ---------------------------------------------------------------------
echo "[*] Task 3: Creating dummy RPM file for installation task..."
mkdir -p /mnt/repo
touch /mnt/repo/legacy-tool-1.2-1.rpm

# ---------------------------------------------------------------------
# Task 4 – Job Scheduling (atd)
# ---------------------------------------------------------------------
echo "[*] Task 4: Creating script for 'atd' task..."
cat > /usr/local/bin/generate-report.sh <<'EOF'
#!/bin/bash
echo "One-time report ran at $(date)" >> /var/log/atd_report.log
EOF
chmod +x /usr/local/bin/generate-report.sh
systemctl enable --now atd || true

# ---------------------------------------------------------------------
# Task 5 – SELinux Troubleshooting
# ---------------------------------------------------------------------
if [ "$DISTRO" = "rhel" ]; then
    echo "[*] Task 5: Creating mislabeled SELinux directory..."
    mkdir -p /var/www/special_app
    echo "SELinux test page" > /var/www/special_app/index.html
    # Apply an incorrect context (var_t) instead of httpd_sys_content_t
    chcon -t var_t /var/www/special_app -R || true
fi

# ---------------------------------------------------------------------
# Task 8 – SSH Tunneling
# ---------------------------------------------------------------------
echo "[*] Task 8: Setting up simulated database server..."
ip addr add 10.100.1.50/24 dev eth1 || true
( while true; do echo -e "HTTP/1.1 200 OK\r\n\r\nSimulated DB Server OK" | nc -l -p 3306 -q 1; done ) &

# ---------------------------------------------------------------------
# Task 11 – Persistent Mounting (by-path)
# ---------------------------------------------------------------------
echo "[*] Task 11: Creating vfat partition on /dev/sdb1..."
if [ -b /dev/sdb ]; then
    (echo n; echo p; echo 1; echo ; echo ; echo w) | fdisk /dev/sdb >/dev/null 2>&1 || true
    partprobe /dev/sdb || true
    mkfs.vfat /dev/sdb1 || true
    mkdir -p /mnt/usb-disk
else
    echo "⚠️ /dev/sdb not found; skipping Task 11 setup."
fi

# ---------------------------------------------------------------------
# Task 12 – LVM Swap Volume
# ---------------------------------------------------------------------
echo "[*] Task 12: Creating Volume Group 'vg-system'..."
if [ -b /dev/sdc ]; then
    pvcreate /dev/sdc || true
    vgcreate vg-system /dev/sdc || true
else
    echo "⚠️ /dev/sdc not found; skipping Task 12 setup."
fi

# ---------------------------------------------------------------------
# Task 13 – Configure Filesystem Automounter
# ---------------------------------------------------------------------
echo "[*] Task 13: Setting up NFS server for autofs..."
ip addr add 10.80.1.10/24 dev eth1 || true
mkdir -p /export/home/jdoe
echo "This is jdoe's remote home directory." > /export/home/jdoe/test.txt
chown $NOGROUP /export/home/jdoe
id jdoe &>/dev/null || useradd jdoe
echo "/export/home *(rw,sync,no_subtree_check)" > /etc/exports
systemctl enable --now $NFS_SERVICE || true
exportfs -ra || true

# ---------------------------------------------------------------------
# Task 14 – RAID Management
# ---------------------------------------------------------------------
echo "[*] Task 14: Creating degraded RAID 1 array on /dev/md0..."
# This creates a degraded array using /dev/sdd, leaving /dev/sde as the spare
if [ -b /dev/sdd ] && [ -b /dev/sde ]; then
    # Stop any existing array and zero superblock
    mdadm --stop /dev/md0 >/dev/null 2>&1 || true
    mdadm --zero-superblock /dev/sdd >/dev/null 2>&1 || true
    mdadm --zero-superblock /dev/sde >/dev/null 2>&1 || true
    # Create a new degraded array with /dev/sdd as the only active disk
    mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdd missing --force || true
else
    echo "⚠️ /dev/sdd or /dev/sde not found; skipping Task 14 setup."
fi

# ---------------------------------------------------------------------
# Task 16 – Git Version Control (cherry-pick)
# ---------------------------------------------------------------------
echo "[*] Task 16: Creating Git repo and commit for cherry-pick..."
mkdir -p /opt/app-config
cd /opt/app-config
git init
git config --global user.email "lab@example.com"
git config --global user.name "Lab User"
echo "v1" > file.txt; git add .; git commit -m "Initial commit"
git checkout -b production
echo "v1-prod" > prod.txt; git add .; git commit -m "Production feature"
git checkout main
echo "This is the bugfix" > bug.txt; git add .; git commit -m "Fix bug #123"
# Get the hash of the commit we just made
CHERRY_PICK_HASH=$(git log -n 1 --pretty=format:%h)
echo "v2" > file.txt; git add .; git commit -m "Main update"
# Save the hash to a file for the student
echo "The commit hash to cherry-pick is: $CHERRY_PICK_HASH" > /opt/app-config/CHERRY_PICK_HASH.txt
cd /

# ---------------------------------------------------------------------
# Task 17 – Archiving and Splitting Files
# ---------------------------------------------------------------------
echo "[*] Task 17: Creating 500MB log file..."
mkdir -p /var/log/app_archive
fallocate -l 500M /var/log/app_archive/large.log || true

# ---------------------------------------------------------------------
# Task 19 – Sudo Configuration
# ---------------------------------------------------------------------
echo "[*] Task 19: Creating 'engineers' group..."
groupadd -f engineers

# ---------------------------------------------------------------------
# Task 20 – Advanced Group Permissions (ACL)
# ---------------------------------------------------------------------
echo "[*] Task 20: Creating 'staff' group and directory..."
groupadd -f staff
mkdir -p /srv/shared

# ---------------------------------------------------------------------
# Finalization
# ---------------------------------------------------------------------
echo "[*] Reloading system services..."
systemctl daemon-reload || true
exportfs -ra || true
echo ""
echo "==============================================================="
echo "✅ LFCS Practice Exam 5 environment setup complete!"
echo "==============================================================="
echo "You can now proceed with the tasks in the LFCS Practice Exam 5."
echo "==============================================================="

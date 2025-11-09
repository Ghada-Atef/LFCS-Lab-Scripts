#!/bin/bash
# =====================================================================
# LFCS Practice Exam 2 – Environment Setup (Cross-Distro Safe Edition)
# (FINAL v1.8 - Changes KVM domain type to QEMU for compatibility)
# =====================================================================

set -e
echo "==============================================================="
echo " ⚙️   Starting environment setup for LFCS Practice Exam 2..."
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
    SEMANAGE_PKG="policycoreutils-python-utils"
    NETCAT_PKG="nmap-ncat"
    NC_QUIT_FLAG=""
    LIBVIRT_DAEMON="libvirt-daemon"
    LIBVIRT_DRIVER_QEMU="libvirt-daemon-driver-qemu"
    EMULATOR_PKG="qemu-kvm"
elif [ -f /etc/debian_version ]; then
    DISTRO="debian"
    PKG_INSTALL="sudo apt install -y"
    FIREWALL_CMD="ufw"
    NOGROUP="nobody:nogroup"
    NFS_SERVICE="nfs-kernel-server"
    SEMANAGE_PKG="semanage-utils"
    NETCAT_PKG="netcat-openbsd"
    NC_QUIT_FLAG="-q 1"
    LIBVIRT_DAEMON="libvirt-daemon-system"
    LIBVIRT_DRIVER_QEMU="libvirt-daemon-driver-qemu"
    EMULATOR_PKG="qemu-kvm"
else
    echo " ⚠️  Unsupported distribution. Use RHEL, AlmaLinux, Rocky, or Ubuntu."
    exit 1
fi
echo "[*] Detected Linux Distribution: $DISTRO"

# ---------------------------------------------------------------------
# Safety & Pre-checks
# ---------------------------------------------------------------------
if ! command -v systemctl >/dev/null; then
    echo " ❌   systemd not available. Exiting."
    exit 1
fi

# ---------------------------------------------------------------------
# Install Essential Packages
# ---------------------------------------------------------------------
echo "[*] Installing required tools..."
$PKG_INSTALL nfs-utils git libvirt-client $LIBVIRT_DAEMON $LIBVIRT_DRIVER_QEMU $EMULATOR_PKG qemu-img mdadm nginx $NETCAT_PKG $SEMANAGE_PKG podman || true

# ---------------------------------------------------------------------
# Task 1 – Libvirt VM Definition
# ---------------------------------------------------------------------
echo "[*] Task 1: Enabling libvirtd service and defining VM (dev-vm)..."
sudo systemctl enable --now libvirtd || echo "Warning: libvirtd service failed to start. Check virtualization support."
echo "[*] Waiting 2 seconds for libvirt daemon to initialize..."
sleep 2 

mkdir -p /var/lib/libvirt/images
if ! virsh list --all | grep -q dev-vm; then
    cat > /tmp/dev-vm.xml <<'EOF'
<domain type="qemu">
<name>dev-vm</name>
<memory unit="KiB">524288</memory>
<vcpu placement="static">1</vcpu>
<os><type arch="x86_64" machine="pc">hvm</type></os>
<devices>
<disk type="file" device="disk">
<driver name="qemu" type="qcow2"/>
<source file="/var/lib/libvirt/images/dev-vm.qcow2"/>
<target dev="vda" bus="virtio"/>
</disk>
<interface type="network">
<source network="default"/>
<model type="virtio"/>
</interface>
<console type="pty"/>
</devices>
</domain>
EOF
    qemu-img create -f qcow2 /var/lib/libvirt/images/dev-vm.qcow2 1G || true
    virsh -c qemu:///system define /tmp/dev-vm.xml || true
    rm -f /tmp/dev-vm.xml
else
    echo " ⚠️  dev-vm already defined. Skipping."
fi

# ---------------------------------------------------------------------
# Task 2 – Process Management
# ---------------------------------------------------------------------
echo "[*] Task 2: Starting simulated 'data-crunch' process..."
(exec -a data-crunch sleep 3600 &)

# ---------------------------------------------------------------------
# Task 5 – SELinux Directory (or Permissions on Ubuntu)
# ---------------------------------------------------------------------
echo "[*] Task 5: Creating /srv/www directory (intentionally misconfigured)..."
mkdir -p /srv/www && touch /srv/www/index.html
# We leave the context as default_t, which is "broken" for the web server.
if [ "$DISTRO" = "debian" ]; then
    echo "[*] SELinux not applicable on Ubuntu – proceeding with permissions."
    chmod 755 /srv/www
fi

# ---------------------------------------------------------------------
# Task 8 – Reverse Proxy Backend
# ---------------------------------------------------------------------
echo "[*] Task 8: Starting backend listener on port 8080..."
( while true; do echo -e "HTTP/1.1 200 OK\r\n\r\nBackend OK" | nc -l -p 8080 $NC_QUIT_FLAG; done ) &

# ---------------------------------------------------------------------
# Task 10 – Network Troubleshooting Target
# ---------------------------------------------------------------------
if ip link show eth1 &>/dev/null; then
    echo "[*] Task 10: Assigning target IP 172.16.10.20 to eth1..."
    ip addr add 172.16.10.20/24 dev eth1 || true
else
    echo " ⚠️  eth1 not found. Skipping IP configuration for Task 10."
fi

# ---------------------------------------------------------------------
# Tasks 11–12 – LVM Management
# ---------------------------------------------------------------------
if [ -b /dev/sdb ] && ! lsblk -no MOUNTPOINTS "/dev/sdb" | grep -q "/"; then
    echo "[*] Task 11–12: Preparing LVM volumes on /dev/sdb..."
    if ! vgs vg-data &>/dev/null; then
        pvcreate /dev/sdb || true
        vgcreate vg-data /dev/sdb || true
    fi
    lvcreate -n lv-logs -L 1G vg-data || true
    lvcreate -n lv-apps -L 2G vg-data || true
    mkfs.xfs /dev/vg-data/lv-apps || true
else
    echo " ⚠️  /dev/sdb not found or is in use – skipping LVM setup."
fi

# ---------------------------------------------------------------------
# Task 13 – NFS Configuration
# ---------------------------------------------------------------------
echo "[*] Task 13: Configuring NFS export and IP 10.20.30.40..."
mkdir -p /export/users
echo "Autofs test file" > /export/users/test.txt
chown $NOGROUP /export/users
echo "/export/users *(ro,sync,no_subtree_check)" > /etc/exports
# Add the IP address that the question requires
if ip link show eth1 &>/dev/null; then
    ip addr add 10.20.30.40/24 dev eth1 || true
else
    echo " ⚠️  eth1 not found. Skipping IP for Task 13."
fi
sudo systemctl enable --now $NFS_SERVICE || true
exportfs -ra || true

# ---------------------------------------------------------------------
# Task 15 – Custom Systemd Service
# ---------------------------------------------------------------------
echo "[*] Task 15: Creating custom cleanup script (but not the service)..."
cat > /usr/local/bin/cleanup.sh <<'EOF'
#!/bin/bash
echo "Cleanup service ran at $(date)" >> /tmp/cleanup_log.txt
EOF
chmod +x /usr/local/bin/cleanup.sh
# We do NOT create the .service file. That is the student's task.

# ---------------------------------------------------------------------
# Task 16 – Git Repository
# ---------------------------------------------------------------------
echo "[*] Task 16: Setting up Git repository..."
if [ ! -d "/opt/lfcs" ]; then
    git clone https://github.com/Ghada-Atef/LFCS-Lab-Scripts.git /opt/lfcs || true
fi
mkdir -p /opt/lfcs/config
echo "# Accidental change by admin" >> /opt/lfcs/config/settings.conf || true

# ---------------------------------------------------------------------
# Task 17 – Disk Space Troubleshooting
# ---------------------------------------------------------------------
if ! id "jdoe" &>/dev/null; then
    useradd -m jdoe
fi
echo "[*] Task 17: Creating large files in /home/jdoe..."
for size in 20M 50M 10M 80M 35M 5M; do
    fallocate -l $size /home/jdoe/file_${size}.dat || true
done
chown -R jdoe:jdoe /home/jdoe || true

# ---------------------------------------------------------------------
# Task 20 – Resource Limits
# ---------------------------------------------------------------------
if ! getent group developers >/dev/null; then
    groupadd developers
fi

# ---------------------------------------------------------------------
# Finalization
# ---------------------------------------------------------------------
echo "[*] Reloading system services..."
systemctl daemon-reload || true
exportfs -ra || true
echo ""
echo "==============================================================="
echo " ✅   LFCS Practice Exam 2 environment setup complete!"
echo "==============================================================="

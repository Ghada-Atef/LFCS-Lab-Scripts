#!/bin/bash
# =====================================================================
# LFCS Practice Exam 4 – Environment Setup (Cross-Distro Safe Edition)
# =====================================================================

set -e
echo "==============================================================="
echo "🔧 Starting environment setup for LFCS Practice Exam 4..."
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
elif [ -f /etc/debian_version ]; then
    DISTRO="debian"
    PKG_INSTALL="sudo apt install -y"
    FIREWALL_CMD="ufw"
    NOGROUP="nobody:nogroup"
    NFS_SERVICE="nfs-kernel-server"
else
    echo "⚠️ Unsupported distribution. Use RHEL, AlmaLinux, Rocky, or Ubuntu."
    exit 1
fi
echo "[*] Detected Linux Distribution: $DISTRO"

# ---------------------------------------------------------------------
# Pre-Checks
# ---------------------------------------------------------------------
if ! command -v systemctl >/dev/null; then
    echo "❌ systemd not detected. Aborting."
    exit 1
fi

# ---------------------------------------------------------------------
# Install packages
# ---------------------------------------------------------------------
echo "[*] Installing required packages..."
$PKG_INSTALL nginx git samba mdadm || true

# ---------------------------------------------------------------------
# Task 1 – Container Persistent Storage (host directory)
# ---------------------------------------------------------------------
echo "[*] Task 1: Creating host directory for container persistent volume..."
mkdir -p /data/db
chown root:root /data/db || true
chmod 755 /data/db || true

# ---------------------------------------------------------------------
# Task 5 – Faulty service & mis-permission config
# ---------------------------------------------------------------------
echo "[*] Task 5: Creating faulty inventory.service scenario..."
if ! id inv_user &>/dev/null; then
    useradd inv_user || true
fi
mkdir -p /etc/inventory-app
echo "[database]" > /etc/inventory-app/config.ini
# Intentionally set restrictive permissions to simulate misconfiguration
chown root:root /etc/inventory-app/config.ini || true
chmod 600 /etc/inventory-app/config.ini || true

cat > /etc/systemd/system/inventory.service <<'EOF'
[Unit]
Description=Inventory Application Service
[Service]
User=inv_user
ExecStart=/bin/bash -c "cat /etc/inventory-app/config.ini && sleep 60"
[Install]
WantedBy=multi-user.target
EOF

# ---------------------------------------------------------------------
# Task 7 – Secure SSH user/group
# ---------------------------------------------------------------------
echo "[*] Task 7: Creating ssh_users group and jdoe user..."
if ! getent group ssh_users >/dev/null; then
    groupadd ssh_users || true
fi
if ! id jdoe &>/dev/null; then
    if [ "$DISTRO" = "rhel" ]; then
        useradd -m jdoe || true
        echo "password" | passwd --stdin jdoe >/dev/null 2>&1 || true
    else
        useradd -m jdoe || true
        echo "jdoe:password" | chpasswd || true
    fi
fi
usermod -aG ssh_users jdoe || true

# ---------------------------------------------------------------------
# Task 11 – LVM Volume for Shrink Task
# ---------------------------------------------------------------------
echo "[*] Task 11: Creating lv-staging if /dev/sdb exists..."
if [ -b /dev/sdb ]; then
    if ! vgs vg-data &>/dev/null; then
        pvcreate /dev/sdb || true
        vgcreate vg-data /dev/sdb || true
    fi
    if ! lvs vg-data/lv-staging &>/dev/null; then
        lvcreate -n lv-staging -L 10G vg-data || true
        mkfs.ext4 /dev/vg-data/lv-staging || true
        mkdir -p /mnt/staging
        mount /dev/vg-data/lv-staging /mnt/staging || true
    else
        echo "⚠️ lv-staging already exists; skipping lvcreate."
    fi
else
    echo "⚠️ /dev/sdb not present — skipping LVM creation."
fi

# ---------------------------------------------------------------------
# Task 12 – Samba/CIFS local server
# ---------------------------------------------------------------------
echo "[*] Task 12: Installing and configuring Samba..."
if [ "$DISTRO" = "rhel" ]; then
    $PKG_INSTALL samba || true
else
    $PKG_INSTALL samba || true
fi

mkdir -p /srv/sharedocs
echo "This is a test file on the CIFS share." > /srv/sharedocs/test.txt
if ! id winuser &>/dev/null; then
    useradd winuser || true
fi
# set Samba password non-interactively where possible
if command -v smbpasswd >/dev/null; then
    (echo "P@ssw0rd1"; echo "P@ssw0rd1") | smbpasswd -s -a winuser || true
fi

cat > /etc/samba/smb.conf <<'EOF'
[global]
   workgroup = WORKGROUP
   server string = Samba Server
   security = user

[sharedocs]
   path = /srv/sharedocs
   valid users = winuser
   read only = no
EOF

# add a secondary IP for Samba tests if eth1 exists
if ip link show eth1 &>/dev/null; then
    ip addr add 10.50.60.70/24 dev eth1 || true
fi

# Start samba service safely
if systemctl list-unit-files | grep -q samba; then
    systemctl enable --now smb || systemctl enable --now samba || true
fi

# Add firewall rule
if [ "$DISTRO" = "rhel" ]; then
    $FIREWALL_CMD --permanent --add-service=samba || true
    $FIREWALL_CMD --reload || true
else
  m   sudo ufw allow samba || true
fi

# ---------------------------------------------------------------------
# Task 13 – Read-only mount to simulate error
# ---------------------------------------------------------------------
echo "[*] Task 13: Creating and mounting read-only filesystem..."
mkdir -p /opt/data
if [ -b /dev/sdb1 ]; then
Star    mount -o ro /dev/sdb1 /opt/data || true
else
    echo "⚠️ /dev/sdb1 not found — skipping read-only mount."
fi

# ---------------------------------------------------------------------
# Task 15 – Archiving directories
# ---------------------------------------------------------------------
echo "[*] Task 15: Creating web dirs for archiving task..."
mkdir -p /var/www/html/cache
touch /var/www/html/index.html || true
touch /var/www/html/cache/tmp.dat || true

# ---------------------------------------------------------------------
# Task 16 – Git history task
# ---------------------------------------------------------------------
echo "[*] Task 16: Preparing git repo with history..."
if [ ! -d "/opt/app-config" ]; then
    git clone https://github.com/linux-foundation/lfcs-course.git /opt/app-config || true
fi
cd /opt/app-config || true
echo -e "production:\n  adapter: postgres" > database.yml
git add database.yml && git commit -m "Initial DB config" || true
echo -e "production:\n  adapter: mysql" > database.yml
git commit -am "Switch to MySQL" || true
cd / || true

# ---------------------------------------------------------------------
# Task 18 – Systemd timer script
# ---------------------------------------------------------------------
echo "[*] Task 18: Creating log-rotate script for systemd timer..."
cat > /usr/local/bin/log-rotate.sh <<'EOF'
#!/bin/bash
echo "Systemd timer ran log rotation at $(date)" >> /var/log/log_rotation.log
EOF
chmod +x /usr/local/bin/log-rotate.sh || true

# ---------------------------------------------------------------------
# Task 20 – Group permissions and setgid dir
# ---------------------------------------------------------------------
echo "[*] Task 20: Creating developers group & projects dir..."
if ! getent group developers >/dev/null; then
I    groupadd developers || true
fi
# Create the directory, but leave ownership and permissions for the task
mkdir -p /srv/projects

# ---------------------------------------------------------------------
# Finalization
# ---------------------------------------------------------------------
echo "[*] Reloading systemd and finalizing..."
systemctl daemon-reload || true
if command -v exportfs >/dev/null; then
    exportfs -ra || true
fi

echo ""
echo "==============================================================="
echo "✅ LFCS Practice Exam 4 environment setup complete!"
echo "==============================================================="
echo "You can now proceed with the tasks in the LFCS Practice Exam 4."
echo "==============================================================="

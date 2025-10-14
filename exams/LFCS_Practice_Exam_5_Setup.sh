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
# System Pre-Checks
# ---------------------------------------------------------------------
if ! command -v systemctl >/dev/null; then
    echo "❌ systemd is required but not found. Aborting setup."
    exit 1
fi

# ---------------------------------------------------------------------
# Install Required Packages
# ---------------------------------------------------------------------
echo "[*] Installing required tools..."
$PKG_INSTALL nginx git podman net-tools nfs-utils mdadm || true

# ---------------------------------------------------------------------
# Task 1 – Custom Network Configuration
# ---------------------------------------------------------------------
echo "[*] Task 1: Configuring static IP for eth1 (172.20.10.5/24)..."
if ip link show eth1 &>/dev/null; then
    ip addr add 172.20.10.5/24 dev eth1 || true
else
    echo "⚠️ eth1 not available — skipping IP configuration."
fi

# ---------------------------------------------------------------------
# Task 2 – DNS Troubleshooting Target
# ---------------------------------------------------------------------
echo "[*] Task 2: Adding incorrect DNS entries..."
grep -q "dbserver" /etc/hosts || echo "203.0.113.77 dbserver" >> /etc/hosts
grep -q "invalid.lfcs.local" /etc/hosts || echo "198.51.100.99 invalid.lfcs.local" >> /etc/hosts

# ---------------------------------------------------------------------
# Task 3 – Web Server Fault Simulation
# ---------------------------------------------------------------------
echo "[*] Task 3: Configuring faulty Nginx site..."
mkdir -p /var/www/html
echo "<h1>LFCS Exam 5 Test Page</h1>" > /var/www/html/index.html
cat > /etc/nginx/conf.d/faulty-site.conf <<'EOF'
server {
    listen 8080;
    server_name localhost;
    root /var/www/html;
    # Intentional typo in directive below
    indes index.html;
}
EOF
systemctl enable --now nginx || true

# ---------------------------------------------------------------------
# Task 5 – Podman Container
# ---------------------------------------------------------------------
echo "[*] Task 5: Creating test Podman container..."
if command -v podman >/dev/null; then
    podman rm -f webtest >/dev/null 2>&1 || true
    podman run -d --name webtest -p 8081:80 docker.io/library/nginx:latest || true
else
    echo "⚠️ Podman not installed; skipping container setup."
fi

# ---------------------------------------------------------------------
# Task 7 – File System Quota Setup
# ---------------------------------------------------------------------
echo "[*] Task 7: Configuring quota-enabled filesystem..."
if [ -b /dev/sdb ]; then
    echo "[*] Setting up /dev/sdb for quota..."
    mkfs.xfs -f /dev/sdb || true
    mkdir -p /quota
    mount -o uquota,gquota /dev/sdb /quota || true
    xfs_quota -x -c 'limit bsoft=50M bhard=100M root' /quota || true
else
    echo "⚠️ /dev/sdb not found — skipping quota setup."
fi

# ---------------------------------------------------------------------
# Task 9 – NFS Export
# ---------------------------------------------------------------------
echo "[*] Task 9: Setting up NFS export..."
mkdir -p /srv/projects
echo "Shared project folder" > /srv/projects/README.txt
chown $NOGROUP /srv/projects || true
echo "/srv/projects *(rw,sync,no_subtree_check)" > /etc/exports
systemctl enable --now $NFS_SERVICE || true
exportfs -ra || true

# ---------------------------------------------------------------------
# Task 10 – Log Rotation Configuration
# ---------------------------------------------------------------------
echo "[*] Task 10: Creating custom logrotate rule..."
cat > /etc/logrotate.d/app-custom <<'EOF'
/var/log/app-custom.log {
    daily
    rotate 3
    compress
    missingok
    notifempty
    create 0640 root root
}
EOF
touch /var/log/app-custom.log || true

# ---------------------------------------------------------------------
# Task 12 – SELinux File Label Issue (RHEL only)
# ---------------------------------------------------------------------
if [ "$DISTRO" = "rhel" ]; then
    echo "[*] Task 12: Creating mislabeled SELinux directory..."
    mkdir -p /srv/webdata
    echo "SELinux test" > /srv/webdata/test.txt
    chown apache:apache /srv/webdata
    # Apply wrong context intentionally
    chcon -t var_t /srv/webdata -R
fi

# ---------------------------------------------------------------------
# Task 14 – Broken Systemd Unit
# ---------------------------------------------------------------------
echo "[*] Task 14: Creating broken systemd unit..."
cat > /etc/systemd/system/faulty-daemon.service <<'EOF'
[Unit]
Description=Faulty Daemon
[Service]
ExecStart=/usr/local/bin/faulty-daemon.sh
[Install]
WantedBy=multi-user.target
EOF
# Missing script (intentional)
systemctl daemon-reload || true

# ---------------------------------------------------------------------
# Task 15 – Disk Full Simulation
# ---------------------------------------------------------------------
echo "[*] Task 15: Filling /tmp with dummy data (50MB)..."
fallocate -l 50M /tmp/fill_test.dat || true

# ---------------------------------------------------------------------
# Task 17 – User and Group Setup
# ---------------------------------------------------------------------
echo "[*] Task 17: Creating developer users..."
for user in dev1 dev2 dev3; do
    if ! id "$user" &>/dev/null; then
        useradd -m "$user" || true
        echo "$user:password" | chpasswd || true
    fi
done
groupadd -f devteam
for user in dev1 dev2 dev3; do
    usermod -aG devteam "$user" || true
done

# ---------------------------------------------------------------------
# Task 18 – Scheduled Job
# ---------------------------------------------------------------------
echo "[*] Task 18: Creating scheduled job..."
cat > /usr/local/bin/backup_daily.sh <<'EOF'
#!/bin/bash
echo "Backup job ran at $(date)" >> /var/log/backup_daily.log
EOF
chmod +x /usr/local/bin/backup_daily.sh
( crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/backup_daily.sh" ) | crontab -

# ---------------------------------------------------------------------
# Task 19 – System Performance Simulation
# ---------------------------------------------------------------------
echo "[*] Task 19: Launching CPU-intensive process..."
yes > /dev/null &

# ---------------------------------------------------------------------
# Task 20 – Git Task
# ---------------------------------------------------------------------
echo "[*] Task 20: Creating Git repo for change tracking..."
mkdir -p /opt/webapp
cd /opt/webapp
git init
echo "Version 1" > version.txt
git add .
git commit -m "Initial commit"
echo "Version 2" > version.txt
git commit -am "Update version"
cd /

# ---------------------------------------------------------------------
# Finalization
# ---------------------------------------------------------------------
echo "[*] Reloading services..."
systemctl daemon-reload || true
exportfs -ra || true
echo ""
echo "==============================================================="
echo "✅ LFCS Practice Exam 5 environment setup complete!"
echo "==============================================================="
echo "You can now proceed with the tasks in the LFCS Practice Exam 5."
echo "==============================================================="
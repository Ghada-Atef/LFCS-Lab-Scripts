#!/bin/bash
# =====================================================================
# LFCS Practice Exam 3 – Environment Setup (Cross-Distro Safe Edition)
# =====================================================================

set -e
echo "==============================================================="
echo "🚀  Starting environment setup for LFCS Practice Exam 3..."
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
    echo "⚠️  Unsupported distribution. Use RHEL, AlmaLinux, Rocky, or Ubuntu."
    exit 1
fi
echo "[*] Detected Linux Distribution: $DISTRO"

# ---------------------------------------------------------------------
# Pre-Checks
# ---------------------------------------------------------------------
if ! command -v systemctl >/dev/null; then
    echo "❌  systemd not detected. Aborting setup."
    exit 1
fi

# ---------------------------------------------------------------------
# Package Installation
# ---------------------------------------------------------------------
echo "[*] Installing required packages..."
$PKG_INSTALL podman git nginx netcat-openbsd nfs-utils mdadm || true

# ---------------------------------------------------------------------
# Task 2 – Failed Container
# ---------------------------------------------------------------------
echo "[*] Task 2: Creating intentionally failed container (db-app)..."
if command -v podman >/dev/null; then
    podman rm -f db-app >/dev/null 2>&1 || true
    podman run --name db-app alpine:latest sh -c "echo '[ERROR] DB connection failed'; exit 126" || true
else
    echo "⚠️  Podman not available; skipping container task."
fi

# ---------------------------------------------------------------------
# Task 3 – System Health Check Script
# ---------------------------------------------------------------------
echo "[*] Task 3: Creating system health-check script..."
mkdir -p /opt/scripts
cat > /opt/scripts/system-health-check.sh <<'EOF'
#!/bin/bash
echo "System health check ran at $(date)" >> /var/log/health_check.log
EOF
chmod +x /opt/scripts/system-health-check.sh

# ---------------------------------------------------------------------
# Task 4 – Memory-Intensive Process
# ---------------------------------------------------------------------
echo "[*] Task 4: Creating tomcat user and memory-hog process..."
id tomcat &>/dev/null || useradd tomcat
runuser -l tomcat -c "exec -a java-app python3 -c 'import time; a=\"\"*(200*1024*1024); time.sleep(3600)'" &>/dev/null &

# ---------------------------------------------------------------------
# Task 5 – Backup Archive and Recovery
# ---------------------------------------------------------------------
echo "[*] Task 5: Creating backup archive and deleting original file..."
mkdir -p /backups /etc/sysconfig
echo "CRITICAL_SETTING=true" > /etc/sysconfig/my-app.conf
tar -czf /backups/etc-backup.tar.gz -C / etc/sysconfig/my-app.conf
rm -f /etc/sysconfig/my-app.conf

# ---------------------------------------------------------------------
# Task 7 – Port Redirection Simulation
# ---------------------------------------------------------------------
echo "[*] Task 7: Starting service listener on port 8080..."
( while true; do echo -e "HTTP/1.1 200 OK\r\n\r\nService on 8080 OK" | nc -l -p 8080 -q 1; done ) &

# ---------------------------------------------------------------------
# Task 8 – SSH Client Configuration
# ---------------------------------------------------------------------
echo "[*] Task 8: Creating SSH key for default user..."
DEFAULT_USER=$(logname 2>/dev/null || echo "rocky")
runuser -l "$DEFAULT_USER" -c "mkdir -p ~/.ssh; ssh-keygen -t rsa -b 2048 -N '' -f ~/.ssh/bastion_key" || true

# ---------------------------------------------------------------------
# Task 9 – Faulty Hostname Entry
# ---------------------------------------------------------------------
echo "[*] Task 9: Adding incorrect /etc/hosts entry..."
grep -q "webapp" /etc/hosts || echo "192.168.254.254 webapp" >> /etc/hosts

# ---------------------------------------------------------------------
# Task 10 – Reverse Proxy Backends
# ---------------------------------------------------------------------
echo "[*] Task 10: Creating backend services on ports 80..."
for i in 10 11; do
    ip addr add 192.168.1.$i/24 dev eth1 2>/dev/null || true
done
( while true; do echo -e "HTTP/1.1 200 OK\r\n\r\nResponse from Backend-1" | nc -l -p 80 -s 192.168.1.10 -q 1; done ) &
( while true; do echo -e "HTTP/1.1 200 OK\r\n\r\nResponse from Backend-2" | nc -l -p 80 -s 192.168.1.11 -q 1; done ) &

# ---------------------------------------------------------------------
# Tasks 11-14 – Storage Configuration
# ---------------------------------------------------------------------
echo "[*] Tasks 11-14: Preparing block devices..."
for dev in /dev/sdb /dev/sdc /dev/sdd /dev/sde; do
    [ -b "$dev" ] || echo "⚠️  Missing $dev, skipping."
done
if [ -b /dev/sdb ]; then
    (echo n; echo p; echo 1; echo ; echo ; echo w) | fdisk /dev/sdb || true
    mkfs.ext4 /dev/sdb1 || true
fi
if [ -b /dev/sdc ]; then
    (echo n; echo p; echo 1; echo ; echo ; echo w) | fdisk /dev/sdc || true
    mkfs.xfs /dev/sdc1 || true
    mkdir -p /mnt/legacy && mount /dev/sdc1 /mnt/legacy || true
fi
if [ -b /dev/sdd ]; then
    (echo n; echo p; echo 1; echo ; echo ; echo w) | fdisk /dev/sdd || true
fi
if [ -b /dev/sde ]; then
    if ! vgs vg-data &>/dev/null; then
        pvcreate /dev/sde || true
        vgcreate vg-data /dev/sde || true
    fi
fi

# ---------------------------------------------------------------------
# Task 15 – SSL Key Creation
# ---------------------------------------------------------------------
echo "[*] Task 15: Generating private key..."
mkdir -p /opt/keys
openssl genpkey -algorithm RSA -out /opt/keys/server.key

# ---------------------------------------------------------------------
# Task 16 – Git Initialization
# ---------------------------------------------------------------------
echo "[*] Task 16: Creating Git repo /opt/app-config..."
mkdir -p /opt/app-config
cd /opt/app-config
git init
touch initial.conf
git add .
git commit -m "Initial commit"
cd /

# ---------------------------------------------------------------------
# Task 17 – Slow Systemd Service
# ---------------------------------------------------------------------
echo "[*] Task 17: Creating slow systemd service..."
cat > /etc/systemd/system/data-importer.service <<'EOF'
[Unit]
Description=Slow data importer service
[Service]
ExecStart=/bin/sleep 4
[Install]
WantedBy=multi-user.target
EOF

# ---------------------------------------------------------------------
# Task 18 – Large Log Files
# ---------------------------------------------------------------------
echo "[*] Task 18: Creating large log files..."
fallocate -l 110M /var/log/audit-archive.log || true
fallocate -l 150M /var/log/app-trace.log || true

# ---------------------------------------------------------------------
# Tasks 19-20 – User and ACL Setup
# ---------------------------------------------------------------------
echo "[*] Tasks 19-20: Creating user jdoe and directories..."
id jdoe &>/dev/null || useradd -m jdoe
mkdir -p /home/jdoe/bin /srv/docs
chown -R jdoe:jdoe /home/jdoe

# ---------------------------------------------------------------------
# Finalization
# ---------------------------------------------------------------------
echo "[*] Reloading services..."
systemctl daemon-reload || true
exportfs -ra || true
echo ""
echo "==============================================================="
echo "✅ LFCS Practice Exam 3 environment setup complete!"
echo "==============================================================="
echo "You can now proceed with the tasks in the LFCS Practice Exam 3."
echo "==============================================================="
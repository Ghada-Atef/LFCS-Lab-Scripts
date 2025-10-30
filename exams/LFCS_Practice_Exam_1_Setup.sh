#!/bin/bash
# =====================================================================
# LFCS Practice Exam 1 – Environment Setup (Cross-Distro Safe Edition)
# Version: 1.2 (October 2025)
# Updates:
#   - Fixed Task 2 (log-archive.service) with Type=oneshot & RemainAfterExit=yes
#   - Added Task 4 jq installation check for RHEL 10 and Debian-based systems
# =====================================================================

set -e  # Exit immediately on critical error
echo "==============================================================="
echo "🔧 Starting environment setup for LFCS Practice Exam 1..."
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
echo "[*] Detected distribution: $DISTRO"

# ---------------------------------------------------------------------
# Safety Checks
# ---------------------------------------------------------------------
if ! command -v systemctl >/dev/null; then
    echo "❌  systemd not found. This lab requires systemd-based systems."
    exit 1
fi

# ---------------------------------------------------------------------
# Essential Packages
# ---------------------------------------------------------------------
echo "[*] Installing required packages..."
$PKG_INSTALL nfs-utils cifs-utils mdadm git nano nginx || true

# ---------------------------------------------------------------------
# Task 2 – Faulty Systemd Service
# ---------------------------------------------------------------------
echo "[*] Setting up for Task 2 – Faulty log-archive service..."
echo "[*] NOTE: The ExecStart path intentionally points to /usr/bin/log_archive.sh"
echo "[*]       while the script is installed to /usr/local/bin. This creates"
echo "[*]       a controlled service start failure for the troubleshooting task."
mkdir -p /usr/local/bin
cat > /usr/local/bin/log_archive.sh <<'EOF'
#!/bin/bash
echo "Log archiving task ran at $(date)" >> /var/log/archive.log
EOF
chmod +x /usr/local/bin/log_archive.sh

cat > /etc/systemd/system/log-archive.service <<'EOF'
[Unit]
Description=Log Archiving Service

# NOTE: ExecStart intentionally points to /usr/bin/log_archive.sh to create
# a troubleshooting scenario. Students should verify path and permissions.
[Service]
Type=oneshot
ExecStart=/usr/bin/log_archive.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# ---------------------------------------------------------------------
# Container Engine – Required for Task 3 (Podman)
# ---------------------------------------------------------------------
echo "[*] Checking container engine (podman)..."
if ! command -v podman >/dev/null 2>&1; then
    echo "[*] podman not found — installing..."
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y podman
    elif command -v apt >/dev/null 2>&1; then
        sudo apt install -y podman
    else
        echo "Unable to detect package manager. Please install podman manually."
    fi
else
    echo "[*] podman already installed."
fi

# ---------------------------------------------------------------------
# Task 4 – jq Installation (Ensure jq is missing for the exercise)
# ---------------------------------------------------------------------
echo "[*] Preparing Task 4 – jq package management test..."
if command -v jq >/dev/null 2>&1; then
    echo "[*] jq already installed — removing to simulate missing package scenario..."
    if command -v dnf >/dev/null; then
        sudo dnf remove -y jq
    elif command -v apt >/dev/null; then
        sudo apt remove -y jq
    fi
else
    echo "[*] jq not detected — ready for installation test."
fi

# ---------------------------------------------------------------------
# Task 5 – Cron Job Script
# ---------------------------------------------------------------------
echo "[*] Setting up for Task 5 – Cron job script..."
cat > /usr/local/bin/backup.sh <<'EOF'
#!/bin/bash
echo "Backup job ran at $(date)" >> /var/log/backup.log
EOF
chmod +x /usr/local/bin/backup.sh

# ---------------------------------------------------------------------
# Task 13 – NFS Server
# ---------------------------------------------------------------------
echo "[*] Setting up for Task 13 – NFS Server..."
mkdir -p /srv/share
echo "NFS share is ready." > /srv/share/README.txt
chown $NOGROUP /srv/share
echo "/srv/share *(ro,sync,no_subtree_check)" > /etc/exports

# Enable and configure firewall safely
if [ "$DISTRO" = "rhel" ]; then
    $FIREWALL_CMD --permanent --add-service=nfs || true
    $FIREWALL_CMD --reload || true
elif [ "$DISTRO" = "debian" ]; then
    sudo ufw allow nfs || true
fi

sudo systemctl enable --now $NFS_SERVICE || true

# ---------------------------------------------------------------------
# Task 15 – Large Old File
# ---------------------------------------------------------------------
echo "[*] Setting up for Task 15 – Large old log file..."
mkdir -p /var/log/archive
fallocate -l 60M /var/log/archive/old-archive.log || true
touch -d "60 days ago" /var/log/archive/old-archive.log

# ---------------------------------------------------------------------
# Task 18 – SSL Directory Setup
# ---------------------------------------------------------------------
echo "[*] Ensuring /etc/ssl/private directory exists..."
sudo mkdir -p /etc/ssl/private
sudo chmod 700 /etc/ssl/private

# ---------------------------------------------------------------------
# Task 20 – ACL Exercise
# ---------------------------------------------------------------------
echo "[*] Setting up for Task 20 – ACL exercise..."
if ! id "temp_contractor" &>/dev/null; then
    useradd temp_contractor
fi
WEB_ROOT="/usr/share/nginx/html"
[ -d /var/www/html ] && WEB_ROOT="/var/www/html"
mkdir -p "$WEB_ROOT"
echo "Default web page for ACL task" > "$WEB_ROOT/index.html"

# ---------------------------------------------------------------------
# Finalization
# ---------------------------------------------------------------------
echo "[*] Reloading system services..."
systemctl daemon-reload || true
exportfs -ra || true
echo "✅  Lab setup for Practice Exam 1 is complete!"
echo "==============================================================="
echo "You can now proceed with the tasks in the LFCS Practice Exam 1."
echo "==============================================================="

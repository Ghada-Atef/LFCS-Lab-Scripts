#!/usr/bin/env bash
# =====================================================================
# LFCS Practice Exam 2 – Environment Setup (Cross-Distro Safe Edition)
# Version: 1.2 (2025-11-01)
# - ADD: Interactive safety prompt; script will not run without user confirmation.
# - Installs all dependencies for RHEL/Debian minimal installs
# - FIX (Libvirt): Change type='kvm' to type='qemu' to bypass nested virtualization error
# - FIX (LVM): Add "scorched earth" cleanup to handle stale LVM caches/devices
# - FIX (LVM): Increase loop file to 3.1G to fix "insufficient space" error
# =====================================================================

set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
LOG_TS() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

# ----------------------------
# Cross-distribution detection
# ----------------------------
DISTRO=""
PKG_INSTALL=""
FIREWALL_CMD=""
NOGROUP=""
NFS_SERVICE=""

if [ -f /etc/redhat-release ]; then
    DISTRO="rhel"
    PKG_INSTALL="sudo dnf install -y"
    FIREWALL_CMD="firewall-cmd"
    NOGROUP="nobody:nobody"
    NFS_SERVICE="nfs-server"
elif [ -f /etc/debian_version ]; then
    DISTRO="debian"
    PKG_INSTALL="sudo apt-get install -y"
    FIREWALL_CMD="ufw"
    NOGROUP="nobody:nogroup"
    NFS_SERVICE="nfs-kernel-server"
else
    LOG_TS "⚠️ Unsupported distribution. Please use RHEL-family or Debian-family."
    exit 1
fi

# ----------------------------
# Helpers
# ----------------------------
safe_install() {
    for pkg in "$@"; do
        LOG_TS "Attempt install: $pkg"
        if $PKG_INSTALL "$pkg" >/dev/null 2>&1; then
            LOG_TS "  OK: $pkg"
        else
            LOG_TS "  WARN: $pkg may be unavailable or require repos/subscription."
        fi
    done
}
command_exists() { command -v "$1" >/dev/null 2>&1; }

# ----------------------------
# Initial installs & prep
# ----------------------------
initial_setup() {
    LOG_TS "Detected distribution: $DISTRO"
    LOG_TS "[*] Installing required packages (best-effort)..."
    if [ "$DISTRO" = "rhel" ]; then
        safe_install git coreutils python3 acl sysstat nginx nfs-utils libvirt-client qemu-img virt-install policycoreutils-python-utils nmap-ncat lvm2 shadow-utils util-linux libvirt-daemon-driver-storage-core
    else
        safe_install git coreutils python3 acl sysstat nginx nfs-common qemu-utils libvirt-clients virtinst jq lvm2
    fi

    LOG_TS "[*] Ensure /etc/ssl/private exists and is secure"
    sudo mkdir -p /etc/ssl/private
    sudo chmod 700 /etc/ssl/private || true
}

# ----------------------------
# Task 01: VM Management (robust handling)
# ----------------------------
Task_01() {
    LOG_TS "[Task 01] Virtual Machine Management (dev-vm)"
    if ! command_exists virsh; then
        LOG_TS "virsh not found — skipping VM creation."
        return 0
    fi

    # Ensure libvirt running
    if ! systemctl is-active --quiet libvirtd; then
        LOG_TS "libvirtd not active — attempting to enable & start"
        sudo systemctl enable --now libvirtd || LOG_TS "Warning: could not start libvirtd"
    fi
    sleep 1 # Give service time to start

    # Re-check
    if ! virsh -c qemu:///system list --all >/dev/null 2>&1; then
        LOG_TS "libvirt/qemu backend still unavailable — skipping VM creation."
        return 0
    fi

    # If dev-vm already present skip
    if virsh -c qemu:///system dominfo dev-vm >/dev/null 2>&1; then
        LOG_TS "dev-vm already defined — skipping."
        return 0
    fi

    # Prepare image
    sudo mkdir -p /var/lib/libvirt/images
    IMG="/var/lib/libvirt/images/dev-vm.qcow2"
    if [ ! -f "$IMG" ]; then
        LOG_TS "Creating qcow2 image: $IMG"
        sudo qemu-img create -f qcow2 "$IMG" 1G || LOG_TS "qemu-img reported non-zero status (continuing)."
    fi

    # Use 'virsh define' (type=qemu) to bypass nested virtualization error
    LOG_TS "Using 'virsh define' (type=qemu) to create VM..."
    cat > /tmp/dev-vm.xml <<'EOF'
<domain type="qemu">
  <name>dev-vm</name>
  <memory unit="KiB">524288</memory>
  <vcpu placement="static">1</vcpu>
  <os>
    <type arch="x86_64" machine="pc-q35-rhel9.4.0">hvm</type>
    <boot dev="hd"/>
  </os>
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
    <graphics type="vnc" port="-1" autoport="yes"/>
  </devices>
</domain>
EOF
    if sudo virsh define /tmp/dev-vm.xml; then
        LOG_TS "dev-vm successfully defined."
    else
        LOG_TS "virsh define failed. Please check libvirt logs."
    fi
    rm -f /tmp/dev-vm.xml
}

# ----------------------------
# Task 02: Simulate data-crunch
# ----------------------------
Task_02() {
    LOG_TS "[Task 02] Simulated 'data-crunch' process"
    if pgrep -f "exec -a data-crunch" >/dev/null 2>&1; then
        LOG_TS "data-crunch already running — skipping."
    else
        ( exec -a data-crunch sleep 3600 & )
        LOG_TS "Simulated data-crunch started."
    fi
}

# ----------------------------
# Task 03: Container placeholder
# ----------------------------
Task_03() { LOG_TS "[Task 03] Container placeholder (student task)"; }

# ----------------------------
# Task 04: Ensure jq
# ----------------------------
Task_04() {
    LOG_TS "[Task 04] Ensure jq present"
    if command_exists jq; then
        LOG_TS "jq present."
    else
        safe_install jq
    fi
}

# ----------------------------
# Task 05: /srv/www + SELinux
# ----------------------------
Task_05() {
    LOG_TS "[Task 05] Prepare /srv/www"
    sudo mkdir -p /srv/www
    sudo touch /srv/www/index.html
    if [ "$DISTRO" = "rhel" ] && command_exists semanage; then
        LOG_TS "Applying SELinux fcontext..."
        sudo semanage fcontext -a -t httpd_sys_content_t "/srv/www(/.*)?" 2>/dev/null || sudo semanage fcontext -m -t httpd_sys_content_t "/srv/www(/.*)?"
        sudo restorecon -Rv /srv/www || true
        LOG_TS "SELinux context applied."
    else
        sudo chmod 755 /srv/www
        LOG_TS "permissions set."
    fi
}

# ----------------------------
# Task 06: nmcli placeholder
# ----------------------------
Task_06() { LOG_TS "[Task 06] NMCLI static IP placeholder"; }

# ----------------------------
# Task 07: Chrony best-effort
# ----------------------------
Task_07() {
    LOG_TS "[Task 07] Chrony best-effort"
    if [ -f /etc/chrony.conf ]; then
        if ! grep -q 'pool pool.ntp.org' /etc/chrony.conf 2>/dev/null; then
            sudo cp /etc/chrony.conf /etc/chrony.conf.bak 2>/dev/null || true
            printf "\n# added by LFCS setup\npool pool.ntp.org iburst\n" | sudo tee -a /etc/chrony.conf >/dev/null
            sudo systemctl restart chronyd || true
        fi
        LOG_TS "Chrony configured (best-effort)."
    else
        LOG_TS "Chrony not present — skipping."
    fi
}

# ----------------------------
# Task 08: local backend 127.0.0.1:8080
# ----------------------------
Task_08() {
    LOG_TS "[Task 08] Start local backend on 127.0.0.1:8080"
    if ss -ltn | grep -q ':8080'; then
        LOG_TS "port 8080 already in use — skipping."
        return 0
    fi
    ( nohup python3 -m http.server 8080 --bind 127.0.0.1 >/dev/null 2>&1 & )
    sleep 0.5
    LOG_TS "Started python3 http.server on 127.0.0.1:8080."
}

# ----------------------------
# Task 09: static route placeholder
# ----------------------------
Task_09() { LOG_TS "[Task 09] Static route placeholder (student task)"; }

# ----------------------------
# Task 10: assign IP to eth1 if present
# ----------------------------
Task_10() {
    LOG_TS "[Task 10] Assign 172.16.10.20 to eth1 if present"
    if ip link show eth1 >/dev/null 2>&1; then
        sudo ip addr add 172.16.10.20/24 dev eth1 || true
        LOG_TS "Assigned 172.16.10.20 to eth1."
    else
        LOG_TS "eth1 not present — skipped."
    fi
}

# ----------------------------
# Task 11/12: LVM safe creation (robust)
# ----------------------------
_task_create_lvm_on_device() {
    DEV="$1"
    LOG_TS "Aggressively wiping all signatures from $DEV"
    sudo wipefs -a "$DEV"
    
    LOG_TS "pvcreate on $DEV (attempt)"
    if sudo pvcreate -ff -y "$DEV"; then
        LOG_TS "vgcreate vg-data on $DEV (attempt)"
        if sudo vgcreate vg-data "$DEV"; then
            sudo lvcreate -n lv-logs -L 1G vg-data
            sudo lvcreate -n lv-apps -L 2G vg-data
            if [ -b /dev/vg-data/lv-apps ]; then
                sudo mkfs.xfs -f /dev/vg-data/lv-apps
                return 0
            fi
        fi
    fi
    return 1
}

_task_cleanup_stale_loops() {
    IMG_PATH="$1"
    LOG_TS "Checking for existing loop devices mapped to $IMG_PATH..."
    for dev in $(losetup -j "$IMG_PATH" | awk -F: '{print $1}' | sort -r); do
        LOG_TS "Detaching stale loop device: $dev"
        sudo losetup -d "$dev" || true
        LOG_TS "Removing stale LVM device entry: $dev"
        sudo lvmdevices --deldev "$dev" --yes || true
    done
}

Task_11_12() {
    LOG_TS "[Task 11/12] LVM safe creation"
    
    # Define loop image path (needed for cleanup)
    LOOP_DIR="/var/lib/lfcs"
    LOOP_IMG="$LOOP_DIR/lfcs_sdb.img"
    sudo mkdir -p "$LOOP_DIR"

    # "Scorched Earth" cleanup block. Runs unconditionally.
    LOG_TS "LVM Cleanup: Removing old LVs (if any)..."
    sudo lvremove -f vg-data/lv-apps || true
    sudo lvremove -f vg-data/lv-logs || true
    LOG_TS "LVM Cleanup: Removing old device-mapper nodes (if any)..."
    sudo dmsetup remove vg--data-lv--apps || true
    sudo dmsetup remove vg--data-lv--logs || true
    LOG_TS "LVM Cleanup: Forcefully removing 'vg-data' (if it exists)..."
    sudo vgremove -f vg-data || true
    LOG_TS "LVM Cleanup: Removing blocking /dev/vg-data file/dir (if it exists)..."
    sudo rm -rf /dev/vg-data || true
    
    # Run cleanup for the loop image
    _task_cleanup_stale_loops "$LOOP_IMG"

    # Remove the old loop *file* to force re-creation
    LOG_TS "LVM Cleanup: Removing old loop image file to force 3.1G recreation..."
    sudo rm -f "$LOOP_IMG" || true

    if [ -b /dev/sdb ]; then
        PARTS="$(sudo parted -s /dev/sdb print 2>/dev/null || true)"
        SIGS="$(sudo wipefs -n /dev/sdb 2>/dev/null || true)"
        LOG_TS "Inspect /dev/sdb: partitions summary: $(echo "$PARTS" | head -n 2 | tr '\n' ' ') ; signatures: $(echo "$SIGS" | head -n 2 | tr '\n' ' ')"
        if ! echo "$PARTS" | grep -q 'Partition Table' && [ -z "$SIGS" ]; then
            if _task_create_lvm_on_device /dev/sdb; then
                LOG_TS "LVM created on /dev/sdb"
                return 0
            else
                LOG_TS "pvcreate/vgcreate failed on /dev/sdb — falling back to loopback image."
            fi
        else
            LOG_TS "/dev/sdb has partitions/signatures — falling back to loopback image (non-destructive)."
        fi
    fi

    # LOOPBACK fallback
    if [ ! -f "$LOOP_IMG" ]; then
        # Increase size to 3.1G (3172M) to have enough extents
        LOG_TS "Creating loop image $LOOP_IMG (3.1G)"
        sudo fallocate -l 3.1G "$LOOP_IMG" || sudo dd if=/dev/zero of="$LOOP_IMG" bs=1M count=3172
    fi

    # Force LVM to rescan *after* stale devices are detached
    LOG_TS "Forcing LVM to rescan and rebuild cache..."
    sudo vgscan --cache || true
    sudo pvscan --cache || true

    # attach loop device with partscan
    LOOPDEV=$(sudo losetup --show -f --partscan "$LOOP_IMG")
    LOG_TS "Loop device attached: $LOOPDEV"

    # attempt pvcreate
    if _task_create_lvm_on_device "$LOOPDEV"; then
        LOG_TS "LVM successfully created on loop device $LOOPDEV."
        return 0
    else
        LOG_TS "ERROR: pvcreate/vgcreate failed on loop device $LOOPDEV."
        LOG_TS "Recent kernel messages (dmesg tail) for loop device:"
        dmesg | tail -n 40 | sed -n '1,40p'
        LOG_TS "Continuing without LVM to allow rest of environment to be usable."
        return 1
    fi
}

# ----------------------------
# Task 13: NFS export
# ----------------------------
Task_13() {
    LOG_TS "[Task 13] Configure NFS export /export/users"
    sudo mkdir -p /export/users
    echo "Autofs test file" | sudo tee /export/users/test.txt >/dev/null
    sudo chown $NOGROUP /export/users || true
    echo "/export/users *(ro,sync,no_subtree_check)" | sudo tee /etc/exports >/dev/null
    sudo systemctl enable --now "$NFS_SERVICE" || true
    sudo exportfs -ra || true
    LOG_TS "NFS export configured."
}

# ----------------------------
# Task 14: iostat placeholder
# ----------------------------
Task_14() { LOG_TS "[Task 14] iostat placeholder"; }

# ----------------------------
# Task 15: cleanup.service
# ----------------------------
Task_15() {
    LOG_TS "[Task 15] Create cleanup.service"
    sudo mkdir -p /usr/local/bin
    sudo tee /usr/local/bin/cleanup.sh >/dev/null <<'EOF'
#!/bin/bash
echo "Cleanup service ran at $(date)" >> /tmp/cleanup_log.txt
EOF
    sudo chmod +x /usr/local/bin/cleanup.sh
    sudo tee /etc/systemd/system/cleanup.service >/dev/null <<'EOF'
[Unit]
Description=Cleanup Task Service
[Service]
Type=oneshot
ExecStart=/usr/local/bin/cleanup.sh
[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload || true
    sudo systemctl start cleanup.service || true
    LOG_TS "cleanup.service created & started."
}

# ----------------------------
# Task 16: Git repo
# ----------------------------
Task_16() {
    LOG_TS "[Task 16] Clone /opt/lfcs"
    if [ ! -d /opt/lfcs ] || [ -z "$(ls -A /opt/lfcs 2>/dev/null || true)" ]; then
        sudo git clone https://github.com/linux-foundation/lfcs-course.git /opt/lfcs || true
        LOG_TS "git clone attempted."
    else
        LOG_TS "/opt/lfcs exists and non-empty — skipping."
    fi
    sudo mkdir -p /opt/lfcs/config || true
    sudo touch /opt/lfcs/config/settings.conf || true
    echo "# Accidental change by admin" | sudo tee -a /opt/lfcs/config/settings.conf >/dev/null || true
}

# ----------------------------
# Task 17: jdoe files
# ----------------------------
Task_17() {
    LOG_TS "[Task 17] Prepare jdoe"
    if ! id jdoe >/dev/null 2>&1; then
        sudo useradd -m jdoe || true
    fi
    sudo bash -c 'for size in 20M 50M 10M 80M 35M 5M; do fallocate -l $size /home/jdoe/file_${size}.dat || true; done'
    sudo chown -R jdoe:jdoe /home/jdoe || true
    LOG_TS "jdoe and files ready."
}

# ----------------------------
# Task 18: /etc/ssl/private (note)
# ----------------------------
Task_18() {
    LOG_TS "[Task 18] /etc/ssl/private ensure"
    sudo mkdir -p /etc/ssl/private
    sudo chmod 700 /etc/ssl/private
    LOG_TS "Student may run:\n  sudo openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/ssl/private/server.key -out /etc/ssl/private/server.crt -days 365 -subj \"/CN=corp.example.com\""
}

# ----------------------------
# Task 19: appsvc system user
# ----------------------------
Task_19() {
    LOG_TS "[Task 19] Create appsvc"
    if ! id appsvc >/dev/null 2>&1; then
        sudo useradd --system --no-create-home --home-dir /opt/appsvc --shell /sbin/nologin appsvc || true
    fi
    sudo mkdir -p /opt/appsvc
    sudo chown appsvc:appsvc /opt/appsvc || true
    LOG_TS "appsvc created."
}

# ----------------------------
# Task 20: nproc limits for developers
# ----------------------------
Task_20() {
    LOG_TS "[Task 20] Configure nproc for @developers"
    if ! getent group developers >/dev/null 2>&1; then
        sudo groupadd developers || true
    fi
    if ! sudo grep -q '^@developers.*nproc' /etc/security/limits.conf 2>/dev/null; then
        echo "@developers hard nproc 200" | sudo tee -a /etc/security/limits.conf >/dev/null
        LOG_TS "Added limit to /etc/security/limits.conf"
    else
        LOG_TS "nproc limit already present."
    fi
    LOG_TS "Note: users must re-login for changes to apply."
}

# ----------------------------
# Finalize
# ----------------------------
finalize() {
    LOG_TS "[*] Reload daemon & sanity check"
    sudo systemctl daemon-reload || true
    sudo exportfs -ra || true
    LOG_TS "Sanity check: key commands"
    for cmd in git python3 systemctl semanage exportfs losetup lvs lvcreate pvcreate fallocate useradd groupadd; do
        printf "  %-12s : %s\n" "$cmd" "$(command_exists "$cmd" && echo present || echo missing)"
    done
    LOG_TS "✅ LFCS Practice Exam 2 environment setup complete!"
}

# ----------------------------
# Main
# ----------------------------
main() {
    # --- Safety Prompt ---
    LOG_TS "WARNING: This script will install packages (dnf/apt) and modify system"
    LOG_TS "         configuration (LVM, libvirt, etc.) for the LFCS Practice Exam 2."
    LOG_TS "         It is intended for a dedicated, non-production lab environment."
    read -p "Are you sure you want to proceed? (y/N) " -r REPLY
    echo # (adds a newline)

    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        LOG_TS "Operation cancelled by user. Exiting."
        exit 1
    fi
    
    LOG_TS "User confirmed. Proceeding with setup..."
    # --- End Safety Prompt ---

    initial_setup
    Task_01
    Task_02
    Task_03
    Task_04
    Task_05
    Task_06
    Task_07
    Task_08
    Task_09
    Task_10
    Task_11_12
    Task_13
    Task_14
    Task_15
    Task_16
    Task_17
    Task_18
    Task_19
    Task_20
    finalize
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
# End of file

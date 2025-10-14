#!/bin/bash
# =====================================================================
# LFCS Lab Cleanup Utility – Safe & Cross-Distro Version
# =====================================================================

set -e
echo "==============================================================="
echo "🧹 Starting LFCS Lab Cleanup..."
echo "==============================================================="

# Detect Distribution
if [ -f /etc/redhat-release ]; then
    DISTRO="rhel"
    FIREWALL_CMD="firewall-cmd"
    NFS_SERVICE="nfs-server"
elif [ -f /etc/debian_version ]; then
    DISTRO="debian"
    FIREWALL_CMD="ufw"
    NFS_SERVICE="nfs-kernel-server"
else
    DISTRO="unknown"
fi

# Stop services safely
echo "[*] Stopping lab-related services..."
for svc in nginx smb nfs-server nfs-kernel-server log-archive cleanup inventory faulty-daemon data-importer; do
    systemctl stop "$svc" 2>/dev/null || true
done

# Remove systemd unit files
echo "[*] Removing custom systemd units..."
find /etc/systemd/system -maxdepth 1 -type f -name "*archive.service" -delete 2>/dev/null || true
find /etc/systemd/system -maxdepth 1 -type f -name "*cleanup.service" -delete 2>/dev/null || true
find /etc/systemd/system -maxdepth 1 -type f -name "*faulty*.service" -delete 2>/dev/null || true

# Containers cleanup
echo "[*] Removing Podman containers..."
if command -v podman >/dev/null; then
    podman rm -f $(podman ps -aq) 2>/dev/null || true
fi

# Kill any lab-generated background listeners
echo "[*] Killing background nc or yes processes..."
pkill -f "nc -l" 2>/dev/null || true
pkill -f "yes > /dev/null" 2>/dev/null || true

# Unmount lab mounts
echo "[*] Unmounting lab mounts..."
for mnt in /mnt/staging /mnt/lv-test /srv/share /quota /opt/data /mnt/legacy; do
    umount "$mnt" 2>/dev/null || true
done

# Disable NFS exports
echo "[*] Clearing NFS exports..."
exportfs -u -a 2>/dev/null || true
> /etc/exports

# Remove temp users
echo "[*] Removing temporary users..."
for usr in temp_contractor jdoe dev1 dev2 dev3 winuser intern_user temp_worker inv_user tomcat; do
    userdel -r "$usr" 2>/dev/null || true
done

# Remove groups if empty
for grp in developers devteam ssh_users; do
    groupdel "$grp" 2>/dev/null || true
done

# Delete lab files and directories
echo "[*] Removing lab directories..."
rm -rf /usr/local/bin/log_archive.sh \
       /usr/local/bin/backup.sh \
       /usr/local/bin/cleanup.sh \
       /usr/local/bin/log-rotate.sh \
       /usr/local/bin/backup_daily.sh \
       /opt/lfcs* \
       /opt/app-config \
       /opt/webapp \
       /opt/scripts \
       /srv/share \
       /srv/projects \
       /srv/docs \
       /srv/sharedocs \
       /srv/webdata \
       /quota \
       /backups \
       /data \
       /var/www/html/cache \
       /var/www/html/tmp.dat \
       /var/www/html/test.html \
       /opt/data \
       /tmp/raidloop*.img \
       /tmp/io_load.tmp 2>/dev/null || true

# Stop RAID & LVM
echo "[*] Cleaning RAID and LVM..."
mdadm --stop /dev/md1 2>/dev/null || true
mdadm --remove /dev/md1 2>/dev/null || true
vgremove -f vg-data 2>/dev/null || true
vgremove -f vg-main 2>/dev/null || true
pvremove -ff /dev/sd[b-e] 2>/dev/null || true

# Reset firewall rules
if [ "$DISTRO" = "rhel" ]; then
    $FIREWALL_CMD --reload 2>/dev/null || true
else
    ufw reload 2>/dev/null || true
fi

# Reload systemd
systemctl daemon-reload || true

echo ""
echo "==============================================================="
echo "✅ LFCS Lab cleanup completed successfully."
echo "All temporary services, users, and mounts have been removed."
echo "==============================================================="
echo "You can now safely set up a new LFCS practice exam environment."
echo "==============================================================="
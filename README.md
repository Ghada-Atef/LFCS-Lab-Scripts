# LFCS-Lab-Scripts

Comprehensive automation scripts to set up, verify, and clean Linux labs for the **Linux Foundation Certified System Administrator (LFCS)** Practice Exams.

## Overview

This repository provides:

- Automated lab setup scripts for **Practice Exams 1–6**
- **Cross-distribution support** (RHEL, AlmaLinux, Rocky Linux, Ubuntu Server)
- Built-in **error handling, device safety, and idempotency**
- Utility scripts for **lab cleanup**

The lab specification below matches the course exactly: **four network adapters (eth0–eth3)** and **five extra data disks**. Build your VM to this spec or some tasks will not have the hardware they expect.

---

## Part 1: Base Lab Environment Setup

This guide walks you through setting up a virtual lab environment using free tools and open-source Linux distributions.

### 📋 Minimum System Requirements

Before you begin, make sure your host machine meets the following:

- **Operating System:** Windows, macOS, or Linux
- **RAM:** Minimum 8 GB (12–16 GB recommended)
- **Free Disk Space:** At least 50 GB
- **Virtualization:** VT-x / AMD-V enabled in BIOS/UEFI
- **Internet Access:** Required for downloads and updates
- **Virtualization Software:**
  * Oracle VirtualBox (Free — Recommended)
  * VMware Workstation Player (Free for non-commercial use)

---

### 🔧 Step 1: Install VirtualBox (Hypervisor)

1. Go to the official VirtualBox website.
2. Download the latest version for your OS (Windows, macOS, or Linux).
3. Run the installer and accept all default options.

### 🐧 Step 2: Download a Linux Server ISO

Choose one of the following **server distributions**:

- **Rocky Linux / AlmaLinux** — great for Red Hat-based practice
- **Ubuntu Server LTS** — widely used and beginner-friendly

Download the latest **Server ISO** from the official website of your chosen distro.

> **Tip:** The real LFCS exam lets you choose your distribution. If you can, build both VMs; at minimum, read the dual-distro notes in the course for the platform you skipped.

### 💻 Step 3: Create the Virtual Machine (VM)

1. Open VirtualBox and click **New**.
2. Configure the VM:
   - **Name:** `LFCS-Practice-Lab`
   - **Type:** `Linux`
   - **Version:** Match your distribution (e.g., `Red Hat (64-bit)` or `Ubuntu (64-bit)`)
3. Set **Hardware Options**:
   - **RAM:** Minimum 2 GB (4 GB recommended)
   - **CPU:** 2 virtual CPUs
4. **Virtual Hard Disk**:
   - Select `Create new` → `VDI` → `Dynamically allocated`
   - **Size:** `30 GB`
   - Click **Create**

### 🛠️ Step 4: Configure Virtual Hardware (Before Installing OS)

This step is critical and ensures your lab supports all LFCS tasks.

1. Select the `LFCS-Practice-Lab` VM and click **Settings**.
2. **Add Extra Virtual Disks (for LVM, RAID, filesystems, swap)**
   - Go to **Storage** → **SATA Controller**.
   - **Add five additional virtual hard disks**, each **5 GB** in size.
   - These simulate secondary drives for storage-related tasks (LVM, RAID 5, swap, migration).
3. **Add Network Interfaces (for IP config, bridging, bonding)**
   - Go to **Network** and enable **four adapters**:
   - **Adapter 1:** `Enable` → Attached to: `NAT` (internet access, script downloads)
   - **Adapter 2:** `Enable` → Attached to: `Host-only Adapter` (SSH, IP configuration)
   - **Adapter 3:** `Enable` → Attached to: `Host-only Adapter` (bonding/bridging tasks)
   - **Adapter 4:** `Enable` → Attached to: `Host-only Adapter` (bonding/bridging tasks)
4. Click **OK** to save settings.

### 📥 Step 5: Install the Linux Server OS

1. Start your VM. It will prompt you to select the ISO file you downloaded.
2. **Keep classic interface names (critical).** At the installer's boot menu, edit the kernel line (**Tab** on BIOS, **e** on UEFI) and append:

       net.ifnames=0 biosdevname=0

   This keeps your interfaces named `eth0`–`eth3`, matching every task in the course.
3. Proceed with the OS installer:
   - Choose a **Minimal** or **Server** installation.
   - **Do not install a GUI** — the LFCS exam is command-line only.
   - Install to the **30 GB primary disk** only (leave the 5 GB disks untouched).
   - Create a non-root user and set strong passwords.
4. After the installation, reboot when prompted.

### 📦 Step 6: Install Essential Packages

Log in to your VM and install the key tools required by the practice exams.

**For Rocky Linux / AlmaLinux (DNF-based):**

    sudo dnf install -y podman git nano policycoreutils-python-utils \
      libvirt-client libvirt-daemon libvirt-daemon-driver-qemu qemu-kvm qemu-img \
      firewalld chrony nfs-utils cifs-utils mdadm sysstat iotop nginx \
      nmap-ncat zip dnf-plugins-core autofs rsync xfsprogs dosfstools

**For Ubuntu Server (APT-based):**

    sudo apt update
    sudo apt install -y podman git nano \
      libvirt-clients libvirt-daemon-system libvirt-daemon-driver-qemu qemu-kvm qemu-utils \
      firewalld chrony nfs-common cifs-utils mdadm sysstat iotop nginx \
      netcat-openbsd zip debsums autofs rsync xfsprogs dosfstools bridge-utils

> **Platform notes:** Network persistence differs — Rocky Linux uses NetworkManager (`nmcli` profiles); Ubuntu Server uses netplan (YAML files under `/etc/netplan`). The course always shows both paths. The lab standardizes on **firewalld** for both families.

### 📸 Step 7: Take a Clean Snapshot

This is the most important step for resetting your lab. This snapshot is your master reset point before each practice exam.

1. With the VM **shut down**, go to **Machine** → **Take Snapshot**.
2. **Name it exactly:** `Clean Install`
3. Confirm.

Your base lab is now ready!

---

## Part 2: Running the Exam-Specific Setup Scripts

### 🔁 The Snapshot Workflow: Your Key to Success

Before starting **any** practice exam, you must reset your lab to a fresh state.

1. **Shut down** the VM.
2. In VirtualBox, right-click your VM → **Restore Snapshot**.
3. Choose your **"Clean Install"** snapshot and restore it.
4. **Start** the VM. It is now 100% clean.
5. Run the **one** setup script for the exam you are about to take.

**Repeat this "Restore Snapshot" process before every new exam session.** Running the wrong script, running one twice, or skipping the restore can produce a lab state the exam tasks do not expect.

### 🚀 Recommended Execution (Fix for Issue #21)

To avoid potential "unbound variable" errors, download the script first and then execute it. Do not use `curl | sudo bash` — downloading first also lets you review the script before it runs with root privileges.

**Example for Practice Exam 1:**

    # Download the script
    curl -o LFCS_Practice_Exam_1_Setup.sh https://raw.githubusercontent.com/Ghada-Atef/LFCS-Lab-Scripts/main/exams/LFCS_Practice_Exam_1_Setup.sh

    # Run the script
    sudo bash LFCS_Practice_Exam_1_Setup.sh

**No internet in the VM?** Download the script on your host, transfer or paste it into a file in the VM, then run `sudo bash LFCS_Practice_Exam_X_Setup.sh`.

### Script Quick Reference

For each practice exam, replace the number in both the filename and the URL:

| Exam | Setup command |
|---|---|
| Practice Exam 1 | `curl -o LFCS_Practice_Exam_1_Setup.sh https://raw.githubusercontent.com/Ghada-Atef/LFCS-Lab-Scripts/main/exams/LFCS_Practice_Exam_1_Setup.sh && sudo bash LFCS_Practice_Exam_1_Setup.sh` |
| Practice Exam 2 | `curl -o LFCS_Practice_Exam_2_Setup.sh https://raw.githubusercontent.com/Ghada-Atef/LFCS-Lab-Scripts/main/exams/LFCS_Practice_Exam_2_Setup.sh && sudo bash LFCS_Practice_Exam_2_Setup.sh` |
| Practice Exam 3 | `curl -o LFCS_Practice_Exam_3_Setup.sh https://raw.githubusercontent.com/Ghada-Atef/LFCS-Lab-Scripts/main/exams/LFCS_Practice_Exam_3_Setup.sh && sudo bash LFCS_Practice_Exam_3_Setup.sh` |
| Practice Exam 4 | `curl -o LFCS_Practice_Exam_4_Setup.sh https://raw.githubusercontent.com/Ghada-Atef/LFCS-Lab-Scripts/main/exams/LFCS_Practice_Exam_4_Setup.sh && sudo bash LFCS_Practice_Exam_4_Setup.sh` |
| Practice Exam 5 | `curl -o LFCS_Practice_Exam_5_Setup.sh https://raw.githubusercontent.com/Ghada-Atef/LFCS-Lab-Scripts/main/exams/LFCS_Practice_Exam_5_Setup.sh && sudo bash LFCS_Practice_Exam_5_Setup.sh` |
| Practice Exam 6 | `curl -o LFCS_Practice_Exam_6_Setup.sh https://raw.githubusercontent.com/Ghada-Atef/LFCS-Lab-Scripts/main/exams/LFCS_Practice_Exam_6_Setup.sh && sudo bash LFCS_Practice_Exam_6_Setup.sh` |

---

*This project is an independent publication and is not affiliated with, authorized, sponsored, or otherwise approved by The Linux Foundation. LFCS is a trademark of The Linux Foundation.*

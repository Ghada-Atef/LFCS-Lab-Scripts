# LFCS-Lab-Scripts

Comprehensive automation scripts to set up, verify, and clean Linux labs for the **Linux Foundation Certified System Administrator (LFCS)** Practice Exams.

## Overview

This repository provides:

  * Automated lab setup scripts for **Practice Exams 1-6**
  * **Cross-distribution support** (RHEL, AlmaLinux, Rocky, Ubuntu)
  * Built-in **error handling, device safety, and idempotency**
  * Utility scripts for **lab cleanup**

-----

## Part 1: Base Lab Environment Setup

This guide walks you through setting up a virtual lab environment, using free tools and open-source Linux distributions.

### 📋 Minimum System Requirements

Before you begin, make sure your host machine meets the following:

  * **Operating System:** Windows, macOS, or Linux
  * **RAM:** Minimum 8 GB (12-16 GB recommended)
  * **Free Disk Space:** At least 50 GB
  * **Internet Access:** Required for downloads and updates
  * **Virtualization Software:**
      * Oracle VirtualBox (Free - Recommended)
      * VMware Workstation Player (Free for non-commercial use)

-----

### 🔧 Step 1: Install VirtualBox (Hypervisor)

1.  Go to the official VirtualBox website.
2.  Download the latest version for your OS (Windows, macOS, or Linux).
3.  Run the installer and accept all default options.

### 🐧 Step 2: Download a Linux Server ISO

Choose one of the following **server distributions**:

  * **Rocky Linux / AlmaLinux** - Great for Red Hat-based practice
  * **Ubuntu Server LTS** - Widely used and beginner-friendly

Download the latest **Server ISO** from the official website of your chosen distro.

### 💻 Step 3: Create the Virtual Machine (VM)

1.  Open VirtualBox and click **New**.
2.  Configure the VM:
      * **Name:** `LFCS-Practice-Lab`
      * **Type:** `Linux`
      * **Version:** Match your distribution (e.g., `Red Hat (64-bit)` or `Ubuntu (64-bit)`)
3.  Set **Hardware Options**:
      * **RAM:** Minimum 2 GB (4 GB recommended)
      * **CPU:** 2 virtual CPUs
4.  **Virtual Hard Disk**:
      * Select `Create new` → `VDI` → `Dynamically allocated`
      * **Size:** `30 GB`
      * Click **Create**

### 🛠️ Step 4: Configure Virtual Hardware (Before Installing OS)

This step is critical and ensures your lab supports all LFCS tasks.

1.  Select the `LFCS-Practice-Lab` VM and click **Settings**.
2.  **Add Extra Virtual Disks (for LVM, RAID, etc.)**
      * Go to **Storage** → **SATA Controller**.
      * **Add four additional virtual hard disks**, each **5 GB** in size.
      * These simulate secondary drives for storage-related tasks.
3.  **Add Network Interfaces (for IP config, bridging, bonding)**
      * Go to **Network**.
      * **Adapter 1:**
          * `Enable`
          * Attached to: `NAT` (for internet access)
      * **Adapter 2:**
          * `Enable`
          * Attached to: `Host-only Adapter` (for SSH, IP configuration)
      * **Adapter 3:**
          * `Enable`
          * Attached to: `Host-only Adapter` (needed for bonding/bridging tasks)
4.  Click **OK** to save settings.

### 📥 Step 5: Install the Linux Server OS

1.  Start your VM. It will prompt you to select the ISO file you downloaded.
2.  Proceed with the OS installer:
      * Choose a **Minimal** or **Server** installation.
      * **Do not install a GUI** – the LFCS exam is command-line only.
      * Install to the **30 GB primary disk** only (leave the 5 GB disks untouched).
      * Create a non-root user and set strong passwords.
3.  After the installation, reboot when prompted.

### 📸 Step 6: Take a Clean Snapshot

This is the most important step for resetting your lab. This snapshot is your master reset point before each new lab session.

1.  With the VM **shut down**, go to **Machine** → **Take Snapshot**.
2.  **Name it:** `Clean Install`
3.  Confirm.

### 📦 Step 7: Install Essential Packages

Log in to your VM and install the key tools required by the practice exams.

**For Rocky Linux / AlmaLinux (DNF-based):**

```bash
sudo dnf install -y podman git nano policycoreutils-python-utils libvirt-client firewalld chrony nfs-utils cifs-utils mdadm sysstat iotop nginx
```

**For Ubuntu Server (APT-based):**

```bash
sudo apt update
sudo apt install -y podman git nano semanage-utils libvirt-clients firewalld chrony nfs-common cifs-utils mdadm sysstat iotop nginx bridge-utils
```

Your base lab is now ready\!

-----

## Part 2: Running the Exam-Specific Setup Scripts

### 🔁 The Snapshot Workflow: Your Key to Success

Before starting **any** practice exam, you must reset your lab to a fresh state.

1.  **Shut down** the VM.
2.  In VirtualBox, right-click your VM → **Restore Snapshot**.
3.  Choose your **"Clean Install"** snapshot and restore it.
4.  **Start** the VM. It is now 100% clean.
5.  Run the setup script for the exam you are about to take.

**Repeat this "Restore Snapshot" process before every new exam session.**

### 🚀 Recommended Execution (Fix for Issue \#21)

To avoid potential "unbound variable" errors, download the script first and then execute it. Do not use `curl | sudo bash`.

**Example for Practice Exam 1:**

```bash
# Download the script
curl -o LFCS_Practice_Exam_1_Setup.sh https://raw.githubusercontent.com/Ghada-Atef/LFCS-Lab-Scripts/main/exams/LFCS_Practice_Exam_1_Setup.sh

# Run the script
sudo bash LFCS_Practice_Exam_1_Setup.sh
```

### Script Quick Reference

Use these commands to set up the lab for each specific exam.

**Practice Exam 1**

```bash
curl -o LFCS_Practice_Exam_1_Setup.sh https://raw.githubusercontent.com/Ghada-Atef/LFCS-Lab-Scripts/main/exams/LFCS_Practice_Exam_1_Setup.sh
sudo bash LFCS_Practice_Exam_1_Setup.sh
```

**Practice Exam 2**

```bash
curl -o LFCS_Practice_Exam_2_Setup.sh https://raw.githubusercontent.com/Ghada-Atef/LFCS-Lab-Scripts/main/exams/LFCS_Practice_Exam_2_Setup.sh
sudo bash LFCS_Practice_Exam_2_Setup.sh
```

**Practice Exam 3**

```bash
curl -o LFCS_Practice_Exam_3_Setup.sh https://raw.githubusercontent.com/Ghada-Atef/LFCS-Lab-Scripts/main/exams/LFCS_Practice_Exam_3_Setup.sh
sudo bash LFCS_Practice_Exam_3_Setup.sh
```

**Practice Exam 4**

```bash
curl -o LFCS_Practice_Exam_4_Setup.sh https://raw.githubusercontent.com/Ghada-Atef/LFCS-Lab-Scripts/main/exams/LFCS_Practice_Exam_4_Setup.sh
sudo bash LFCS_Practice_Exam_4_Setup.sh
```

**Practice Exam 5**

```bash
curl -o LFCS_Practice_Exam_5_Setup.sh https://raw.githubusercontent.com/Ghada-Atef/LFCS-Lab-Scripts/main/exams/LFCS_Practice_Exam_5_Setup.sh
sudo bash LFCS_Practice_Exam_5_Setup.sh
```

**Practice Exam 6**

```bash
curl -o LFCS_Practice_Exam_6_Setup.sh https://raw.githubusercontent.com/Ghada-Atef/LFCS-Lab-Scripts/main/exams/LFCS_Practice_Exam_6_Setup.sh
sudo bash LFCS_Practice_Exam_6_Setup.sh
```

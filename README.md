# LFCS-Lab-Scripts

Comprehensive automation scripts to set up, verify, and clean Linux labs for the **Linux Foundation Certified System Administrator (LFCS)** Practice Exams.

## 📘 Overview
This repository provides:
- Automated lab setup scripts for **Practice Exams 1–6**  
- **Cross-distribution support** (RHEL, AlmaLinux, Rocky, Ubuntu)  
- Built-in **error handling, device safety, and idempotency**  
- Utility scripts for **lab cleanup**

## Usage

### Setup a Specific lab

Run the corresponding setup script for each exam. To avoid potential "unbound variable" errors, it's highly recommended to download the script first and then execute it.

**Example for Exam 3:**

```bash
# Download the script
curl -o LFCS_Practice_Exam_3_Setup.sh [https://raw.githubusercontent.com/Ghada-Atef/LFCS-Lab-Scripts/main/exams/LFCS_Practice_Exam_3_Setup.sh](https://raw.githubusercontent.com/Ghada-Atef/LFCS-Lab-Scripts/main/exams/LFCS_Practice_Exam_3_Setup.sh)

# Run the script
sudo bash LFCS_Practice_Exam_3_Setup.sh

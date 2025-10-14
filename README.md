# LFCS-Lab-Scripts

Comprehensive automation scripts to set up, verify, and clean Linux labs for the **Linux Foundation Certified System Administrator (LFCS)** Practice Exams.

## 📘 Overview
This repository provides:
- Automated lab setup scripts for **Practice Exams 1–6**  
- **Cross-distribution support** (RHEL, AlmaLinux, Rocky, Ubuntu)  
- Built-in **error handling, device safety, and idempotency**  
- Utility scripts for **lab cleanup**

## 🧩 Usage

### 1️⃣ Setup a Specific Lab
Run the corresponding setup script for each exam (example for Exam 3):
```bash
curl -s https://raw.githubusercontent.com/Ghada-Atef/LFCS-Lab-Scripts/main/exams/LFCS_Practice_Exam_3_Setup.sh | sudo bash

# Realme XT (RMX1971) — PixelOS 17 / Android 17 (CP2A) Patches & Manifest

This repository contains the local manifests, platform source patches, and step-by-step restoration automation needed to build **PixelOS 17 (Android 17 / CP2A)** for the **Realme XT (`RMX1971`)** (Qualcomm Snapdragon 710 platform).

---

## Quick Setup on a New Server

```bash
# 1. Inside your ROM source tree (e.g. ~/pos):
cd ~/pos

# 2. Clone this patches repository:
git clone https://github.com/gaurav-paul9/rmx1971-patches.git ~/rmx1971-patches

# 3. Run the automated restoration script:
bash ~/rmx1971-patches/restore_rmx1971_a17.sh ~/pos

# 4. Build the ROM:
source build/envsetup.sh
lunch custom_RMX1971-cp2a-userdebug
m bacon -j$(nproc --all)
```

For the complete architectural guide, deep dive into Soong sandboxing fixes, and HAL details, read [BUILD_GUIDE_RMX1971.md](BUILD_GUIDE_RMX1971.md).

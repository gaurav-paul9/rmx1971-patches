# Realme XT (RMX1971) — PixelOS 17 (Android 17 / CP2A) Complete Build & Source Guide

This document details all configuration, device-side adaptations, vendor blob patches, and platform source fixes required to cleanly build **PixelOS 17 / Android 17 (CP2A)** for the **Realme XT (`RMX1971`)** (Qualcomm Snapdragon 710 platform).

Use this guide and the accompanying restoration script to replicate this build on a new server.

---

## 1. Quick Start: Restoring on a Fresh Server

### Step 1: Initialize and Sync PixelOS 17
```bash
mkdir -p ~/pos && cd ~/pos
repo init -u https://github.com/PixelOS-Pixelish/manifest.git -b seventeen --git-lfs
repo sync -c --no-clone-bundle --optimized-fetch --prune --force-sync -j$(nproc --all)
```

### Step 2: Set Up Local Manifest
Create `.repo/local_manifests/rmx1971.xml`:
```bash
mkdir -p .repo/local_manifests
cat << 'XML' > .repo/local_manifests/rmx1971.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
    <!-- Device Tree -->
    <project name="gaurav-paul9/device_realme_RMX1971" path="device/realme/RMX1971" remote="github" revision="seventeen" />

    <!-- Vendor Tree -->
    <project name="kaderbava/vendor_realme_RMX1971" path="vendor/realme/RMX1971" remote="gitlab" revision="16" />

    <!-- Kernel (SDM710 4.9 BPF) -->
    <project name="kaderbava/android_kernel_realme_sdm710" path="kernel/realme/sdm710" remote="github" revision="16-bpf-r5p" />

    <!-- Connectivity with BPF Reverts -->
    <remove-project name="PixelOS-Pixelish/packages_modules_Connectivity" />
    <project name="gaurav-paul9/android_packages_modules_Connectivity" path="packages/modules/Connectivity" remote="github" revision="seventeen" />

    <!-- Qualcomm CAF SDM660 HALs (LineageOS 24.0) -->
    <project name="LineageOS/android_hardware_qcom_audio" path="hardware/qcom-caf/sdm660/audio" remote="github" revision="lineage-24.0-caf-sdm660" />
    <project name="LineageOS/android_hardware_qcom_display" path="hardware/qcom-caf/sdm660/display" remote="github" revision="lineage-24.0-caf-sdm660" />
    <project name="LineageOS/android_hardware_qcom_media" path="hardware/qcom-caf/sdm660/media" remote="github" revision="lineage-24.0-caf-sdm660" />

    <!-- Hardware Dolby & BCR -->
    <project name="crdroidandroid/android_hardware_dolby" path="hardware/dolby" remote="github" revision="16.0" />
    <project name="Lunaris-AOSP/vendor_bcr" path="vendor/bcr" remote="github" revision="16.2" />
</manifest>
XML

repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
```

### Step 3: Run the Auto-Restoration Script
Clone the patch repo (or copy `ascp-patches`):
```bash
bash ~/ascp-patches/restore_rmx1971_a17.sh ~/pos
```

### Step 4: Build
```bash
cd ~/pos
source build/envsetup.sh
lunch custom_RMX1971-cp2a-userdebug
m bacon -j$(nproc --all)
```

---

## 2. Platform Architecture & HAL Grouping

- **SoC**: Qualcomm Snapdragon 710 (`SDM710` / `sdm670` family).
- **HAL Selection**:
  - In modern LineageOS 24.0 / Android 17, Qualcomm SDM660, SDM670, and SDM710 are officially maintained under **`hardware/qcom-caf/sdm660`** (`lineage-24.0-caf-sdm660`).
  - `sdm845` HALs were deprecated after branch 23.2 and do not exist in LineageOS 24.0.
  - `sm8150` has differing kernel UAPI structures and cannot be used for SDM710 display or media.

---

## 3. Device Tree Changes (`device/realme/RMX1971`)

Branch: **`seventeen`** (Remote: `https://github.com/gaurav-paul9/device_realme_RMX1971.git`)

### Key Modifications:
1. **HAL Paths & Soong Namespaces (`device.mk`)**:
   ```make
   SRC_AUDIO_HAL_DIR := hardware/qcom-caf/sdm660/audio
   SRC_DISPLAY_HAL_DIR := hardware/qcom-caf/sdm660/display
   SRC_MEDIA_HAL_DIR := hardware/qcom-caf/sdm660/media

   PRODUCT_SOONG_NAMESPACES += \
       hardware/qcom-caf/sdm660
   ```
2. **Display Stack Packages (`device.mk`)**:
   Replaced deprecated allocator 1.0 with modern AIDL allocator service and mapper 3.0/4.0:
   ```make
   PRODUCT_PACKAGES += \
       android.hardware.graphics.composer@2.3-service \
       android.hardware.graphics.mapper@3.0-impl-qti-display \
       android.hardware.graphics.mapper@4.0-impl-qti-display \
       gralloc.sdm710 \
       hwcomposer.qcom \
       libvulkan \
       vendor.qti.hardware.memtrack-service \
       vendor.qti.hardware.display.allocator-service
   ```
3. **Blob Fixup (`extract-files.py`)**:
   Updated WFD audio type replacement to V5:
   ```python
   'system_ext/lib/libwfdservice.so': blob_fixup()
       .add_needed('libaudioclient_shim.so')
       .replace_needed('android.media.audio.common.types-V3-cpp.so', 'android.media.audio.common.types-V5-cpp.so'),
   ```

---

## 4. Vendor Tree Changes (`vendor/realme/RMX1971`)

Branch: **`16`** (Remote: `https://gitlab.com/kaderbava/vendor_realme_RMX1971.git`)

### Key Modifications:
1. **Soong Namespace Import (`Android.bp`)**:
   ```text
   soong_namespace {
       imports: [
           "device/realme/RMX1971",
           "hardware/qcom-caf/sdm660",
           ...
       ],
   }
   ```
2. **Deprecated Libraries Pruned (`Android.bp`)**:
   - Removed references to `libdisplaydebug` (no longer in A17 display HAL).
   - Removed references to `libheif` (removed from AOSP core libraries).
3. **WFD Service Binary DT_NEEDED Patched**:
   - `proprietary/system_ext/lib/libwfdservice.so` binary patched via `patchelf`:
     `patchelf --replace-needed android.media.audio.common.types-V4-cpp.so android.media.audio.common.types-V5-cpp.so proprietary/system_ext/lib/libwfdservice.so`
   - Updated `Android.bp` shared library dependency to `android.media.audio.common.types-V5-cpp`.

---

## 5. Kernel & Connectivity

### Kernel:
- **Repository**: `https://github.com/kaderbava/android_kernel_realme_sdm710.git`
- **Branch**: `16-bpf-r5p`
- **Path**: `kernel/realme/sdm710`
- Contains backported BPF engine patches allowing modern Android network monitoring on Linux 4.9.

### Connectivity Module:
- **Repository**: `https://github.com/gaurav-paul9/android_packages_modules_Connectivity.git`
- **Branch**: `seventeen`
- **Path**: `packages/modules/Connectivity`
- Retains 5 BPF reverts in `bpf/progs/offload.c` enabling network offload and packet accounting compatibility with 4.9 kernels without crashing or failing verification.

---

## 6. Critical Android 17 / CP2A Source Fixes

### Fix 1: Soong RuleBuilder Sbox Sandboxing Bypass
- **File**: `vendor/lineage/build/soong/generator/generator.go`
- **Problem**: In Android 17 / CP2A, Google enforced strict hermetic sandboxing (`Sbox`). When `lineage_generator` runs `make headers_install`, hundreds of kernel UAPI headers are generated into `usr/include/`. Because Soong only has `.dummy_dep` declared as an output, `sbox` copied back `.dummy_dep` and deleted the entire sandbox directory containing all kernel headers (`drm/sde_drm.h`, `linux/msm_mdp_ext.h`, etc.).
- **Fix**: Remove `.Sbox(...)` from `RuleBuilder`:
  ```diff
  diff --git a/build/soong/generator/generator.go b/build/soong/generator/generator.go
  --- a/build/soong/generator/generator.go
  +++ b/build/soong/generator/generator.go
  @@ -258,9 +258,7 @@ func (g *Module) GenerateAndroidBuildActions(ctx android.ModuleContext) {
   	dummyDep := android.PathForModuleGen(ctx, ".dummy_dep")
  -	genDir := android.PathForModuleGen(ctx)
  -	manifestPath := android.PathForModuleOut(ctx, "generator.sbox.textproto")
  -	rule := android.NewRuleBuilder(pctx, ctx).Sbox(genDir, manifestPath)
  +	rule := android.NewRuleBuilder(pctx, ctx)
  ```

### Fix 2: `clean_headers.sh` Path Parameters
- **File**: `vendor/lineage/tools/clean_headers.sh`
- **Problem**: When headers are directly generated, raw `struct sigaction` in `asm-generic/signal.h` conflicts with bionic's `sigaction`. Lineage's script failed to sanitize the headers because it invoked `clean_header.py` without `-k` (source) and `-d` (destination).
- **Fix**:
  ```diff
  diff --git a/tools/clean_headers.sh b/tools/clean_headers.sh
  --- a/tools/clean_headers.sh
  +++ b/tools/clean_headers.sh
  @@ -3,6 +3,9 @@ set -eu
   export ANDROID_BUILD_TOP="$PWD"
  -./bionic/libc/kernel/tools/clean_header.py -u \
  -    "$1/usr/include/asm/signal.h" \
  -    "$1/usr/include/asm-generic/signal.h"
  +./bionic/libc/kernel/tools/clean_header.py \
  +    -k "$1/usr/include" \
  +    -d "$1/usr/include" \
  +    -u \
  +    asm/signal.h \
  +    asm-generic/signal.h
  ```

---

## 7. Verification Targets
To independently verify that the display and kernel headers are working before running the full ROM build:
```bash
# Verify kernel header generation and display core:
m libsdmcore

# Verify hardware composer 2 service:
m hwcomposer.qcom

# Verify gralloc allocator service:
m vendor.qti.hardware.display.allocator-service gralloc.sdm710
```
All four commands must finish with `#### build completed successfully ####` (Exit code 0).

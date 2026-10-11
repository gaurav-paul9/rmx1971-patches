#!/bin/bash
# ==============================================================================
# Realme XT (RMX1971) PixelOS 17 / Android 17 (CP2A) Auto-Restoration Script
# Usage:
#   bash /path/to/restore_rmx1971_a17.sh /path/to/rom_root
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROM_ROOT="${1:-$PWD}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}==================================================================${NC}"
echo -e "${BLUE}  Realme XT (RMX1971) Android 17 (PixelOS) Setup & Patch Applicator${NC}"
echo -e "${BLUE}==================================================================${NC}"
echo "ROM Root Directory: $ROM_ROOT"
cd "$ROM_ROOT"

# 1. Local Manifests
echo -e "\n${YELLOW}[1/4] Setting up local manifest...${NC}"
mkdir -p .repo/local_manifests
cp "$SCRIPT_DIR/local_manifests/rmx1971.xml" .repo/local_manifests/rmx1971.xml
echo -e "${GREEN}✓ Local manifest installed to .repo/local_manifests/rmx1971.xml${NC}"

# 2. Sync / Verify Repositories
echo -e "\n${YELLOW}[2/4] Verifying required repositories...${NC}"
declare -A REPOS=(
    ["device/realme/RMX1971"]="https://github.com/gaurav-paul9/device_realme_RMX1971.git seventeen"
    ["vendor/realme/RMX1971"]="https://github.com/gaurav-paul9/vendor_realme_RMX1971.git 16"
    ["kernel/realme/sdm710"]="https://github.com/kaderbava/android_kernel_realme_sdm710.git 16-bpf-r5p"
    ["packages/modules/Connectivity"]="https://github.com/gaurav-paul9/android_packages_modules_Connectivity.git seventeen"
    ["hardware/qcom-caf/sdm660/audio"]="https://github.com/LineageOS/android_hardware_qcom_audio.git lineage-24.0-caf-sdm660"
    ["hardware/qcom-caf/sdm660/display"]="https://github.com/LineageOS/android_hardware_qcom_display.git lineage-24.0-caf-sdm660"
    ["hardware/qcom-caf/sdm660/media"]="https://github.com/LineageOS/android_hardware_qcom_media.git lineage-24.0-caf-sdm660"
    ["hardware/dolby"]="https://github.com/crdroidandroid/android_hardware_dolby.git 16.0"
    ["vendor/bcr"]="https://github.com/Lunaris-AOSP/vendor_bcr.git 16.2"
)

for path in "${!REPOS[@]}"; do
    repo_info=(${REPOS[$path]})
    repo_url="${repo_info[0]}"
    repo_branch="${repo_info[1]}"
    if [ ! -d "$path/.git" ]; then
        echo "Cloning $path ($repo_branch)..."
        git clone "$repo_url" -b "$repo_branch" "$path"
    else
        echo "✓ $path exists"
    fi
done

# 3. Apply Source-side Patches
echo -e "\n${YELLOW}[3/4] Applying source-side fixes...${NC}"

# Vendor Lineage (Soong generator Sbox & clean_headers.sh fix)
if [ -d "vendor/lineage" ]; then
    echo "Checking vendor/lineage..."
    for p in "$SCRIPT_DIR/vendor_lineage/"*.patch; do
        [ -f "$p" ] || continue
        if git -C vendor/lineage apply --check "$p" 2>/dev/null; then
            git -C vendor/lineage am "$p"
            echo "  ✓ Applied $(basename "$p")"
        else
            echo "  (vendor/lineage patch already present or applied)"
        fi
    done
fi

# Hardware Lineage Compat (libgui_shim symbol update for A17)
if [ -d "hardware/lineage/compat" ]; then
    echo "Checking hardware/lineage/compat..."
    for p in "$SCRIPT_DIR/hardware_lineage_compat/"*.patch; do
        [ -f "$p" ] || continue
        if git -C hardware/lineage/compat apply --check "$p" 2>/dev/null; then
            git -C hardware/lineage/compat am "$p"
            echo "  ✓ Applied $(basename "$p")"
        else
            echo "  (hardware/lineage/compat patch already present or applied)"
        fi
    done
fi

# Device tree patches (if missing)
if [ -d "device/realme/RMX1971" ]; then
    echo "Checking device/realme/RMX1971..."
    for p in "$SCRIPT_DIR/device_realme_RMX1971/"*.patch; do
        [ -f "$p" ] || continue
        if git -C device/realme/RMX1971 apply --check "$p" 2>/dev/null; then
            git -C device/realme/RMX1971 am "$p"
            echo "  ✓ Applied $(basename "$p")"
        else
            echo "  (device tree patch already present or applied)"
        fi
    done
fi

# Vendor tree patches (if missing)
if [ -d "vendor/realme/RMX1971" ]; then
    echo "Checking vendor/realme/RMX1971..."
    for p in "$SCRIPT_DIR/vendor_realme_RMX1971/"*.patch; do
        [ -f "$p" ] || continue
        if git -C vendor/realme/RMX1971 apply --check "$p" 2>/dev/null; then
            git -C vendor/realme/RMX1971 am "$p"
            echo "  ✓ Applied $(basename "$p")"
        else
            echo "  (vendor tree patch already present or applied)"
        fi
    done
fi

# 4. Ready to build
echo -e "\n${GREEN}==================================================================${NC}"
echo -e "${GREEN}✓ Realme XT (RMX1971) Android 17 restoration completed!${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo "To build ROM:"
echo "  source build/envsetup.sh"
echo "  lunch custom_RMX1971-cp2a-userdebug"
echo "  m bacon -j\$(nproc --all)"

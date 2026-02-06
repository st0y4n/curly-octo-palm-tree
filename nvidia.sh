#!/bin/bash

# FAILS FASE: exit on error, undefined vars, or pipe failures
set -ouex pipefail

echo ">>> STARTING INDEPENDENT NVIDIA SETUP <<<"

# 1. Install RPM Fusion Repos
# We use standard DNF here.
dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# 2. Capture the Kernel Version (Robustly)
# We pick the latest installed kernel-core version to match headers against.
KERNEL_VERSION=$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -n 1)
echo ">>> Locking driver tools to Kernel: $KERNEL_VERSION"

# 3. Install Build Tools & Headers
# Note: We MUST keep gcc/make installed so the driver can build itself on the first boot.
dnf install -y \
    akmods \
    gcc \
    make \
    "kernel-devel-$KERNEL_VERSION" \
    kernel-headers \
    nvidia-kmod-common

# 4. Install the Driver (The "Nuclear" Option)
# --setopt=tsflags=noscripts prevents the 'Not to be used as root' crash.
echo ">>> Installing Akmod Nvidia (Scripts Disabled)..."
dnf install -y --setopt=tsflags=noscripts \
    akmod-nvidia \
    xorg-x11-drv-nvidia-cuda

# 5. Configure Kernel Arguments (Bootc Style)
# We write a config file to /usr/lib/bootc/kargs.d/ to blacklist nouveau.
echo ">>> Setting Kernel Arguments..."
mkdir -p /usr/lib/bootc/kargs.d
cat <<EOF > /usr/lib/bootc/kargs.d/10-nvidia.toml
rd.driver.blacklist=nouveau
modprobe.blacklist=nouveau
nvidia-drm.modeset=1
EOF

# 6. Enable the Service
# This service runs on boot to compile the driver.
systemctl enable akmods

# 7. Cleanup DNF Metadata
dnf clean all

echo ">>> NVIDIA SETUP COMPLETE <<<"

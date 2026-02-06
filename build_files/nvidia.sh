#!/bin/bash
set -ouex pipefail

echo ">>> STARTING NVIDIA SETUP <<<"

# 1. Install Repos
dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# 2. ROBUST KERNEL VERSION CHECK (The fix)
# We don't use 'rpm -q' because it might list multiple kernels.
# We look at exactly which kernel modules are present on the disk.
# This guarantees we install the headers for the kernel we are actually building against.
KERNEL_VERSION=$(ls /usr/lib/modules | sort -V | tail -n 1)
echo ">>> Detected Kernel: ${KERNEL_VERSION}"

# 3. Install Build Dependencies
# We include 'gcc' and 'make' so the driver can compile on first boot.
dnf install -y \
    akmods \
    gcc \
    make \
    "kernel-devel-${KERNEL_VERSION}" \
    kernel-headers \
    nvidia-kmod-common

# 4. Install the Driver (The "Nuclear" Fix)
# We install akmod-nvidia separately with --setopt=tsflags=noscripts.
# This prevents the '%post' script from running and failing the build.
echo ">>> Installing Akmod Nvidia (No Scripts)..."
dnf install -y --setopt=tsflags=noscripts akmod-nvidia

# 5. Install the Rest of the Stack
# Now that akmod-nvidia is safe, we install the CUDA drivers.
echo ">>> Installing CUDA Drivers..."
dnf install -y xorg-x11-drv-nvidia-cuda

# 6. Configure Kernel Arguments (Bootc Style)
# This hides the Nouveau driver so Nvidia can load.
mkdir -p /usr/lib/bootc/kargs.d
cat <<EOF > /usr/lib/bootc/kargs.d/10-nvidia.toml
rd.driver.blacklist=nouveau
modprobe.blacklist=nouveau
nvidia-drm.modeset=1
EOF

# 7. Enable the Build Service
# This ensures the driver compiles itself on the first boot.
systemctl enable akmods

# 8. Cleanup
dnf clean all

echo ">>> NVIDIA SETUP COMPLETE <<<"

#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux  

dnf5 install -y rpmdevtools akmods

dnf5 install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm


dnf5 install -y akmod-nvidia xorg-x11-drv-nvidia xorg-x11-drv-nvidia-cuda --exclude=nvidia-kmod-common

rpm-ostree kargs --append=rd.driver.blacklist=nouveau,nova_core --append=modprobe.blacklist=nouveau,nova_core


akmods --force --kernels $(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -n 1)

dracut -f --regenerate-all

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket

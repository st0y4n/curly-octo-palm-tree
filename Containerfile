# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image

FROM ghcr.io/ublue-os/kinoite-main:latest

## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:latest
# FROM ghcr.io/ublue-os/bluefin-nvidia:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:41
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh
    
RUN dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm


# ---------------------------------------------------------------------------
# STEP 1: Install Build Tools ONLY
# Do NOT install any nvidia packages here, or DNF will pull the driver too early.
# ---------------------------------------------------------------------------
RUN KERNEL_VERSION=$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}') && \
    dnf install -y \
    akmods \
    gcc \
    make \
    "kernel-devel-$KERNEL_VERSION" \
    kernel-headers \
    && dnf clean all

# ---------------------------------------------------------------------------
# STEP 2: The "Fake Binary" Hack + Install Drivers
# ---------------------------------------------------------------------------
RUN mv /usr/sbin/akmods /usr/sbin/akmods.real && \
    echo '#!/bin/sh' > /usr/sbin/akmods && \
    echo 'exit 0' >> /usr/sbin/akmods && \
    chmod +x /usr/sbin/akmods && \
    \
    # NOW install the actual Nvidia packages. 
    # The scriptlet will fire, hit our fake 'exit 0' script, and succeed.
    dnf install -y \
        akmod-nvidia \
        xorg-x11-drv-nvidia-cuda \
    && \
    \
    # Restore the real tool so it works on boot
    mv /usr/sbin/akmods.real /usr/sbin/akmods && \
    dnf clean all

# ---------------------------------------------------------------------------
# STEP 3: Enable the service
# ---------------------------------------------------------------------------
RUN systemctl enable akmods

RUN bootc container lint


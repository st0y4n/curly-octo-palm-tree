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


RUN KERNEL_VERSION=$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}') && \
    dnf install -y \
    akmod-nvidia \
    xorg-x11-drv-nvidia-cuda \
    "kernel-devel-$KERNEL_VERSION" \
    "kernel-headers" \
    && dnf clean all

RUN mv /usr/sbin/akmods /usr/sbin/akmods.real && \
    echo '#!/bin/sh' > /usr/sbin/akmods && \
    echo 'exit 0' >> /usr/sbin/akmods && \
    chmod +x /usr/sbin/akmods && \
    \
    # 3. Now install the driver
    #    The scriptlet will run our dummy 'akmods', return success, and finish installing.
    dnf install -y akmod-nvidia && \
    \
    # 4. Cleanup: Restore the REAL binary so it works on boot
    mv /usr/sbin/akmods.real /usr/sbin/akmods && \
    dnf clean all

RUN systemctl enable akmods

RUN bootc container lint


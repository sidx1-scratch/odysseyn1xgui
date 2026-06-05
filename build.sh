#!/bin/sh
# Made with <3 by raspberryenvoie
# odysseyn1x build script (a fork of asineth/checkn1x)
# Modified to use Fedora Workstation as base

# Exit if user isn't root
[ "$(id -u)" -ne 0 ] && {
    echo 'Please run as root'
    exit 1
}

# Change these variables to modify the version of checkra1n
CHECKRA1N_AMD64='https://assets.checkra.in/downloads/linux/cli/x86_64/dac9968939ea6e6bfbdedeb41d7e2579c4711dc2c5083f91dced66ca397dc51d/checkra1n'
CHECKRA1N_I686='https://assets.checkra.in/downloads/linux/cli/i486/77779d897bf06021824de50f08497a76878c6d9e35db7a9c82545506ceae217e/checkra1n'

GREEN="$(tput setaf 2)"
BLUE="$(tput setaf 6)"
NORMAL="$(tput sgr0)"
cat << EOF
${GREEN}############################################${NORMAL}
${GREEN}#                                          #${NORMAL}
${GREEN}#  ${BLUE}Welcome to the odysseyn1x build script  ${GREEN}#${NORMAL}
${GREEN}#                                          #${NORMAL}
${GREEN}############################################${NORMAL}

EOF
# Ask for the version and architecture if variables are empty
while [ -z "$VERSION" ]; do
    printf 'Version: '
    read -r VERSION
done
until [ "$ARCH" = 'amd64' ] || [ "$ARCH" = 'i686' ]; do
    echo '1 amd64'
    echo '2 i686'
    printf 'Which architecture? amd64 (default) or i686 '
    read -r input_arch
    [ "$input_arch" = 1 ] && ARCH='amd64'
    [ "$input_arch" = 2 ] && ARCH='i686'
    [ -z "$input_arch" ] && ARCH='amd64'
done

# Delete old build
{
    umount work/chroot/proc
    umount work/chroot/sys
    umount work/chroot/dev
} > /dev/null 2>&1
rm -rf work/

set -e -u -v
start_time="$(date -u +%s)"

# Install dependencies to build odysseyn1x
# Using Fedora dnf package manager
dnf update -y
dnf install -y wget rpm-build dnf-plugins-core grub2-pc-modules grub2-efi-x64-modules \
    squashfs-tools xorriso ca-certificates curl libusb-devel gcc make gzip xz \
    unzip glibc-devel

# Determine architecture-specific settings for Fedora
if [ "$ARCH" = 'amd64' ]; then
    REPO_ARCH='x86_64'
    FEDORA_RELEASE='stable'
else
    # Install dependencies to build odysseyn1x for i686
    dnf install -y glibc-devel.i686 libusb-devel.i686 gcc-c++.i686
    REPO_ARCH='i386'
    FEDORA_RELEASE='stable'
fi

# Configure the base system using Fedora
# Using dnf instead of debootstrap for Fedora-based systems
mkdir -p work/chroot work/iso/live work/iso/boot/grub

# Create minimal Fedora base with dnf
dnf install -y --installroot="$(pwd)/work/chroot" --releasever=latest \
    basesystem filesystem setup yum dnf

# Mount necessary filesystems
mount --bind /proc work/chroot/proc
mount --bind /sys work/chroot/sys
mount --bind /dev work/chroot/dev
cp /etc/resolv.conf work/chroot/etc

cat << EOF | chroot work/chroot /bin/bash
# Set dnf to be non-interactive
export DNFPLUGIN_ENABLED=1
export FEDORA_FRONTEND=noninteractive

# Install required packages from Fedora repositories
dnf install -y --setopt=tsflags=nodocs kernel-core kernel-modules live-boot \
    systemd systemd-libs usbmuxd openssh-clients openssh-keygen sshpass xz whiptail \
    firefox wget curl ca-certificates libusb

# Install minimal X11 and GTK for GUI support (optional, if needed)
# Uncomment if you want full GUI support:
# dnf install -y xorg-x11-server-Xvfb fluxbox

# Clean up to reduce size
dnf clean all
rm -rf /var/cache/dnf/*
EOF

# Change initramfs compression to xz
sed -i 's/COMPRESS=gzip/COMPRESS=xz/' work/chroot/etc/dracut.conf.d/* 2>/dev/null || true
chroot work/chroot dracut --hostonly --hostonly-cmdline -f

(
    cd work/chroot
    # Empty some directories to make the system smaller
    rm -f etc/mtab \
        etc/fstab \
        etc/ssh/ssh_host* \
        root/.wget-hsts \
        root/.bash_history
    rm -rf var/log/* \
        var/cache/* \
        var/backups/* \
        var/lib/dnf/* \
        usr/share/doc/* \
        usr/share/man/* \
        usr/share/info/* \
        usr/share/icons/* \
        usr/share/locale/* \
        usr/share/zoneinfo/* \
        usr/lib/modules/*
)

# Copy scripts
cp scripts/* work/chroot/usr/bin/

# Download resources for odysseyra1n
mkdir -p work/chroot/root/odysseyra1n/
(
    cd work/chroot/root/odysseyra1n/
    curl -sL -O https://github.com/coolstar/Odyssey-bootstrap/raw/master/bootstrap_1500.tar.gz \
        -O https://github.com/coolstar/Odyssey-bootstrap/raw/master/bootstrap_1600.tar.gz \
        -O https://github.com/coolstar/Odyssey-bootstrap/raw/master/bootstrap_1700.tar.gz \
        -O https://github.com/coolstar/Odyssey-bootstrap/raw/master/org.coolstar.sileo_2.3_iphoneos-arm.deb \
        -O https://github.com/coolstar/Odyssey-bootstrap/raw/master/org.swift.libswift_5.0-electra2_iphoneos-arm.deb
    # Change compression format to xz
    gzip -dv ./*.tar.gz
    xz -v9e -T0 ./*.tar
)

(
    cd work/chroot/root/
    # Download resources for Android Sandcastle
    curl -L -O 'https://assets.checkra.in/downloads/sandcastle/dff60656db1bdc6a250d3766813aa55c5e18510694bc64feaabff88876162f3f/android-sandcastle.zip'
    unzip android-sandcastle.zip
    rm -f android-sandcastle.zip
    (
        cd android-sandcastle/
        rm -f iproxy ./*.dylib load-linux.mac ./*.sh README.txt
    )

    # Download resources for Linux Sandcastle
    curl -L -O 'https://assets.checkra.in/downloads/sandcastle/0175ae56bcba314268d786d1239535bca245a7b126d62a767e12de48fd20f470/linux-sandcastle.zip'
    unzip linux-sandcastle.zip
    rm -f linux-sandcastle.zip
    (
        cd linux-sandcastle/
        rm -f load-linux.mac README.txt
    )
)

(
    cd work/chroot/usr/bin/
    curl -L -O 'https://raw.githubusercontent.com/corellium/projectsandcastle/master/loader/load-linux.c'
    # Build load-linux.c and download checkra1n for the corresponding architecture
    if [ "$ARCH" = 'amd64' ]; then
        gcc load-linux.c -o load-linux -lusb-1.0
        curl -L -o checkra1n "$CHECKRA1N_AMD64"
    else
        gcc -m32 load-linux.c -o load-linux -lusb-1.0
        curl -L -o checkra1n "$CHECKRA1N_I686"
    fi
    rm -f load-linux.c
    chmod +x load-linux checkra1n
)

# Configure linux-apple
(
    cd work/chroot/usr/bin
    # Build pongoterm.c for the corresponding architecture
    # load-linux.c does not work as there is no baked in initramfs
    curl -L -O https://github.com/konradybcio/pongoOS/raw/master/scripts/pongoterm.c
    if [ "$ARCH" = 'amd64' ]; then
        gcc -Wall -Wextra -Os -m64 pongoterm.c -DUSE_LIBUSB=1 -o pongoterm -lusb-1.0 -lpthread
    else
        gcc -Wall -Wextra -Os -m32 pongoterm.c -DUSE_LIBUSB=1 -o pongoterm -lusb-1.0 -lpthread
    fi
    rm -f pongoterm.c
)

# Download resources for linux-apple
(
    cd work/chroot/root
    mkdir linux-apple
    cd linux-apple
    # Download DeviceTree, 4K, 16K kernels and initramfs.
    curl -L -OOOOO \
        https://cdn.discordapp.com/attachments/672628720497852459/1023930400365625344/netboot_debug_initrd.img \
        https://cdn.discordapp.com/attachments/672628720497852459/1024873433567350794/dtbpack \
        https://cdn.discordapp.com/attachments/672628720497852459/1024873433982578718/Image.lzma-16k \
        https://cdn.discordapp.com/attachments/672628720497852459/1024873434334892063/Image.lzma-4k \
        https://cdn.discordapp.com/attachments/672628720497852459/1025036488414593085/Pongo.bin
)

# Download A8X/A9X resources
(
    cd work/chroot/root
    curl -L -O https://cdn.discordapp.com/attachments/672628720497852459/1025048286916251668/PongoConsolidated.bin
)

# Configure autologin
mkdir -p work/chroot/etc/systemd/system/getty@tty1.service.d
cat << EOF > work/chroot/etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin root %I
Type=idle
EOF

# Configure grub
cat << "EOF" > work/iso/boot/grub/grub.cfg
insmod all_video
echo ''
echo '  ___   __| |_   _ ___ ___  ___ _   _ _ __ / |_  __'
echo ' / _ \ / _` | | | / __/ __|/ _ \ | | | `_ \| \ \/ /'
echo '| (_) | (_| | |_| \__ \__ \  __/ |_| | | | | |>  < '
echo ' \___/ \__,_|\__, |___/___/\___|\__, |_| |_|_/_/\_\'
echo '             |___/              |___/              '
echo ''
echo '          Made with <3 by raspberryenvoie'
linux /boot/vmlinuz boot=live quiet
initrd /boot/initrd.img
boot
EOF

# Change hostname and configure .bashrc
echo 'odysseyn1x' > work/chroot/etc/hostname
echo "export ODYSSEYN1X_VERSION='$VERSION'" > work/chroot/root/.bashrc
echo '/usr/bin/odysseyn1x_menu' >> work/chroot/root/.bashrc

rm -f work/chroot/etc/resolv.conf

# Build the ISO
umount work/chroot/proc
umount work/chroot/sys
umount work/chroot/dev

# Get kernel and initramfs from Fedora chroot
if [ "$ARCH" = 'amd64' ]; then
    KERNEL_PATH=$(find work/chroot/boot -name 'vmlinuz-*' -type f | head -n1)
    INITRD_PATH=$(find work/chroot/boot -name 'initramfs-*' -type f | head -n1)
else
    KERNEL_PATH=$(find work/chroot/boot -name 'vmlinuz-*' -type f | head -n1)
    INITRD_PATH=$(find work/chroot/boot -name 'initramfs-*' -type f | head -n1)
fi

cp "$KERNEL_PATH" work/iso/boot/vmlinuz
cp "$INITRD_PATH" work/iso/boot/initrd.img

mksquashfs work/chroot work/iso/live/filesystem.squashfs -noappend -e boot -comp xz -Xbcj x86
grub-mkrescue -o "odysseyn1x-$VERSION-$ARCH.iso" work/iso \
    --compress=xz \
    --fonts='' \
    --locales='' \
    --themes=''

end_time="$(date -u +%s)"
elapsed_time="$((end_time - start_time))"

echo "Built odysseyn1x-$VERSION-$ARCH in $((elapsed_time / 60)) minutes and $((elapsed_time % 60)) seconds."

#!/usr/bin/env bash

set -e

if [[ ${USER} != "root" ]]; then
  echo "This script must be run with root"
  exit 1
fi

#declare variables
ORIGIN_DIR=$(pwd)
TMPDIR=${2:-$(mktemp -d)}
BUILD_DIR=${TMPDIR}/dist
DEST_DIR=${TMPDIR}/dest
INSTALL_ISO=${TMPDIR}/install.iso
INSTALL_TAR_GZ=${DEST_DIR}/install.tar.gz

echo "##[section] clean up"
rm -rf "${BUILD_DIR}"
rm -rf "${DEST_DIR}"

mkdir -p "${DEST_DIR}"
mkdir -p "${BUILD_DIR}"

#enterprise boot ISO
BOOT_ISO="/root/install8.iso"

#enterprise Docker kickstart file
KS_FILE="https://raw.githubusercontent.com/WhitewaterFoundry/sig-cloud-instance-build/master/docker/rhel-8.ks"

#go to our temporary directory
cd "$TMPDIR"

echo "##[section] make sure we are up to date"
dnf -y update

echo "##[section] get livemedia-creator dependencies"
dnf -y install libvirt lorax virt-install libvirt-daemon-config-network libvirt-daemon-kvm libvirt-daemon-driver-qemu bc

#get anaconda dependencies
#dnf -y install anaconda anaconda-tui

echo "##[section] restart libvirtd for good measure"
systemctl restart libvirtd || echo "Running without SystemD"

echo "##[section] download enterprise boot ISO"
if [[ ! -f ${INSTALL_ISO} ]]; then
  cp "${BOOT_ISO}" "${INSTALL_ISO}"
fi
echo "##[section] download enterprise Docker kickstart file"
curl $KS_FILE -o install.ks

rm -f "${INSTALL_TAR_GZ}"

echo "##[section] build intermediary rootfs tar"
processor_count=$(echo "$(grep -c "processor.*:" /proc/cpuinfo) - 1" | bc -l)
ram=$(free -m | sed -n "sA\(Mem: *\)\([0-9]*\)\(.*\)A\2 / 2Ap" | bc -l | cut -d'.' -f1)
livemedia-creator --make-tar --iso="${INSTALL_ISO}" --image-name=install.tar.gz --ks=install.ks --releasever "8" --vcpus ${processor_count} --ram=${ram} --compression gzip --tmp "${DEST_DIR}"
unset processor_count
unset ram

echo "##[section] open up the tar into our build directory"
tar -xf "${INSTALL_TAR_GZ}" -C "${BUILD_DIR}"

echo "##[section] copy some custom files into our build directory"
cp "${ORIGIN_DIR}"/linux_files/wsl.conf "${BUILD_DIR}"/etc/wsl.conf
mkdir "${BUILD_DIR}"/etc/fonts
cp "${ORIGIN_DIR}"/linux_files/local.conf "${BUILD_DIR}"/etc/fonts/local.conf
cp "${ORIGIN_DIR}"/linux_files/DB_CONFIG "${BUILD_DIR}"/var/lib/rpm/
cp "${ORIGIN_DIR}"/linux_files/00-wle.sh "${BUILD_DIR}"/etc/profile.d/
cp "${ORIGIN_DIR}"/linux_files/upgrade.sh "${BUILD_DIR}"/usr/local/bin/upgrade.sh
chmod +x "${BUILD_DIR}"/usr/local/bin/upgrade.sh
ln -s "${BUILD_DIR}"/usr/local/bin/upgrade.sh "${BUILD_DIR}"/usr/local/bin/update.sh

echo "##[section] re-build our tar image"
cd "${BUILD_DIR}"

#chmod 640 etc/shadow*
#chmod 640 etc/gshadow*
#chmod +r usr/bin/sudo
#chmod +r usr/bin/sudoreplay

mkdir -p "${ORIGIN_DIR}"/x64
tar --exclude='boot/*' --exclude=proc --exclude=dev --exclude=sys --exclude='var/cache/dnf/*' --numeric-owner -czf "${ORIGIN_DIR}"/x64/install.tar.gz ./*

echo "##[section] go home"
cd "${ORIGIN_DIR}"


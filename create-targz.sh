#!/usr/bin/env bash

set -e
set -x

#declare variables
ORIGIN_DIR=$(pwd)
TMPDIR=${2:-$(mktemp -d)}
BUILD_DIR=${TMPDIR}/dist
mkdir -p "${BUILD_DIR}"
DEST_DIR=${TMPDIR}/dest
INSTALL_ISO=${TMPDIR}/install.iso
INSTALL_TAR=${DEST_DIR}/install.tar
INSTALL_TAR_GZ=${INSTALL_TAR}.gz

#enterprise boot ISO
BOOT_ISO="/root/install8.iso"

#enterprise Docker kickstart file
KS_FILE="https://raw.githubusercontent.com/WhitewaterFoundry/sig-cloud-instance-build/master/docker/rhel-8.ks"

#go to our temporary directory
cd "$TMPDIR"

echo "##[section] make sure we are up to date"
sudo yum -y update

echo "##[section] get livemedia-creator dependencies"
sudo yum -y install libvirt lorax virt-install libvirt-daemon-config-network libvirt-daemon-kvm libvirt-daemon-driver-qemu

#get anaconda dependencies
#sudo yum -y install anaconda anaconda-tui

echo "##[section] restart libvirtd for good measure"
sudo systemctl restart libvirtd

echo "##[section] download enterprise boot ISO"
if [[ ! -f ${INSTALL_ISO} ]]; then
  sudo cp "${BOOT_ISO}" "${INSTALL_ISO}"
fi
echo "##[section] download enterprise Docker kickstart file"
curl $KS_FILE -o install.ks

sudo rm -f "${INSTALL_TAR_GZ}"
sudo rm -f "${INSTALL_TAR}"

echo "##[section] build intermediary rootfs tar"
sudo rm -rf "${DEST_DIR}"
mkdir -p "${DEST_DIR}"
sudo livemedia-creator --make-tar --iso="${INSTALL_ISO}" --image-name=install.tar.gz --ks=install.ks --releasever "8" --vcpus 4 --ram=4096 --compression gzip --tmp "${DEST_DIR}"

echo "##[section] open up the tar into our build directory"
sudo gunzip "${INSTALL_TAR_GZ}"

echo "##[section] copy some custom files into our build directory"
mkdir -p temp/etc/fonts
sudo cp "${ORIGIN_DIR}"/linux_files/wsl.conf temp/etc/wsl.conf
sudo cp "${ORIGIN_DIR}"/linux_files/local.conf temp/etc/fonts/local.conf
mkdir -p temp/var/lib/rpm
sudo cp "${ORIGIN_DIR}"/linux_files/DB_CONFIG temp/var/lib/rpm/
mkdir -p temp/etc/profile.d
sudo cp "${ORIGIN_DIR}"/linux_files/00-wle.sh temp/etc/profile.d/
mkdir -p temp/usr/local/bin
sudo cp "${ORIGIN_DIR}"/linux_files/upgrade.sh temp/usr/local/bin/upgrade.sh
sudo chmod +x temp/usr/local/bin/upgrade.sh
sudo tar -rvf "${INSTALL_TAR}" -C temp .

echo "##[section] re-build our tar image"
tar -xvf "${INSTALL_TAR}" -C "${BUILD_DIR}"

cd "${BUILD_DIR}"

sudo chmod 640 etc/shadow*
sudo chmod 640 etc/gshadow*
sudo chmod +r usr/bin/sudo
sudo chmod +r usr/bin/sudoreplay

mkdir -p "${ORIGIN_DIR}"/x64
sudo tar --exclude='boot/*' --exclude=proc --exclude=dev --exclude=sys --exclude='var/cache/dnf/*' --numeric-owner -czf "${ORIGIN_DIR}"/x64/install.tar.gz ./*

#sudo gzip "${INSTALL_TAR}"
#sudo mv "${INSTALL_TAR_GZ}" "${ORIGIN_DIR}"/x64/install.tar.gz

echo "##[section] go home"
cd "${ORIGIN_DIR}"

echo "##[section] clean up"
sudo rm -rf "${BUILD_DIR}"
#sudo rm -rf "${TMPDIR}"
#sudo rm -f "${INSTALL_ISO}"
#sudo rm -f "${INSTALL_TAR_GZ}"
sudo rm -rf "${DEST_DIR}"

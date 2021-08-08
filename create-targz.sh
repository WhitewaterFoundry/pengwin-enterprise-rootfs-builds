#!/usr/bin/env bash

set -e

#declare variables
ORIGINDIR=$(pwd)
TMPDIR=$(mktemp -d)
BUILDDIR=$(mktemp -d)
INSTALLISO=${ORIGINDIR}/install.iso
INSTALL_TAR=/tmp/install.tar
INSTALL_TAR_GZ=${INSTALL_TAR}.gz

#enterprise boot ISO
BOOTISO="/root/install8.iso"

#enterprise Docker kickstart file
KSFILE="https://raw.githubusercontent.com/WhitewaterFoundry/sig-cloud-instance-build/master/docker/rhel-8.ks"

#go to our temporary directory
cd "$TMPDIR"

echo "##[section] make sure we are up to date"
sudo yum -y update

echo "##[section] get livemedia-creator dependencies"
sudo yum -y install libvirt lorax virt-install libvirt-daemon-config-network libvirt-daemon-kvm libvirt-daemon-driver-qemu

#get anaconda dependencies
#sudo yum -y install anaconda anaconda-tui

echo "##[section] restart libvirtd for good measure"
#sudo systemctl restart libvirtd

echo "##[section] download enterprise boot ISO"
if [[ ! -f ${INSTALLISO} ]] ; then
  sudo cp "${BOOTISO}" "${INSTALLISO}"
fi
echo "##[section] download enterprise Docker kickstart file"
curl $KSFILE -o install.ks

sudo rm -f "${INSTALL_TAR_GZ}"

echo "##[section] build intermediary rootfs tar"
sudo livemedia-creator --make-tar --iso="${INSTALLISO}" --image-name=install.tar.gz --ks=install.ks --releasever "8" --vcpus 2 --compression gzip --tmp /tmp

echo "##[section] open up the tar into our build directory"
sudo gunzip "${INSTALL_TAR_GZ}"
#tar -xvzf "${INSTALL_TAR_GZ}" -C "${BUILDDIR}"

echo "##[section] copy some custom files into our build directory"
mkdir -p temp/etc/fonts
sudo cp "${ORIGINDIR}"/linux_files/wsl.conf temp/etc/wsl.conf
sudo cp "${ORIGINDIR}"/linux_files/local.conf temp/etc/fonts/local.conf
mkdir -p temp/var/lib/rpm
sudo cp "${ORIGINDIR}"/linux_files/DB_CONFIG temp/var/lib/rpm/
mkdir -p temp/etc/profile.d
sudo cp "${ORIGINDIR}"/linux_files/00-wle.sh temp/etc/profile.d/
mkdir -p temp/usr/local/bin
sudo cp "${ORIGINDIR}"/linux_files/upgrade.sh temp/usr/local/bin/upgrade.sh
sudo chmod +x temp/usr/local/bin/upgrade.sh

echo "##[section] re-build our tar image"
#cd "${BUILDDIR}"
mkdir -p "${ORIGINDIR}"/x64
#tar --ignore-failed-read -czvf "${ORIGINDIR}"/x64/install.tar.gz *
sudo tar -rvf "${INSTALL_TAR}" -C temp .
sudo gzip "${INSTALL_TAR}"
sudo mv "${INSTALL_TAR_GZ}" "${ORIGINDIR}"/x64/install.tar.gz

echo "##[section] go home"
cd "${ORIGINDIR}"

echo "##[section] clean up"
sudo rm -rf "${BUILDDIR}"
sudo rm -rf "${TMPDIR}"
sudo rm -f "${INSTALLISO}"
sudo rm -f "${INSTALL_TAR_GZ}"

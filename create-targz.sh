#!/usr/bin/env bash

set -e
set -x

#declare variables
ORIGINDIR=$(pwd)
TMPDIR=$(mktemp -d -p "${ORIGINDIR}")
BUILDDIR=$(mktemp -d -p "${ORIGINDIR}")
INSTALLISO=${ORIGINDIR}/install.iso

#enterprise boot ISO
BOOTISO="http://ftp1.scientificlinux.org/linux/scientific/7x/x86_64/os/images/boot.iso"

#enterprise Docker kickstart file
KSFILE="https://raw.githubusercontent.com/WhitewaterFoundry/sig-cloud-instance-build/master/docker/sl-7.ks"

#go to our temporary directory
cd "$TMPDIR"

#make sure we are up to date
sudo yum -y update

#get livemedia-creator dependencies
sudo yum -y install libvirt lorax virt-install libvirt-daemon-config-network libvirt-daemon-kvm libvirt-daemon-driver-qemu

#get anaconda dependencies
sudo yum -y install anaconda anaconda-tui

#restart libvirtd for good measure
sudo systemctl restart libvirtd

#download enterprise boot ISO
if [[ ! -f ${INSTALLISO} ]] ; then
  sudo curl $BOOTISO -o "${INSTALLISO}"
fi
#download enterprise Docker kickstart file
curl $KSFILE -o install.ks

rm -f /var/tmp/install.tar.xz

#build intermediary rootfs tar
sudo livemedia-creator --make-tar --iso="${INSTALLISO}" --image-name=install.tar.xz --ks=install.ks --releasever "7" --no-virt

#open up the tar into our build directory
tar -xvf /var/tmp/install.tar.xz -C "${BUILDDIR}"

#copy some custom files into our build directory
sudo cp "${ORIGINDIR}"/linux_files/wsl.conf "${BUILDDIR}"/etc/wsl.conf
sudo mkdir "${BUILDDIR}"/etc/fonts
sudo cp "${ORIGINDIR}"/linux_files/local.conf "${BUILDDIR}"/etc/fonts/local.conf
sudo cp "${ORIGINDIR}"/linux_files/DB_CONFIG "${BUILDDIR}"/var/lib/rpm/
sudo cp "${ORIGINDIR}"/linux_files/00-wle.sh "${BUILDDIR}"/etc/profile.d/
sudo cp "${ORIGINDIR}"/linux_files/upgrade.sh "${BUILDDIR}"/usr/local/bin/upgrade.sh
sudo chmod +x "${BUILDDIR}"/usr/local/bin/upgrade.sh

#re-build our tar image
cd "${BUILDDIR}"
mkdir -p "${ORIGINDIR}"/x64
tar --ignore-failed-read -czvf "${ORIGINDIR}"/x64/install.tar.gz *

#go home
cd "${ORIGINDIR}"

#clean up
sudo rm -r "${BUILDDIR}"
sudo rm -r "$TMPDIR"
sudo rm "${INSTALLISO}"
sudo rm /var/tmp/install.tar.xz

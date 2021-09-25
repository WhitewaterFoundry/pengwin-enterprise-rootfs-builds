#!/bin/bash

set -e

if [[ ${USER} != "root" ]]; then
  echo "This script must be run with root"
  exit 1
fi

#declare variables
origin_dir=$(pwd)
tmp_dir=${2:-$(mktemp -d)}
build_dir=${tmp_dir}/dist
dest_dir=${tmp_dir}/dest
install_iso=${tmp_dir}/install.iso
install_tar_gz=${dest_dir}/install.tar.gz

echo "##[section] clean up"
rm -rf "${build_dir}"
rm -rf "${dest_dir}"

mkdir -p "${dest_dir}"
mkdir -p "${build_dir}"

#enterprise boot ISO
boot_iso="https://download.rockylinux.org/pub/rocky/8/isos/x86_64/Rocky-8.4-x86_64-dvd1.iso"

#enterprise Docker kickstart file
ks_file="https://raw.githubusercontent.com/WhitewaterFoundry/sig-cloud-instance-build/master/docker/rockylinux-8.ks"

#go to our temporary directory
cd "$tmp_dir"

echo "##[section] make sure we are up to date"
yum -y update

echo "##[section] get livemedia-creator dependencies"
yum -y install libvirt lorax virt-install libvirt-daemon-config-network libvirt-daemon-kvm libvirt-daemon-driver-qemu

#get anaconda dependencies
#yum -y install anaconda anaconda-tui

echo "##[section] restart libvirtd for good measure"
systemctl restart libvirtd

echo "##[section] download enterprise boot ISO"
if [[ ! -f ${install_iso} ]]; then
  curl $boot_iso -o "${install_iso}"
fi
echo "##[section] download enterprise Docker kickstart file"
curl $ks_file -o install.ks

rm -f "${install_tar_gz}"

echo "##[section] build intermediary rootfs tar"
livemedia-creator --make-tar --iso="${install_iso}" --image-name=install.tar.gz --ks=install.ks --releasever "8" --vcpus 4 --ram=4096 --compression gzip --tmp "${dest_dir}"

echo "##[section] open up the tar into our build directory"
tar -xvf "${install_tar_gz}" -C "${build_dir}"

echo "##[section] copy some custom files into our build directory"
cp "${origin_dir}"/linux_files/wsl.conf "${build_dir}"/etc/wsl.conf
mkdir "${build_dir}"/etc/fonts
cp "${origin_dir}"/linux_files/local.conf "${build_dir}"/etc/fonts/local.conf
cp "${origin_dir}"/linux_files/DB_CONFIG "${build_dir}"/var/lib/rpm/
cp "${origin_dir}"/linux_files/00-wle.sh "${build_dir}"/etc/profile.d/
cp "${origin_dir}"/linux_files/upgrade.sh "${build_dir}"/usr/local/bin/upgrade.sh
chmod +x "${build_dir}"/usr/local/bin/upgrade.sh
ln -s /usr/local/bin/upgrade.sh "${build_dir}"/usr/local/bin/update.sh

echo "##[section] re-build our tar image"
cd "${build_dir}"
mkdir -p "${origin_dir}"/x64
tar --exclude='boot/*' --exclude=proc --exclude=dev --exclude=sys --exclude='var/cache/dnf/*' --numeric-owner -czf "${origin_dir}"/x64/install.tar.gz ./*

echo "##[section] go home"
cd "${origin_dir}"


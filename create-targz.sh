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
install_iso=${tmp_dir}/install-rockylinux8.iso
install_tar_gz=${dest_dir}/install.tar.gz

echo "##[section] clean up"
rm -rf "${build_dir}"
rm -rf "${dest_dir}"

mkdir -p "${dest_dir}"
mkdir -p "${build_dir}"

#enterprise boot ISO
boot_iso="https://download.rockylinux.org/pub/rocky/8/isos/x86_64/Rocky-8.6-x86_64-dvd1.iso"

#enterprise Docker kickstart file
ks_file="https://raw.githubusercontent.com/WhitewaterFoundry/sig-cloud-instance-build/master/docker/rockylinux-8.ks"

#go to our temporary directory
cd "$tmp_dir"

echo "##[section] make sure we are up-to-date"
dnf -y update

echo "##[section] get livemedia-creator dependencies"
dnf -y install libvirt lorax virt-install libvirt-daemon-config-network libvirt-daemon-kvm libvirt-daemon-driver-qemu bc

#get anaconda dependencies
#dnf -y install anaconda anaconda-tui

echo "##[section] restart libvirtd for good measure"
systemctl restart libvirtd || echo "Running without SystemD"

echo "##[section] download enterprise boot ISO"
if [[ ! -f ${install_iso} ]]; then
  curl -L -f "${boot_iso}" -o "${install_iso}"
fi
echo "##[section] download enterprise Docker kickstart file"
curl -L -f $ks_file -o install.ks

rm -f "${install_tar_gz}"

echo "##[section] build intermediary rootfs tar"
processor_count=$(grep -c "processor.*:" /proc/cpuinfo)
ram=$(free -m | sed -n "sA\(Mem: *\)\([0-9]*\)\(.*\)A\2 / 2Ap" | bc -l | cut -d'.' -f1)
livemedia-creator --make-tar --iso="${install_iso}" --image-name=install.tar.gz --ks=install.ks --releasever "8" --vcpus "${processor_count}" --ram=${ram} --compression gzip --tmp "${dest_dir}"
unset processor_count
unset ram

echo "##[section] open up the tar into our build directory"
tar -xf "${install_tar_gz}" -C "${build_dir}"

echo "##[section] copy some custom files into our build directory"
cp "${origin_dir}"/linux_files/wsl.conf "${build_dir}"/etc/wsl.conf
mkdir "${build_dir}"/etc/fonts
cp "${origin_dir}"/linux_files/local.conf "${build_dir}"/etc/fonts/local.conf
cp "${origin_dir}"/linux_files/DB_CONFIG "${build_dir}"/var/lib/rpm/
cp "${origin_dir}"/linux_files/00-wle.sh "${build_dir}"/etc/profile.d/
cp "${origin_dir}"/linux_files/upgrade.sh "${build_dir}"/usr/local/bin/upgrade.sh
chmod +x "${build_dir}"/usr/local/bin/upgrade.sh
ln -s /usr/local/bin/upgrade.sh "${build_dir}"/usr/local/bin/update.sh

cp "${origin_dir}"/linux_files/start-systemd.sudoers "${build_dir}"/etc/sudoers.d/start-systemd
cp "${origin_dir}"/linux_files/start-systemd.sh "${build_dir}"/usr/local/bin/start-systemd
chmod +x "${tmp_dir}"/dist/usr/local/bin/start-systemd

cp "${origin_dir}"/linux_files/wsl2-xwayland.service "${build_dir}"/etc/systemd/system/wsl2-xwayland.service
cp "${origin_dir}"/linux_files/wsl2-xwayland.socket "${build_dir}"/etc/systemd/system/wsl2-xwayland.socket
#mkdir -p "${build_dir}"/etc/systemd/system/sockets.target.wants
#ln -sf ../wsl2-xwayland.socket "${build_dir}"/etc/systemd/system/sockets.target.wants/

cp "${origin_dir}"/linux_files/systemctl3.py "${build_dir}"/usr/local/bin/wslsystemctl
chmod +x "${build_dir}"/usr/local/bin/wslsystemctl

echo "##[section] re-build our tar image"
cd "${build_dir}"
mkdir -p "${origin_dir}"/x64
tar --exclude='boot/*' --exclude=proc --exclude=dev --exclude=sys --exclude='var/cache/dnf/*' --numeric-owner -czf "${origin_dir}"/x64/install.tar.gz ./*

echo "##[section] go home"
cd "${origin_dir}"


#!/bin/bash
script_dir=$(dirname ${BASH_SOURCE[0]})
set -x
set -e

target=$1
SRCDIR=$2
ARCH=$3

fss="proc dev sys"
echo $QEMU_EXE

multistrap_conf=${SRCDIR}/multistrap.config
multistrap_opt=

if [ -n "$PYNQ_UBUNTU_REPO" ]; then
  tmpfile=$(mktemp)
  export PYNQ_UBUNTU_REPO=$(echo ${PYNQ_UBUNTU_REPO} | sed 's\jammy\jammy/$(ARCH)\')
  sed -e "s;source=.*;source=${PYNQ_UBUNTU_REPO};" $multistrap_conf > $tmpfile
  mkdir -p $target/etc/apt/apt.conf.d/
  echo 'Acquire::AllowInsecureRepositories "1";' > $target/etc/apt/apt.conf.d/allowinsecure
  multistrap_conf=$tmpfile
  multistrap_opt=--no-auth
  trap "rm -f $tmpfile" EXIT
fi

# Perform the basic bootstrapping of the image
$dry_run sudo -E multistrap -f $multistrap_conf -d $target $multistrap_opt

# Make sure the that the root is still writable by us
sudo chroot / chmod a+w $target

cat - > $target/postinst1.sh <<EOT
set -x
export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C
rm -f /var/run/reboot-required
dpkg --configure -a
exit 0
EOT
cat - > $target/postinst2.sh <<EOT
export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C
rm -f /var/run/reboot-required
rm -f /var/run/firefox-restart-required
dpkg --configure -a
apt-get clean

rm -f /boot/*

# Create the STAR User
adduser --home /home/star star --disabled-password --gecos "STAR Robot User,,,,"

echo -e "star\\nstar" | passwd star
echo -e "star\\nstar" | passwd root

adduser star adm
adduser star sudo

# Configure locales to only use en_US.UTF-8
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

# Remove unnecessary locale files (saves ~50-100MB)
find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en' ! -name 'en_US' -type d -exec rm -rf {} + 2>/dev/null || true
find /usr/share/i18n/locales -mindepth 1 -maxdepth 1 ! -name 'en_US' ! -name 'en_GB' ! -name 'POSIX' -type f -delete 2>/dev/null || true

fake-hwclock save

# Disable wpa_supplicant service so ifup works correctly
systemctl mask wpa_supplicant

# Disable hibernation to keep interfaces alive
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Disable UA Client
systemctl mask ua-auto-attach.service

# Disable default graphical environment
systemctl set-default multi-user

# Ensure /usr/local/bin is a directory
mkdir -p /usr/local/bin
EOT

if [ -n "$PYNQ_UBUNTU_REPO" ]; then
  cat - >> $target/postinst2.sh <<EOT
echo "deb http://ports.ubuntu.com/ubuntu-ports jammy main universe" > /etc/apt/sources.list.d/multistrap-jammy.list
echo "deb-src http://ports.ubuntu.com/ubuntu-ports jammy main universe" >> /etc/apt/sources.list.d/multistrap-jammy.list
EOT
fi

cat - >> $target/postinst2.sh <<EOT
exit 0
EOT


# Copy over what we need to complete the installation
$dry_run sudo cp ${QEMU_EXE} $target/usr/bin

# Finish the base install
# Pass through special files so that the chroot works properly
for fs in $fss
do
  $dry_run sudo mount -o bind /$fs $target/$fs
done

$dry_run sudo -E chroot $target bash postinst1.sh

function unmount_special() {

# Unmount special files
for fs in $fss
do
  $dry_run sudo umount -l $target/$fs
done
if [ -e "$tmpfile" ]; then
  rm -f $tmpfile
fi
}

trap unmount_special EXIT

$dry_run sudo -E chroot $target bash postinst2.sh

$dry_run rm -f $target/postinst*.sh

# Perform configuration
# Apply patches to the base configuration

for f in $(cd ${SRCDIR}/patch && find -name "*.diff")
do
  # Forgot about patch as well
  $dry_run sudo chroot / patch $target/${f%.diff} < ${SRCDIR}/patch/$f
done

$script_dir/kill_chroot_processes.sh $target

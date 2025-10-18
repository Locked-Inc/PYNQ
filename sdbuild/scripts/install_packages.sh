#!/bin/bash

set -e
set -x

target=$1
shift

fss="proc run dev"


for fs in $fss
do
  $dry_run sudo mount -o bind /$fs $target/$fs
done
mkdir -p $target/ccache
sudo mount -o bind $CCACHEDIR $target/ccache

# Mount pip cache if configured
if [ -n "$PIP_CACHE_DIR" ] && [ -d "$PIP_CACHE_DIR" ]; then
  mkdir -p $target/pip-cache
  sudo mount -o bind $PIP_CACHE_DIR $target/pip-cache
  export PIP_CACHE_DIR=/pip-cache
fi

# Mount git cache if configured
if [ -n "$GIT_CACHE_DIR" ] && [ -d "$GIT_CACHE_DIR" ]; then
  mkdir -p $target/git-cache
  sudo mount -o bind $GIT_CACHE_DIR $target/git-cache
  export GIT_CACHE_DIR=/git-cache
fi

function unmount_special() {

# Unmount special files
for fs in $fss
do
  $dry_run sudo umount -l $target/$fs
done
sudo umount -l $target/ccache
rmdir $target/ccache || true

# Unmount pip cache if it was mounted
if mountpoint -q $target/pip-cache 2>/dev/null; then
  sudo umount -l $target/pip-cache
  rmdir $target/pip-cache || true
fi

# Unmount git cache if it was mounted
if mountpoint -q $target/git-cache 2>/dev/null; then
  sudo umount -l $target/git-cache
  rmdir $target/git-cache || true
fi
}

trap unmount_special EXIT

export CFLAGS="${IMAGE_CFLAGS}"
export CPPFLAGS="$CFLAGS"
export PATH="/usr/lib/ccache:$PATH"
export CCACHE_DIR=/ccache
export CCACHE_MAXSIZE=15G
export CCACHE_SLOPPINESS=file_macro,time_macros
export CC=/usr/lib/ccache/gcc
export CXX=/usr/lib/ccache/g++


# Hardening of resolv.conf for 20.04 images over QEMU 5.2.0
hostresolvfile=/etc/resolv.conf
targetresolvfile=$target/etc/resolv.conf
if [[ -L "$targetresolvfile" ]]; then
    sudo mv $targetresolvfile ${targetresolvfile}.link
    sudo cp -L $hostresolvfile $targetresolvfile
fi


for p in $@ 
do
  if [ -n "$PACKAGE_PATH" -a -e $PACKAGE_PATH/$p ]; then
    f=$PACKAGE_PATH/$p
  else
    f=$ROOTDIR/packages/$p
  fi
  if [ -e $f/pre.sh ]; then
    $dry_run $f/pre.sh $target
  fi
  if [ -e $f/qemu.sh ]; then
    $dry_run cp $f/qemu.sh $target
    $dry_run sudo -E chroot $target bash qemu.sh
    $dry_run rm $target/qemu.sh
  fi
  if [ -e $f/post.sh ]; then
    $dry_run $f/post.sh $target
  fi
done


# Target resolv.conf back to linkfile
if [[ ! -L "$targetresolvfile" ]]; then
    sudo rm $targetresolvfile
    sudo mv ${targetresolvfile}.link $targetresolvfile
fi

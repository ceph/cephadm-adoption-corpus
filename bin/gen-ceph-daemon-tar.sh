#!/bin/bash -ex

#
# Generates a tarball for use with
# the standalone `ceph-daemon` tests.
#

DIRS=(
   "/etc/ceph"
   "/var/lib/ceph"
   "/var/log/ceph"
)

SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})

TMPDIR=$(mktemp -d ${SCRIPT_NAME%.*}.XXX)
trap "rm -rf $TMPDIR" EXIT

TARBALL="$1"
if [ -z "$TARBALL" ]; then
    echo "tarball not specified" 1>&2
    exit 1
fi

# `systemctl stop` all services
systemctl list-units | grep ceph
systemctl stop ceph.target

# Copy the required dirs
for dir in "${DIRS[@]}"; do
    cp -a --parents --sparse=always $dir $TMPDIR
done

# Convert block dev(s) into a sparse file
SYMLINKS=$(find $TMPDIR -type l)
for symlink in $SYMLINKS; do
    file -L $symlink |  grep "block special" || exit 1
    dd if=$symlink of=$symlink.dev conv=sparse
    rm -f $symlink && ln -s $(basename $symlink.dev) $symlink
done

# Output the tarball
tar czvSpf $TARBALL -C $TMPDIR .

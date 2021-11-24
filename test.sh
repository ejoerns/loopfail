#!/bin/bash


set -e

echo "Setting up for $1 test runs"

TMPDIR=$(mktemp -d)

echo "TMPDIR is $TMPDIR"

# create target device
dd if=/dev/zero of=$TMPDIR/target-dev bs=1M count=50
mkfs.ext4 -F -I 256 $TMPDIR/target-dev > /dev/null
# create test image
dd if=/dev/zero of=$TMPDIR/test-image bs=1M count=50
mkfs.ext4 -F -I 256 $TMPDIR/test-image > /dev/null

# crate mount mounts
mkdir $TMPDIR/mount

# create additional loop devices to get sufficient overhead
for i in a b c d e f g h i; do
	dd if=/dev/zero of=$TMPDIR/target-dev-$i bs=1M count=50
	mkfs.ext4 -F -I 256 $TMPDIR/target-dev-$i > /dev/null
	mkdir $TMPDIR/mount-$i
	mount -t ext4 $TMPDIR/target-dev-$i $TMPDIR/mount-$i
done

for run in $(seq 1 $1); do

echo "Run $run..."

# mimic slot status read
flock $TMPDIR/target-dev mount -t ext4 $TMPDIR/target-dev $TMPDIR/mount
touch $TMPDIR/mount/status.file || true
umount $TMPDIR/target-dev

# echo if loop associated
echo "TP@0: $(losetup -j $TMPDIR/target-dev)"

# copy content of image
dd if=$TMPDIR/test-image of=$TMPDIR/target-dev bs=1M conv=fsync

# echo if loop associated
echo "TP@1: $(losetup -j $TMPDIR/target-dev)"

if [ "x$2" == "xnocache" ]; then
	#echo "Drop caches.."
	#time echo 1 > /proc/sys/vm/drop_caches
	echo "sync.."
	sync $TMPDIR/target-dev
else
	sleep 0.3
fi

# mount again for writing status file (manually with losetup)
LOOPDEV=$(losetup --find -L --show $TMPDIR/target-dev)
echo "mounting $LOOPDEV"
mount -t ext4 $LOOPDEV $TMPDIR/mount
echo "Status file changed: $DATE" > $TMPDIR/mount/status.file
umount $TMPDIR/target-dev

echo "done."

done

for i in a b c d e f g h i; do
	umount $TMPDIR/mount-$i
done

#m -rf $TMPDIR

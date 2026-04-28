#!/bin/busybox sh
# tokimo-sandbox initrd init
# Runs inside a minimal Linux VM (macOS Virtualization.framework / Windows HCS).
# Mounts the shared rootfs, executes a b64-encoded command from the kernel cmdline,
# writes results to the shared filesystem, then powers off.

set -e

# ---------------------------------------------------------------------------
# 1. Mount essential pseudo-filesystems
# ---------------------------------------------------------------------------
/bin/busybox mount -t proc proc /proc
/bin/busybox mount -t sysfs sys /sys
/bin/busybox mount -t devtmpfs dev /dev

# ---------------------------------------------------------------------------
# 2. Parse kernel cmdline for run=<base64>
# ---------------------------------------------------------------------------
CMD_B64=""
for arg in $(/bin/busybox cat /proc/cmdline); do
    case "$arg" in
        run=*) CMD_B64="${arg#run=}" ;;
    esac
done

if [ -z "$CMD_B64" ]; then
    echo "tokimo-init: no run= parameter in kernel cmdline"
    /bin/busybox poweroff -f
fi

# ---------------------------------------------------------------------------
# 3. Mount shared rootfs (virtiofs on macOS, 9p on Windows HCS)
# ---------------------------------------------------------------------------
/bin/busybox mkdir -p /mnt/work

if /bin/busybox mount -t virtiofs work /mnt/work 2>/dev/null; then
    echo "tokimo-init: mounted virtiofs"
elif /bin/busybox mount -t 9p -o trans=virtio,version=9p2000.L,msize=262144 work /mnt/work 2>/dev/null; then
    echo "tokimo-init: mounted 9p"
else
    echo "tokimo-init: failed to mount shared filesystem"
    /bin/busybox poweroff -f
fi

# ---------------------------------------------------------------------------
# 4. Check for rootfs inside shared dir
# ---------------------------------------------------------------------------
ROOTFS="/mnt/work"

# ---------------------------------------------------------------------------
# 5. Decode and run command
# ---------------------------------------------------------------------------
CMD=$(echo "$CMD_B64" | /bin/busybox base64 -d 2>/dev/null || echo "$CMD_B64")

echo "tokimo-init: running: $CMD"

/bin/busybox chroot "$ROOTFS" /bin/busybox sh -c "
    exec /bin/bash -c \"\$1\" </dev/null
" _ "$CMD" > "$ROOTFS/.vz_stdout" 2>"$ROOTFS/.vz_stderr"

echo $? > "$ROOTFS/.vz_exit_code"

# ---------------------------------------------------------------------------
# 6. Clean shutdown
# ---------------------------------------------------------------------------
/bin/busybox sync
echo "tokimo-init: done (exit=$(cat $ROOTFS/.vz_exit_code))"
/bin/busybox poweroff -f

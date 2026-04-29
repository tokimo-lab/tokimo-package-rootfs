#!/bin/busybox sh
# tokimo-sandbox initrd init (PID 1)
#
# Boot model:
#   * macOS VZ:  workspace_dir is mounted as `work` via virtio-fs and
#                also serves as the rootfs (chroot target). Single share.
#   * Windows HCS: TWO Plan9-over-vsock shares:
#       - rootshare (port from tokimo.rootshare_port=) → Debian rootfs
#       - work      (port from tokimo.work_port=)      → workspace
#     The guest mounts rootshare at /newroot, work at /newroot/mnt/work,
#     bind-mounts /proc /sys /dev /run, then switch_root and exec.
#
# Output goes to /mnt/work/.vz_{stdout,stderr,exit_code} (relative to the
# rootfs after switch_root). The host reads them after the VM powers off.

set -e

/bin/busybox mount -t proc proc /proc 2>/dev/null || true
/bin/busybox mount -t sysfs sys /sys 2>/dev/null || true
/bin/busybox mount -t devtmpfs dev /dev 2>/dev/null || true

CMDLINE=$(/bin/busybox cat /proc/cmdline 2>/dev/null || echo)
echo "tokimo-init: cmdline=$CMDLINE" >/dev/kmsg 2>/dev/null || true

# Parse kernel cmdline.
CMD_B64=""
ROOTSHARE_PORT=""
WORK_PORT=""
for arg in $CMDLINE; do
    case "$arg" in
        run=*)                       CMD_B64="${arg#run=}" ;;
        tokimo.rootshare_port=*)     ROOTSHARE_PORT="${arg#tokimo.rootshare_port=}" ;;
        tokimo.work_port=*)          WORK_PORT="${arg#tokimo.work_port=}" ;;
    esac
done

if [ -z "$CMD_B64" ]; then
    echo "tokimo-init: missing run=" >/dev/kmsg 2>/dev/null || true
    /bin/busybox poweroff -f
fi

/bin/busybox mkdir -p /mnt/work /newroot

# ---------------------------------------------------------------------------
# Load kernel modules from /modules (Hyper-V vsock + 9p stack).
# Order matters: hv_vmbus first, then vsock + hv_sock + 9pnet stack.
# ---------------------------------------------------------------------------
load_mod() {
    local m="/modules/$1.ko"
    [ -f "$m" ] || { echo "tokimo-init: missing module $1" >/dev/kmsg 2>/dev/null; return 0; }
    if /bin/busybox insmod "$m" 2>/tmp/_insmod.err; then
        echo "tokimo-init: insmod $1 OK" >/dev/kmsg 2>/dev/null
    else
        echo "tokimo-init: insmod $1 FAILED: $(/bin/busybox cat /tmp/_insmod.err)" >/dev/kmsg 2>/dev/null
    fi
}

if [ -d /modules ]; then
    # Hyper-V transport.
    load_mod hv_vmbus
    load_mod hv_utils
    # vsock core then hv_sock transport.
    load_mod vsock
    load_mod hv_sock
    # 9p stack (9p needs netfs since 6.x).
    load_mod netfs
    load_mod 9pnet
    load_mod 9pnet_fd
    load_mod 9p
    echo "tokimo-init: modules loaded" >/dev/kmsg 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Mount shared filesystems.
# ---------------------------------------------------------------------------

MOUNTED_ROOT=0

# macOS VZ path: virtio-fs single `work` share, used as both rootfs and work.
if /bin/busybox mount -t virtiofs work /newroot 2>/dev/null; then
    echo "tokimo-init: virtiofs rootfs mounted (macOS VZ mode)" >/dev/kmsg 2>/dev/null || true
    /bin/busybox mkdir -p /newroot/mnt/work
    /bin/busybox mount --bind /newroot /newroot/mnt/work 2>/dev/null || true
    MOUNTED_ROOT=1
fi

# Windows HCS path: two Plan9-over-vsock shares.
if [ "$MOUNTED_ROOT" = 0 ] && [ -n "$ROOTSHARE_PORT" ] && [ -n "$WORK_PORT" ]; then
    if [ -x /bin/vsock9p ]; then
        if /bin/vsock9p /newroot "$ROOTSHARE_PORT" rootshare; then
            echo "tokimo-init: rootshare mounted on vsock port $ROOTSHARE_PORT" >/dev/kmsg 2>/dev/null || true
            /bin/busybox mkdir -p /newroot/mnt/work
            if /bin/vsock9p /newroot/mnt/work "$WORK_PORT" work; then
                echo "tokimo-init: work share mounted on vsock port $WORK_PORT" >/dev/kmsg 2>/dev/null || true
                MOUNTED_ROOT=1
            else
                echo "tokimo-init: work share mount failed" >/dev/kmsg 2>/dev/null || true
            fi
        else
            echo "tokimo-init: rootshare mount failed" >/dev/kmsg 2>/dev/null || true
        fi
    else
        echo "tokimo-init: /bin/vsock9p missing" >/dev/kmsg 2>/dev/null || true
    fi
fi

if [ "$MOUNTED_ROOT" = 0 ]; then
    echo "tokimo-init: no shared filesystem available, powering off" >/dev/kmsg 2>/dev/null || true
    /bin/busybox poweroff -f
fi

# ---------------------------------------------------------------------------
# Bind essential filesystems into the new root.
# ---------------------------------------------------------------------------

/bin/busybox mkdir -p /newroot/proc /newroot/sys /newroot/dev /newroot/run /newroot/tmp 2>/dev/null || true
/bin/busybox mount --bind /proc /newroot/proc 2>/dev/null || /bin/busybox mount -t proc proc /newroot/proc
/bin/busybox mount --bind /sys  /newroot/sys  2>/dev/null || /bin/busybox mount -t sysfs sys /newroot/sys
/bin/busybox mount --bind /dev  /newroot/dev  2>/dev/null || /bin/busybox mount -t devtmpfs dev /newroot/dev
/bin/busybox mount -t tmpfs tmpfs /newroot/tmp 2>/dev/null || true
/bin/busybox mount -t tmpfs tmpfs /newroot/run 2>/dev/null || true

# ---------------------------------------------------------------------------
# Decode and run the command inside the rootfs (chrooted).
# ---------------------------------------------------------------------------

CMD=$(echo "$CMD_B64" | /bin/busybox base64 -d 2>/dev/null || echo "$CMD_B64")
echo "tokimo-init: exec: $CMD" >/dev/kmsg 2>/dev/null || true

# We `chroot` rather than `switch_root` because some shares (Plan9) are
# mounted into /newroot and switch_root would break the underlying
# mounts. chroot is sufficient for one-shot command execution.
#
# IMPORTANT: do not let `set -e` kill us when the user command exits non-zero.
# Disable errexit just for the chroot block, capture RC, then continue.
set +e
STDIN_FILE=/dev/null
[ -f /newroot/mnt/work/.vz_stdin ] && STDIN_FILE=/newroot/mnt/work/.vz_stdin
/bin/busybox chroot /newroot /bin/bash -c "
    cd /mnt/work 2>/dev/null || true
    exec /bin/bash -c \"\$0\"
" "$CMD" <"$STDIN_FILE" >/newroot/mnt/work/.vz_stdout 2>/newroot/mnt/work/.vz_stderr
RC=$?
set -e

echo "$RC" > /newroot/mnt/work/.vz_exit_code

/bin/busybox sync
echo "tokimo-init: done (exit=$RC)" >/dev/kmsg 2>/dev/null || true
/bin/busybox poweroff -f

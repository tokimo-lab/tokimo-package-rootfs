#!/usr/bin/env bash
# Enter TokimoOS sandbox via bwrap (for testing)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOTFS_DIR="$PROJECT_DIR/tokimo-os-amd64/rootfs"

for d in "$PROJECT_DIR"/tokimo-os-*/rootfs; do
    [ -d "$d" ] && ROOTFS_DIR="$d" && break
done

if [ ! -d "$ROOTFS_DIR/usr" ]; then
    echo "error: rootfs not found; run bash build.sh first"
    exit 1
fi

echo "Entering TokimoOS sandbox ... (exit to leave)"
exec bwrap \
  --bind "$ROOTFS_DIR" / \
  --bind /tmp /tmp \
  --proc /proc \
  --dev /dev \
  --ro-bind /etc/resolv.conf /etc/resolv.conf \
  --unshare-user \
  --uid 1000 \
  --gid 1000 \
  --unshare-uts \
  --hostname TokimoOS \
  --unsetenv LD_LIBRARY_PATH \
  --setenv HOME /home/tokimo \
  --setenv USER tokimo \
  --setenv LOGNAME tokimo \
  --setenv TERM "${TERM:-xterm-256color}" \
  /bin/bash --login

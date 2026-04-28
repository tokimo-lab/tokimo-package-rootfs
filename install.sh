#!/usr/bin/env bash
# Install TokimoOS kernel + initrd + rootfs to ~/.tokimo/
# Usage: bash install.sh [amd64|arm64]
set -euo pipefail

ARCH="${1:-amd64}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$PROJECT_DIR/tokimo-os-${ARCH}"
DEST_DIR="${HOME}/.tokimo"
KERNEL_DEST="${DEST_DIR}/kernel"
ROOTFS_DEST="${DEST_DIR}/rootfs"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "error: artifact directory $SOURCE_DIR not found"
    echo "run: bash build.sh ${ARCH}"
    exit 1
fi

echo "Installing TokimoOS (${ARCH}) → ${DEST_DIR}"
mkdir -p "$KERNEL_DEST" "$ROOTFS_DEST"

echo "  vmlinuz    → $KERNEL_DEST/vmlinuz"
cp "$SOURCE_DIR/vmlinuz" "$KERNEL_DEST/vmlinuz"

echo "  initrd.img → $DEST_DIR/initrd.img"
cp "$SOURCE_DIR/initrd.img" "$DEST_DIR/initrd.img"

echo "  rootfs/    → $ROOTFS_DEST/"
rsync -a --delete "$SOURCE_DIR/rootfs/" "$ROOTFS_DEST/"

echo ""
echo "Done. Set env vars or rely on defaults:"
echo "  TOKIMO_VZ_KERNEL=$KERNEL_DEST/vmlinuz"
echo "  TOKIMO_VZ_INITRD=$DEST_DIR/initrd.img"
echo "  TOKIMO_VZ_ROOTFS=$ROOTFS_DEST"

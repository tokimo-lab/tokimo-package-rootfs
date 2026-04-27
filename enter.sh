#!/usr/bin/env bash
# 进入 TokimoOS rootfs 沙箱
# 改动直接写入 rootfs/ 目录，exit 后持久化，git commit 保存版本
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOTFS_DIR="$PROJECT_DIR/rootfs"

if [ ! -d "$ROOTFS_DIR/usr" ]; then
  echo "错误: rootfs 不存在，请先运行 bash build.sh"
  exit 1
fi

echo "进入 TokimoOS 沙箱 ... (exit 退出，改动自动保存到 rootfs/)"
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

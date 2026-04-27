#!/usr/bin/env bash
# 进入 rootfs 交互环境（改动直接持久化到 rootfs/ 目录）
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOTFS_DIR="$PROJECT_DIR/rootfs"

if [ ! -d "$ROOTFS_DIR/usr" ]; then
  echo "错误: rootfs 不存在，请先运行 bash build.sh"
  exit 1
fi

echo "进入 tokimo rootfs ... (exit 退出，改动自动保存)"
exec bwrap \
  --bind "$ROOTFS_DIR" / \
  --bind /tmp /tmp \
  --proc /proc \
  --dev /dev \
  --ro-bind /etc/resolv.conf /etc/resolv.conf \
  --setenv HOME /root \
  --setenv TERM "${TERM:-xterm-256color}" \
  /bin/bash --login

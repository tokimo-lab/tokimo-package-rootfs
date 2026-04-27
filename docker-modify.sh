#!/usr/bin/env bash
# 把现有 rootfs/ 导入 Docker，交互修改后重新导出
# 适合需要 apt install 等重型操作的场景
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOTFS_DIR="$PROJECT_DIR/rootfs"
ROOTFS_TAR="$PROJECT_DIR/rootfs.tar"
CONTAINER_NAME="tokimo-builder"
IMAGE_NAME="tokimo-modify-base"

if [ ! -d "$ROOTFS_DIR/usr" ]; then
  echo "错误: rootfs 不存在，请先运行 bash build.sh"
  exit 1
fi

echo "==> 打包 rootfs/ 为 tar..."
tar -cpf "$ROOTFS_TAR" -C "$ROOTFS_DIR" .

echo "==> 导入为 Docker 镜像..."
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
docker rmi -f "$IMAGE_NAME" 2>/dev/null || true
docker import "$ROOTFS_TAR" "$IMAGE_NAME"
rm -f "$ROOTFS_TAR"

echo "==> 启动交互容器（做完改动后 exit）..."
docker run -it \
  --name "$CONTAINER_NAME" \
  --platform linux/amd64 \
  "$IMAGE_NAME" bash

echo "==> 重新导出 rootfs..."
docker export "$CONTAINER_NAME" -o "$ROOTFS_TAR"
echo "    大小: $(du -sh "$ROOTFS_TAR" | cut -f1)"

rm -rf "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"
tar -xpf "$ROOTFS_TAR" \
  -C "$ROOTFS_DIR" \
  --numeric-owner --no-same-owner \
  --exclude='dev/*' --exclude='proc/*' --exclude='sys/*'

echo "==> 清理..."
docker rm -f "$CONTAINER_NAME"
docker rmi -f "$IMAGE_NAME"
rm -f "$ROOTFS_TAR"

echo "完成! 改动已更新到 rootfs/"
echo "记得 git add -A && git commit"

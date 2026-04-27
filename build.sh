#!/usr/bin/env bash
# 一键构建 tokimo rootfs
# 产物: ./rootfs/ (可直接给 bwrap 使用)
set -euo pipefail

CONTAINER_NAME="tokimo-builder"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOTFS_DIR="$PROJECT_DIR/rootfs"
ROOTFS_TAR="$PROJECT_DIR/rootfs.tar"

echo "==> [1/4] 清理旧容器..."
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
rm -rf "$ROOTFS_DIR"
rm -f  "$ROOTFS_TAR"

echo "==> [2/4] 启动构建容器 (debian:12 amd64)..."
docker run -dit \
  --name "$CONTAINER_NAME" \
  --platform linux/amd64 \
  debian:12 bash

echo "==> [3/4] 配置并安装软件..."
docker exec -i "$CONTAINER_NAME" bash << 'BUILDER_SCRIPT'
set -euo pipefail

# ── APT: 切换清华大学镜像 ─────────────────────────────────────────────────────
cat > /etc/apt/sources.list << 'APTEOF'
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware
APTEOF

apt-get update -qq

# ── 基础工具 ──────────────────────────────────────────────────────────────────
apt-get install -y --no-install-recommends \
  curl wget git ca-certificates gnupg lsb-release \
  build-essential pkg-config \
  vim nano less procps htop \
  ripgrep fd-find jq unzip zip \
  python3 python3-pip python3-venv

# ── Node.js 24 (nodesource) ──────────────────────────────────────────────────
curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
apt-get install -y nodejs
corepack enable

# ── npm: 切换 npmmirror + prefix 指向 /tmp ──────────────────────────────────
npm config set --global registry https://registry.npmmirror.com
npm config set --global prefix /tmp

# ── Node 包: npm -g 安装到 /tmp ──────────────────────────────────────────────
mkdir -p /tmp
npm install -g pnpm tsx typescript ts-node nodemon

# ── pip: 清华 PyPI 镜像 ───────────────────────────────────────────────────────
mkdir -p /etc/pip
cat > /etc/pip.conf << 'PIPEOF'
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
PIPEOF

# ── Python 包: 安装到 /tmp/python_packages ────────────────────────────────────
mkdir -p /tmp/python_packages
pip3 install --break-system-packages --target=/tmp/python_packages \
  python-dotenv requests httpx pydantic ipython rich

# ── 环境变量: profile.d (login shell) ────────────────────────────────────────
cat > /etc/profile.d/tokimo_env.sh << 'ENVEOF'
# tokimo sandbox environment
export NPM_CONFIG_PREFIX=/tmp
export NODE_PATH=/tmp/lib/node_modules
export PATH=/tmp/bin:$PATH
export PYTHONPATH=/tmp/python_packages${PYTHONPATH:+:$PYTHONPATH}
export PIP_TARGET=/tmp/python_packages
export npm_config_registry=https://registry.npmmirror.com
ENVEOF
chmod +x /etc/profile.d/tokimo_env.sh

# ── 同样写到 bash.bashrc (非 login 交互 shell) ────────────────────────────────
cat >> /etc/bash.bashrc << 'BASHRCEOF'

# tokimo sandbox environment
if [ -f /etc/profile.d/tokimo_env.sh ]; then
    . /etc/profile.d/tokimo_env.sh
fi
BASHRCEOF

# ── 清理 apt 缓存 (保留 /tmp 里的包) ─────────────────────────────────────────
apt-get clean
rm -rf /var/lib/apt/lists/* /var/tmp/*

echo "--- 验证 ---"
node --version
python3 --version
python3 -c "import sys; print('PYTHONPATH will include /tmp/python_packages')"
ls /tmp/bin/ | head -10
ls /tmp/python_packages/ | head -10
BUILDER_SCRIPT

echo "==> [4/4] 导出 & 解包 rootfs..."
docker export "$CONTAINER_NAME" -o "$ROOTFS_TAR"
echo "    rootfs.tar 大小: $(du -sh "$ROOTFS_TAR" | cut -f1)"

mkdir -p "$ROOTFS_DIR"
tar -xpf "$ROOTFS_TAR" \
  -C "$ROOTFS_DIR" \
  --numeric-owner \
  --no-same-owner \
  --exclude='dev/*' \
  --exclude='proc/*' \
  --exclude='sys/*'

echo "--- 最终验证 ---"
"$ROOTFS_DIR/usr/bin/node" --version
"$ROOTFS_DIR/usr/bin/python3" --version
echo "Node packages (npm -g -> /tmp/bin):"
ls "$ROOTFS_DIR/tmp/bin/" | head -10
echo "Python packages:"
ls "$ROOTFS_DIR/tmp/python_packages/" | head -10

echo "==> 清理容器和 tar..."
docker rm -f "$CONTAINER_NAME"
rm -f "$ROOTFS_TAR"

echo ""
echo "完成! rootfs 位于: $ROOTFS_DIR"
echo "bwrap 示例: bwrap --bind \$ROOTFS_DIR / --bind /tmp /tmp --proc /proc --dev /dev bash"

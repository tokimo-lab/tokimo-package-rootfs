#!/usr/bin/env bash
# 一键构建 TokimoOS rootfs
# 产物: ./rootfs/ (bwrap 使用, 用户 tokimo, 主目录 /home/tokimo)
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

cat > /etc/apt/sources.list << 'APTEOF'
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware
APTEOF

apt-get update -qq

DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  curl ca-certificates gnupg \
  git vim nano less procps htop \
  ripgrep fd-find jq unzip zip wget \
  python3 python3-pip python3-venv \
  bash-completion

curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
corepack enable

groupadd -g 1000 tokimo
useradd -m -u 1000 -g 1000 -s /bin/bash -d /home/tokimo tokimo

npm config set --global registry https://registry.npmmirror.com
npm config set --global prefix /home/tokimo
npm install -g pnpm tsx typescript ts-node nodemon

cat > /etc/pip.conf << 'PIPEOF'
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
PIPEOF

mkdir -p /home/tokimo/python_packages
pip3 install --break-system-packages --target=/home/tokimo/python_packages \
  python-dotenv requests httpx pydantic ipython rich

echo "TokimoOS" > /etc/hostname

cat > /etc/os-release << 'OSEOF'
PRETTY_NAME="TokimoOS 1.0"
NAME="TokimoOS"
ID=tokimoos
ID_LIKE=debian
VERSION_ID="1.0"
HOME_URL="https://tokimo.io"
OSEOF

cat > /etc/profile.d/tokimo_env.sh << 'ENVEOF'
export HOME=/home/tokimo
export USER=tokimo
export LOGNAME=tokimo
export NPM_CONFIG_PREFIX=/home/tokimo
export NODE_PATH=/home/tokimo/lib/node_modules
export PATH=/home/tokimo/bin:/usr/local/bin:/usr/bin:/bin
export PYTHONPATH=/home/tokimo/python_packages${PYTHONPATH:+:$PYTHONPATH}
export PIP_TARGET=/home/tokimo/python_packages
export npm_config_registry=https://registry.npmmirror.com
ENVEOF
chmod +x /etc/profile.d/tokimo_env.sh

cat > /etc/bash.bashrc << 'BASHRCEOF'
for f in /etc/profile.d/*.sh; do [ -r "$f" ] && . "$f"; done
unset f
[ -f ~/.bashrc ] && . ~/.bashrc
BASHRCEOF

cat > /home/tokimo/.bashrc << 'DOTBASHRC'
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
shopt -s histappend

PS1='[\[\033[35;1m\]\u\[\033[0m\]@\[\033[31;1m\]TokimoOS\[\033[0m\]:\[\033[32;1m\]$PWD\[\033[0m\]]\$ '

alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion 2>/dev/null || true
fi
DOTBASHRC

cat > /home/tokimo/.bash_profile << 'DOTPROFILE'
[ -f ~/.bashrc ] && . ~/.bashrc
DOTPROFILE

cat > /home/tokimo/.inputrc << 'DOTINPUTRC'
set completion-ignore-case on
set show-all-if-ambiguous on
set show-all-if-unmodified on
set colored-stats on
set mark-symlinked-directories on
set visible-stats on
DOTINPUTRC

chown -R tokimo:tokimo /home/tokimo

rm -rf \
  /usr/share/man \
  /usr/share/doc \
  /usr/share/locale \
  /usr/share/info \
  /usr/share/lintian \
  /usr/share/common-licenses

apt-get clean
rm -rf \
  /var/lib/apt/lists/* \
  /var/cache/apt \
  /var/log/apt \
  /var/log/*.log \
  /root/.npm \
  /root/.cache \
  /home/tokimo/.cache \
  /tmp/* \
  /var/tmp/*

find / -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
find / -name '*.pyc' -delete 2>/dev/null || true

echo "--- 验证 ---"
node --version
python3 --version
ls /home/tokimo/bin/ | head -10
ls /home/tokimo/python_packages/ | grep -v dist-info | grep -v __pycache__ | head -15
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
echo "Node bins:"
ls "$ROOTFS_DIR/home/tokimo/bin/" | head -10
echo "Python packages:"
ls "$ROOTFS_DIR/home/tokimo/python_packages/" | grep -v dist-info | grep -v __pycache__ | head -15

echo "==> 清理..."
docker rm -f "$CONTAINER_NAME"
rm -f "$ROOTFS_TAR"
rm -f "$PROJECT_DIR/build.sh.bak"

echo ""
echo "完成! rootfs 位于: $ROOTFS_DIR"
echo "进入沙箱: bash enter.sh"

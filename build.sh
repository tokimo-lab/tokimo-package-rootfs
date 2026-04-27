#!/usr/bin/env bash
# 一键构建 TokimoOS rootfs
# 产物: ./rootfs/ (bwrap 使用, 用户 tokimo, 主目录 /home/tokimo)
# 用法: bash build.sh [amd64|arm64]
set -euo pipefail

ARCH="${1:-${TOKIMO_ARCH:-amd64}}"

case "$ARCH" in
  amd64|x86_64)
    DOCKER_PLATFORM="linux/amd64"
    GO_ARCH="amd64"
    DEB_MULTIARCH="x86_64-linux-gnu"
    ;;
  arm64|aarch64)
    DOCKER_PLATFORM="linux/arm64"
    GO_ARCH="arm64"
    DEB_MULTIARCH="aarch64-linux-gnu"
    ;;
  *)
    echo "错误: 不支持的架构 '$ARCH' (支持: amd64, arm64)"
    exit 1
    ;;
esac

CONTAINER_NAME="tokimo-builder-${ARCH}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOTFS_DIR="$PROJECT_DIR/rootfs-${ARCH}"
ROOTFS_TAR="$PROJECT_DIR/rootfs.tar"

echo "==> [1/4] 清理旧容器 ($ARCH)..."
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
rm -rf "$ROOTFS_DIR"
rm -f  "$ROOTFS_TAR"

echo "==> [2/4] 启动构建容器 (debian:13 ${DOCKER_PLATFORM})..."
docker run -dit \
  --name "$CONTAINER_NAME" \
  --platform "$DOCKER_PLATFORM" \
  debian:13 bash

echo "==> [3/4] 配置并安装软件..."
docker exec -i \
  -e DEB_MULTIARCH="$DEB_MULTIARCH" \
  -e GO_ARCH="$GO_ARCH" \
  "$CONTAINER_NAME" bash << 'BUILDER_SCRIPT'
set -euo pipefail

# 先把 ca-certificates 装上，后面全程 HTTPS
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  ca-certificates curl

# 切到 HTTPS 国内镜像源
rm -f /etc/apt/sources.list.d/debian.sources
cat > /etc/apt/sources.list << 'APTEOF'
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security trixie-security main contrib non-free non-free-firmware
APTEOF

apt-get update -qq

DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  gnupg vim nano less procps \
  wget git jq unzip zip bzip2 xz-utils zstd \
  iputils-ping rsync \
  dnsutils ffmpeg \
  python3 python3-pip python3-venv \
  bash-completion \
  pandoc poppler-utils qpdf tesseract-ocr \
  libreoffice-writer libreoffice-impress libreoffice-calc \
  lua5.4 rustc cargo

curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
corepack enable

groupadd -g 1000 tokimo
useradd -m -u 1000 -g 1000 -s /bin/bash -d /home/tokimo tokimo

npm config set --global registry https://registry.npmmirror.com
npm config set --global prefix /home/tokimo
npm install -g pnpm docx pptxgenjs

curl -fsSL "https://go.dev/dl/go1.24.4.linux-${GO_ARCH}.tar.gz" | tar -C /usr/local -xz
ln -sf ../go/bin/go /usr/local/bin/go
ln -sf ../go/bin/gofmt /usr/local/bin/gofmt

cat > /etc/pip.conf << 'PIPEOF'
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
PIPEOF

ln -sf ../../bin/python3 /usr/local/bin/python
ln -sf ../../bin/lua5.4 /usr/local/bin/lua

mkdir -p /home/tokimo/python_packages
pip3 install --break-system-packages --target=/home/tokimo/python_packages \
  requests ipython rich \
  pypdf pdfplumber reportlab pytesseract pdf2image \
  pandas openpyxl "markitdown[pptx]" Pillow

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
export PATH=/home/tokimo/bin:/home/tokimo/go/bin:/usr/local/bin:/usr/bin:/bin
export GOPATH=/home/tokimo/go
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

# =============================================
# 精简：删除 bwrap 沙箱用不到的东西
# =============================================

# Node.js C++ 头文件 (仅编译原生模块需要, 运行时不需要)
rm -rf /usr/include/node

# Perl 模块文件 (perl-base 是 Essential 保留)
rm -rf /usr/share/perl /usr/share/perl5 /etc/perl

# PulseAudio 库路径注册 (ffmpeg 依赖 libpulsecommon, 不在标准库路径)
echo "/usr/lib/${DEB_MULTIARCH}/pulseaudio" > /etc/ld.so.conf.d/pulseaudio.conf
# LibreOffice 库路径注册
echo "/usr/lib/libreoffice/program" > /etc/ld.so.conf.d/libreoffice.conf
ldconfig

# Scalar (Git 大仓库管理工具)
rm -rf /usr/bin/scalar /usr/share/man/man1/scalar* 2>/dev/null || true

# GPG 附属工具 (保留 gpg 本体)
apt-get remove -y dirmngr gpgsm 2>/dev/null || true

# Vim 文档/帮助/教程 (保留编辑器本体)
rm -rf /usr/share/vim/vim*/doc /usr/share/vim/vim*/tutor
# Vim 语法: 只保留文案工作者常用的 (删掉 180+ 编程语言语法文件)
find /usr/share/vim/vim*/syntax -type f ! -name 'markdown.vim' ! -name 'text.vim' \
  ! -name 'help.vim' ! -name 'vim.vim' ! -name 'viminfo.vim' \
  ! -name 'sh.vim' ! -name 'bash.vim' ! -name 'python.vim' \
  ! -name 'json.vim' ! -name 'yaml.vim' ! -name 'xml.vim' \
  ! -name 'html.vim' ! -name 'css.vim' ! -name 'javascript.vim' \
  ! -name 'conf.vim' ! -name 'gitcommit.vim' ! -name 'gitconfig.vim' \
  ! -name 'diff.vim' ! -name 'csv.vim' ! -name 'toml.vim' \
  ! -name 'sql.vim' ! -name 'log.vim' ! -name 'dosini.vim' \
  ! -name 'cmake.vim' ! -name 'make.vim' \
  ! -name 'lua.vim' ! -name 'go.vim' ! -name 'rust.vim' \
  -delete 2>/dev/null || true

# systemd / init / udev (bwrap 无 init 系统)
rm -rf /usr/lib/systemd /usr/lib/init /etc/systemd /etc/init.d
rm -rf /var/lib/systemd /usr/lib/tmpfiles.d /usr/lib/sysctl.d
rm -rf /usr/lib/udev /etc/udev 2>/dev/null || true

# 桌面相关 (图标/菜单/桌面入口)
rm -rf /usr/share/icons /usr/share/pixmaps /usr/share/applications
rm -rf /usr/share/menu /usr/share/polkit-1

# 其他 shell (只用 bash)
rm -rf /usr/share/fish /usr/share/zsh

# 杂项 share 目录
rm -rf /usr/share/keyrings /usr/share/gcc /usr/share/libgcrypt20
rm -rf /usr/share/cmake /usr/share/pkgconfig /usr/share/binfmts
rm -rf /usr/share/libc-bin /usr/share/readline /usr/share/misc
rm -rf /usr/share/bug /usr/share/doc-base /usr/share/debconf
rm -rf /usr/share/debianutils /usr/share/base-files /usr/share/base-passwd
rm -rf /usr/share/gdb /usr/share/gitweb /usr/share/tabset
rm -rf /usr/share/python-wheels

# PAM (bwrap 单用户, 无登录认证)
rm -rf /etc/pam.d /etc/pam.conf /etc/security /usr/share/pam*
rm -rf /var/lib/pam

# etc 杂项 (不影响 apt 的部分)
rm -rf /etc/cron* /etc/logrotate.d /etc/logcheck /etc/default /etc/skel

# usr/lib 杂项
rm -rf /usr/lib/lsb /usr/lib/valgrind /usr/lib/mime

# /usr/sbin: 只保留沙箱需要的, 其他全删
# 保留: ldconfig(库路径), update-ca-certificates(证书), zic(时区), sysctl, iconvconfig
find /usr/sbin -type f ! -name 'ldconfig' ! -name 'update-ca-certificates' \
  ! -name 'zic' ! -name 'sysctl' ! -name 'iconvconfig' -delete 2>/dev/null || true

# terminfo: 只保留 xterm
find /usr/share/terminfo -type f ! -path '*/xterm*' -delete 2>/dev/null || true
find /usr/share/terminfo -type d -empty -delete 2>/dev/null || true

# zoneinfo: 只保留 Asia + UTC + PRC
find /usr/share/zoneinfo -type f \
  ! -path '*/Asia/*' ! -name 'UTC' ! -name 'PRC' ! -name 'posixrules' \
  -delete 2>/dev/null || true
find /usr/share/zoneinfo -type d -empty -delete 2>/dev/null || true

# === 原清理步骤 (apt 操作) ===

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
python --version
lua -v
go version
rustc --version
cargo --version
pandoc --version | head -1
pdftoppm -v 2>&1 | head -1
qpdf --version 2>&1 | head -1
dig -v 2>&1 | head -1
ls /home/tokimo/bin/ | head -15
ls /home/tokimo/python_packages/ | grep -v dist-info | grep -v __pycache__ | head -20
BUILDER_SCRIPT

echo "==> [4/4] 导出 & 解包 rootfs..."
docker export "$CONTAINER_NAME" -o "$ROOTFS_TAR"
echo "    rootfs.tar 大小: $(du -sh "$ROOTFS_TAR" | cut -f1)"

mkdir -p "$ROOTFS_DIR"
tar -xpf "$ROOTFS_TAR" \
  -C "$ROOTFS_DIR" \
  --numeric-owner \
  --no-same-owner \
  --exclude='./dev/*' \
  --exclude='./proc/*' \
  --exclude='./sys/*'

echo "--- 最终验证 ---"
"$ROOTFS_DIR/usr/bin/node" --version
"$ROOTFS_DIR/usr/bin/python3" --version
"$ROOTFS_DIR/usr/local/bin/python" --version
"$ROOTFS_DIR/usr/local/bin/lua" -v
"$ROOTFS_DIR/usr/local/bin/go" version
"$ROOTFS_DIR/usr/bin/rustc" --version
echo "Node bins:"
ls "$ROOTFS_DIR/home/tokimo/bin/" | head -15
echo "Python packages:"
ls "$ROOTFS_DIR/home/tokimo/python_packages/" | grep -v dist-info | grep -v __pycache__ | head -20

echo "==> 清理..."
docker rm -f "$CONTAINER_NAME"
rm -f "$ROOTFS_TAR"
rm -f "$PROJECT_DIR/build.sh.bak"

echo ""
echo "完成! rootfs (${ARCH}) 位于: $ROOTFS_DIR"
echo "产物大小: $(du -sh "$ROOTFS_DIR" | cut -f1)"
echo "进入沙箱: bwrap --bind $ROOTFS_DIR / ..."

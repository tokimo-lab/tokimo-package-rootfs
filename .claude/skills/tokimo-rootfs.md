---
name: tokimo-rootfs
description: Build and manage the TokimoOS rootfs — a Debian 13 based bwrap sandbox filesystem with Node.js/Python/ffmpeg
type: knowledge
---

# TokimoOS rootfs

基于 Debian 13 (Trixie) 的精简容器文件系统，专为 [bwrap](https://github.com/containers/bubblewrap) 沙箱设计。

## 项目结构

```
├── build.sh              # 一键构建 (Docker → rootfs.tar → rootfs/)
├── enter.sh              # bwrap 进入沙箱
├── docker-modify.sh      # rootfs → Docker 容器交互修改 → 重新导出
├── rootfs/               # 构建产物 (.gitignore)
├── .github/workflows/build.yml  # CI: 自动构建 + zstd 压缩 + Release
└── README.md
```

## 构建命令

```bash
bash build.sh        # 完整构建（需要 Docker）
bash enter.sh        # 进入 rootfs 沙箱
bash docker-modify.sh # rootfs 导入 Docker 交互式修改
```

## 发布新版本

```bash
git tag v1.1.0 && git push origin v1.1.0
# CI 自动构建、zstd 压缩、创建 GitHub Release
```

## 构建细节

### 基镜像
- `debian:13` (Linux/amd64)
- 先用默认源装 ca-certificates → 切 HTTPS 清华源
- apt sources 保存在 `/etc/apt/sources.list`

### 安装的包
- **运行时**: nodejs (via nodesource), python3, python3-pip, python3-venv
- **编辑**: vim, nano
- **网络**: curl, wget, git, dnsutils (dig), iputils-ping, rsync
- **媒体**: ffmpeg
- **压缩**: bzip2, xz-utils, zstd, zip, unzip
- **工具**: gnupg, less, procps, jq, bash-completion
- **npm 全局**: pnpm (registry = npmmirror)
- **pip 包**: requests, ipython, rich (index-url = 清华源)

### 不安装
- ripgrep, fd-find, htop (开发工具, 文案工作者不需要)
- tsx, typescript, ts-node, nodemon (开发者工具)

### 深度清理
- `/usr/include/node` — Node C++ 头文件 (省 65MB)
- `/usr/share/perl` — Perl 模块文件 (perl-base 保留)
- systemd / init / udev — bwrap 无 init 系统
- 桌面文件 — icons, pixmaps, applications, menu, polkit
- 其他 shell — fish, zsh
- PAM — 单用户沙箱无需认证
- tirm /sbin — 只保留 ldconfig, update-ca-certificates, zic, sysctl, iconvconfig
- terminfo — 只保留 xterm
- zoneinfo — 只保留 Asia + UTC + PRC
- apt/dpkg 保留不动 (可动态安装)
- /usr/share/man, doc, locale, info, lintian

### 体积参考
- 原始 Debian 13 ffmpeg 全套: ~850MB
- 深度精简前 (仅删 man/doc): ~590MB
- 精简后: ~420MB (不含 ffmpeg), ~850MB (含 ffmpeg)

## Release 产物
- `rootfs.tar.zst` — zstd 压缩的 rootfs tar 包
- `sha256sum.txt` — 校验文件
- 每次 tag push 自动发布

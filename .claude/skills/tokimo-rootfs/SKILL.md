---
name: tokimo-rootfs
description: Build, modify, and publish releases for TokimoOS rootfs — a Debian 13 based bwrap sandbox filesystem
when_to_use: When the user wants to build the rootfs, add/remove packages, publish a new release, or enter the sandbox
user-invocable: true
---

# TokimoOS rootfs

基于 Debian 13 (Trixie) 的精简容器文件系统，专为 bwrap 沙箱设计。

## 项目结构

```
tokimo-package-rootfs/
├── build.sh              # 一键构建 (Docker → rootfs.tar → rootfs/)
├── enter.sh              # bwrap 进入沙箱
├── docker-modify.sh      # rootfs → Docker 容器交互修改 → 重新导出
├── rootfs/               # 构建产物 (.gitignore)
├── .github/workflows/build.yml  # CI: 自动构建 + zstd 压缩 + Release
└── README.md
```

## 关键命令

```bash
bash build.sh                         # 完整构建（需要 Docker）
bash enter.sh                         # 进入 rootfs 沙箱
bash docker-modify.sh                 # rootfs 导入 Docker 交互式修改
git tag v1.1.0 && git push origin v1.1.0   # 发布新版本（CI 自动构建 Release）
```

## 构建细节

### 镜像 & 源
- 基镜像: `debian:13` (linux/amd64)
- 先装 ca-certificates → 切 HTTPS 清华源

### 预装包
- **运行时**: nodejs (via nodesource 24.x), python3, python3-pip, python3-venv
- **编辑**: vim, nano
- **网络**: curl, wget, git, dnsutils (dig), iputils-ping, rsync
- **媒体**: ffmpeg
- **压缩**: bzip2, xz-utils, zstd, zip, unzip
- **工具**: gnupg, less, procps, jq, bash-completion
- **npm 全局**: pnpm (registry = npmmirror)
- **pip 包**: requests, ipython, rich (index-url = 清华源)

### 深度清理
- 删除: `/usr/include/node`, `/usr/share/perl`, systemd, init, udev, PAM, fish/zsh, 桌面文件, man/doc/locale/info, 大部分 /usr/sbin, 非 xterm terminfo, 非 Asia/UTC/PRC zoneinfo
- 保留: apt/dpkg（AI 可动态安装包）
- Vim 语法: 只保留文案工作者常用的 25 种（markdown, json, yaml, python, html 等）

### 体积参考
- 含 ffmpeg: ~850MB
- 不含 ffmpeg: ~420MB

## Release 产物
- `rootfs.tar.zst` — zstd 压缩
- `sha256sum.txt` — 校验文件

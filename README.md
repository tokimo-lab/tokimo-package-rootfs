# TokimoOS rootfs

基于 **Debian 13 (Trixie)** 的精简容器文件系统。专为 [bwrap](https://github.com/containers/bubblewrap) 沙箱设计，开箱即用 Node.js + Python 环境。

## 特性

- **轻量** — 经过深度精简，去除 systemd/init/PAM/桌面文件等沙箱无用内容
- **自带运行时** — Node.js 24 + Python 3.13，预装 pnpm / ipython / requests
- **工具齐全** — ffmpeg, git, vim, nano, curl, wget, dig, ping, rsync, jq, zstd 等
- **中国镜像** — apt (清华源), npm (npmmirror), pip (清华源) 已配置
- **apt 保留** — 缺什么随时 `apt install`
- **Zstd 压缩发布** — Release 提供 `.tar.zst` 下载

## 快速使用

```bash
# 下载最新 rootfs
wget https://github.com/tokimo-lab/tokimo-package-rootfs/releases/latest/download/rootfs.tar.zst
zstd -d rootfs.tar.zst
mkdir rootfs && tar -xpf rootfs.tar -C rootfs

# bwrap 进入沙箱
exec bwrap \
  --bind rootfs / \
  --bind /tmp /tmp \
  --proc /proc \
  --dev /dev \
  --ro-bind /etc/resolv.conf /etc/resolv.conf \
  --unshare-user \
  --uid 1000 \
  --gid 1000 \
  --hostname TokimoOS \
  /bin/bash --login
```

## 预装清单

| 类别 | 内容 |
|------|------|
| **运行时** | Node.js 24, Python 3.13, pnpm |
| **编辑** | vim, nano |
| **网络** | curl, wget, dig (dnsutils), ping, rsync, git |
| **媒体** | ffmpeg, ffprobe |
| **压缩** | tar, gzip, bzip2, xz, zstd, zip, unzip |
| **Python 包** | ipython, requests, rich |
| **其他** | jq, ripgrep-style grep, bash-completion |

## 从源码构建

需要 Docker。

```bash
git clone https://github.com/tokimo-lab/tokimo-package-rootfs.git
cd tokimo-package-rootfs
bash build.sh
```

产物在 `./rootfs/` 目录，可直接搭配 `enter.sh` 进入沙箱。

## 项目结构

```
├── build.sh          # 一键构建脚本 (Docker → rootfs)
├── enter.sh          # bwrap 进入沙箱
├── docker-modify.sh  # rootfs 导入 Docker 交互修改
├── rootfs/           # 构建产物 (解包后的文件系统)
│   ├── bin → usr/bin
│   ├── etc/
│   ├── usr/
│   └── home/
└── .github/workflows/build.yml  # CI: 构建 + Release
```

## Release 下载

访问 [Releases](https://github.com/tokimo-lab/tokimo-package-rootfs/releases) 页面获取最新构建的 `rootfs.tar.zst`。

文件名 | 说明
---|---
`rootfs.tar.zst` | 完整 rootfs (Zstd 压缩)
`sha256sum.txt` | 校验文件

## License

MIT

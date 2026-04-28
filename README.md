# TokimoOS

A minimal Linux OS bundle (kernel + initrd + Debian rootfs) for sandbox VMs.

Used by [tokimo-package-sandbox](https://github.com/tokimo-lab/tokimo-package-sandbox) on macOS (Virtualization.framework) and Windows (Hyper-V/HCS).

## What's included

| Artifact | Description |
|----------|------------|
| `vmlinuz` | Linux kernel (cloud-image, virtio + 9p drivers) |
| `initrd.img` | initramfs with busybox + tokimo init script |
| `rootfs/` | Debian 13 (Trixie) filesystem, heavily stripped |

The initrd init script auto-detects the shared filesystem mount type (virtiofs on macOS, 9p on Windows HCS) and runs the same command execution logic on both platforms.

## Features

- **Slim** — heavily stripped of systemd, init, udev, PAM, desktop files
- **Runtimes** — Node.js 24, Python 3.13, Lua 5.4
- **Office tools** — LibreOffice (headless), pandoc, poppler, qpdf, tesseract-ocr
- **Python packages** — pypdf, pdfplumber, reportlab, pytesseract, pdf2image, pandas, openpyxl, markitdown, ipython, requests, rich, Pillow
- **Node.js global** — pnpm, docx, pptxgenjs
- **Media & network** — ffmpeg, git, curl, wget, dig, ping, rsync, jq, zstd
- **China mirrors** — apt (Tsinghua), npm (npmmirror), pip (Tsinghua) pre-configured
- **apt kept** — install anything else on demand

## Quick start

```bash
# Download latest TokimoOS bundle (kernel + initrd)
curl -LO https://github.com/tokimo-lab/tokimo-package-rootfs/releases/latest/download/tokimo-os-amd64.tar.zst
zstd -d tokimo-os-amd64.tar.zst
mkdir -p ~/.tokimo/kernel
tar -xpf tokimo-os-amd64.tar -C ~/.tokimo/

# Download rootfs
curl -LO https://github.com/tokimo-lab/tokimo-package-rootfs/releases/latest/download/rootfs-amd64.tar.zst
zstd -d rootfs-amd64.tar.zst
mkdir -p ~/.tokimo/rootfs
tar -xpf rootfs-amd64.tar -C ~/.tokimo/rootfs

# Or build from source
bash build.sh amd64 && bash install.sh amd64
```

## Building from source

Docker required. Supports amd64 and arm64.

```bash
git clone https://github.com/tokimo-lab/tokimo-package-rootfs.git
cd tokimo-package-rootfs

# Build (amd64 default)
bash build.sh

# Build for arm64 (Apple Silicon)
bash build.sh arm64

# Install to ~/.tokimo/
bash install.sh amd64
```

Output at `./tokimo-os-{arch}/`:
```
tokimo-os-amd64/
├── vmlinuz       # Linux kernel
├── initrd.img    # initramfs (busybox + init.sh)
└── rootfs/       # Debian filesystem
```

## Project structure

```
├── build.sh              # One-shot build (Docker → kernel + initrd + rootfs)
├── init.sh               # Initrd PID 1 script
├── install.sh            # Install to ~/.tokimo/
├── enter.sh              # Enter rootfs via bwrap for testing
├── docker-modify.sh      # Import rootfs into Docker for interactive modification
├── .github/workflows/    # CI: build + release (tokimo-os + rootfs artifacts)
└── tokimo-os-{arch}/     # Build artifact (git-ignored)
```

## Release downloads

Visit [Releases](https://github.com/tokimo-lab/tokimo-package-rootfs/releases).

| File | Contents | Arch |
|------|----------|------|
| `tokimo-os-amd64.tar.zst` | kernel + initrd | x86_64 (Intel Mac / Windows) |
| `tokimo-os-arm64.tar.zst` | kernel + initrd | aarch64 (Apple Silicon) |
| `rootfs-amd64.tar.zst` | Debian rootfs | x86_64 |
| `rootfs-arm64.tar.zst` | Debian rootfs | aarch64 |

## License

MIT

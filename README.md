# TokimoOS rootfs

A minimal container filesystem based on **Debian 13 (Trixie)**, purpose-built for [bwrap](https://github.com/containers/bubblewrap) sandboxes.

## Features

- **Slim** — heavily stripped of systemd, init, udev, PAM, desktop files, and other sandbox-irrelevant cruft
- **Runtimes** — Node.js 24, Python 3.13, Lua 5.4, Go 1.24, Rust 1.85
- **Office tools** — LibreOffice (headless), pandoc, poppler, qpdf, tesseract-ocr
- **Python packages** — pypdf, pdfplumber, reportlab, pytesseract, pdf2image, pandas, openpyxl, markitdown, ipython, requests, rich, Pillow
- **Node.js global** — pnpm, docx, pptxgenjs
- **Media & network** — ffmpeg, git, curl, wget, dig, ping, rsync, jq, zstd
- **China mirrors** — apt (Tsinghua), npm (npmmirror), pip (Tsinghua) pre-configured
- **apt kept** — install anything else on demand

## Quick start

```bash
# Download latest rootfs
wget https://github.com/tokimo-lab/tokimo-package-rootfs/releases/latest/download/rootfs-amd64.tar.zst
zstd -d rootfs-amd64.tar.zst
mkdir rootfs && tar -xpf rootfs-amd64.tar -C rootfs

# Enter sandbox with bwrap
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

## Pre-installed packages

| Category | Contents |
|----------|----------|
| **Runtimes** | Node.js 24, Python 3.13, Lua 5.4, Go 1.24, Rust 1.85 |
| **Editors** | vim, nano |
| **Network** | curl, wget, dig (dnsutils), ping, rsync, git |
| **Media** | ffmpeg |
| **Compression** | bzip2, xz, zstd, zip, unzip |
| **Office / docs** | pandoc, libreoffice (headless), poppler-utils, qpdf, tesseract-ocr |
| **Python** | ipython, requests, rich, pypdf, pdfplumber, reportlab, pytesseract, pdf2image, pandas, openpyxl, markitdown, Pillow |
| **Node.js global** | pnpm, docx, pptxgenjs |
| **Other** | jq, bash-completion |

## Building from source

Docker required. Supports amd64 and arm64.

```bash
git clone https://github.com/tokimo-lab/tokimo-package-rootfs.git
cd tokimo-package-rootfs

# Build for amd64 (default)
bash build.sh

# Build for arm64
bash build.sh arm64
```

Output is at `./rootfs-amd64/` (or `./rootfs-arm64/`). Use `enter.sh` to drop into the sandbox.

## Project structure

```
├── build.sh              # One-shot build (Docker → rootfs)
├── enter.sh              # Enter sandbox via bwrap
├── docker-modify.sh      # Import rootfs into Docker for interactive modification
├── .claude/skills/       # Claude Code skill definitions
├── .github/workflows/    # CI: build + release
└── rootfs-{arch}/        # Build artifact (extracted filesystem)
```

## Release downloads

Visit [Releases](https://github.com/tokimo-lab/tokimo-package-rootfs/releases) for the latest pre-built `rootfs-*.tar.zst` files.

| File | Arch |
|------|------|
| `rootfs-amd64.tar.zst` | x86_64 / Intel Mac |
| `rootfs-arm64.tar.zst` | aarch64 / Apple Silicon |
| `sha256sum-{arch}.txt` | Checksum file |

## License

MIT

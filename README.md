# TokimoOS

A minimal Linux sandbox image (kernel + initrd + Debian 13 rootfs) consumed by
[tokimo-package-sandbox](https://github.com/tokimo-lab/tokimo-package-sandbox).

The sandbox is fundamentally a **Linux** sandbox; the host platform only changes
how the Linux image is launched:

| Host | Launcher | Needs kernel? | Rootfs format |
|------|----------|---------------|---------------|
| Linux x86_64       | bubblewrap (`bwrap`) | No (uses host kernel) | rootfs tarball |
| Windows x86_64     | Hyper-V HCS micro-VM | Yes                   | ext4 VHDX disk |
| macOS Apple Silicon (arm64) | `Virtualization.framework` (VZ) | Yes | rootfs tarball (virtiofs share) |

> Only the three host combinations above are supported. The matrix builds
> `amd64` and `arm64` images because Windows x86_64 and Linux x86_64 share the
> same `amd64` build, while macOS Apple Silicon needs `arm64`.

## Release artifacts

Released at <https://github.com/tokimo-lab/tokimo-package-rootfs/releases>.

| File | Contents | Consumed by |
|------|----------|-------------|
| `tokimo-linux-rootfs-x86_64.tar.zst`  | Debian 13 rootfs (zstd tarball) | Linux x86_64 (bwrap) |
| `tokimo-linux-rootfs-arm64.tar.zst`   | Debian 13 rootfs (zstd tarball) | macOS arm64 (VZ virtiofs) |
| `tokimo-linux-rootfs-x86_64.vhdx.zip` | ext4 VHDX disk image            | Windows x86_64 (HCS) |
| `tokimo-linux-kernel-x86_64.tar.zst`  | `vmlinuz` + `initrd.img`        | Windows x86_64 (HCS) |
| `tokimo-linux-kernel-arm64.tar.zst`   | `vmlinuz` + `initrd.img`        | macOS arm64 (VZ) |

Each file has a matching `.sha256` checksum.

### Per-host download list

| Host | Download |
|------|----------|
| Linux x86_64   | `tokimo-linux-rootfs-x86_64.tar.zst` |
| Windows x86_64 | `tokimo-linux-kernel-x86_64.tar.zst` + `tokimo-linux-rootfs-x86_64.vhdx.zip` |
| macOS arm64    | `tokimo-linux-kernel-arm64.tar.zst` + `tokimo-linux-rootfs-arm64.tar.zst` |

## What's inside

- **Slim** — heavily stripped of systemd, init, udev, PAM, desktop files
- **Runtimes** — Node.js 24, Python 3.13, Lua 5.4
- **Office tools** — LibreOffice (headless), pandoc, poppler, qpdf, tesseract-ocr
- **Python packages** — pypdf, pdfplumber, reportlab, pytesseract, pdf2image, pandas, openpyxl, markitdown, ipython, requests, rich, Pillow
- **Node.js global** — pnpm, docx, pptxgenjs
- **Media & network** — ffmpeg, git, curl, wget, dig, ping, rsync, jq, zstd
- **China mirrors** — apt (Tsinghua), npm (npmmirror), pip (Tsinghua) pre-configured
- **apt kept** — install anything else on demand

The initrd init script auto-detects the share type at boot:

* SCSI VHDX (Windows HCS) → mount `/dev/sda` as ext4, switch root.
* virtiofs share (macOS VZ) → mount the share, chroot.
* Plan9-over-vsock (Windows HCS, fallback) → mount via `vsock9p`, chroot.

The initrd also bundles all kernel modules that the Debian generic kernel
splits out (`hv_vmbus`, `hv_storvsc`, `scsi_common`, `scsi_mod`, `sd_mod`,
`9pnet`, `vsock`, `hv_sock`, `crc16`, `crc32c`, `jbd2`, `mbcache`, `ext4`,
plus all transitive deps resolved via `modinfo -F depends`).

## Quick start

```bash
# Linux x86_64 host
curl -LO https://github.com/tokimo-lab/tokimo-package-rootfs/releases/latest/download/tokimo-linux-rootfs-x86_64.tar.zst
zstd -d tokimo-linux-rootfs-x86_64.tar.zst
mkdir -p ~/.tokimo/rootfs
tar -xpf tokimo-linux-rootfs-x86_64.tar -C ~/.tokimo/rootfs

# Windows x86_64 host (PowerShell)
curl -LO https://github.com/tokimo-lab/tokimo-package-rootfs/releases/latest/download/tokimo-linux-kernel-x86_64.tar.zst
curl -LO https://github.com/tokimo-lab/tokimo-package-rootfs/releases/latest/download/tokimo-linux-rootfs-x86_64.vhdx.zip
# extract kernel.tar.zst → vm/vmlinuz, vm/initrd.img
# unzip vhdx.zip       → vm/rootfs.vhdx

# macOS arm64 host
curl -LO https://github.com/tokimo-lab/tokimo-package-rootfs/releases/latest/download/tokimo-linux-kernel-arm64.tar.zst
curl -LO https://github.com/tokimo-lab/tokimo-package-rootfs/releases/latest/download/tokimo-linux-rootfs-arm64.tar.zst
```

## Build from source

Docker required.

```bash
git clone https://github.com/tokimo-lab/tokimo-package-rootfs.git
cd tokimo-package-rootfs
bash build.sh amd64        # or arm64
```

Output at `./tokimo-os-{arch}/`:

```
tokimo-os-amd64/
├── vmlinuz       # Linux kernel
├── initrd.img    # initramfs (busybox + init.sh + tokimo-sandbox-init + modules)
└── rootfs/       # Debian filesystem
```

## Project structure

```
├── build.sh              # One-shot build (Docker → kernel + initrd + rootfs)
├── init.sh               # Initrd PID 1 script
├── install.sh            # Install to ~/.tokimo/
├── enter.sh              # Enter rootfs via bwrap for testing
├── docker-modify.sh      # Import rootfs into Docker for interactive modification
├── vsock9p.c             # Static helper used by initrd to mount Plan9-over-vsock
├── .github/workflows/    # CI: build + release
└── tokimo-os-{arch}/     # Build artifact (git-ignored)
```

## License

MIT

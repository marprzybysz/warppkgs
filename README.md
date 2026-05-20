# warppkgs — Flow Linux package repository

Package repository for the [WARP](https://github.com/marprzybysz/warp) package manager — the sole package manager for Flow Linux.  
Internally called **"tabela kompilacji"** — each WARPBUILD is a build recipe that produces a `.wrp` binary package.

## Overview

**317 packages** organized into category directories. Each package contains a `WARPBUILD` file with metadata and `build()` / `package()` functions. Some packages have `INSTALL` / `REMOVE` hooks for post-install automation.

## Directory structure

```
warppkgs/
├── base/          Base system utilities (glibc chain, openssl, pam…)
├── toolchain/     Compilers & build tools (gcc, clang, rust, go, zig…)
├── langs/         Programming language runtimes (nodejs, openjdk, ruby…)
├── libs/          Libraries (gtk, mesa, x11, wayland, boost…)
├── audio/         Audio stack + players + codecs
├── network/       Network tools (curl, openssh, NetworkManager…)
├── display/       Display server (xorg-server, xwayland)
├── drivers/       GPU, input, Vulkan, firmware, NVIDIA
├── desktop/       DEs, WMs, Qt6, KDE, GNOME, SDDM
├── terminals/     Terminal emulators (alacritty, kitty, ghostty…)
├── browsers/      Web browsers (chromium, zen-browser)
├── media/         Media players & encoders (ffmpeg, mpv, x264)
├── containers/    Docker, Podman, containerd, runc
├── devtools/      Dev tools (git, neovim, helix, vim)
├── monitoring/    System monitoring (htop, btop, fastfetch)
├── cli/           Modern CLI utilities (ripgrep, fzf, bat, jq…)
├── filemanagers/  TUI file managers (mc, lf, ranger, nnn)
├── shell/         Shells & prompt (fish, zsh, starship)
├── editors/       Multiplexers & editors (tmux, zellij)
├── windows/       Windows compatibility (wine, bottles, cabextract, p7zip)
└── pending/       Build workspace — packages under development
```

## WARPBUILD format

```bash
pkgname=example
pkgver=1.0.0
description="Short description"
arch=x86_64
license=GPL-2.0
deps=glibc,libfoo          # runtime dependencies
makedeps=gcc,cmake         # build-only dependencies
source=https://example.com/example-1.0.0.tar.gz
sha256=abc123...

build() {
    ./configure --prefix=/usr
    make $MAKEFLAGS
}

package() {
    make DESTDIR="$DESTDIR" install
}
```

## Package categories

### Base system
Core userland utilities that form the foundation of Flow Linux.

`acl` `attr` `autoconf` `automake` `bc` `bzip2` `coreutils` `diffutils`
`e2fsprogs` `elfutils` `eudev` `expat` `expect` `file` `findutils` `flex`
`gawk` `gdbm` `gettext` `gmp` `grep` `groff` `gzip` `inetutils` `intltool`
`kbd` `kmod` `less` `libarchive` `libcap` `libffi` `libpipeline` `libtool`
`lz4` `m4` `make` `man-db` `man-pages` `mpc` `mpfr` `ncurses` `openrc`
`openssl` `patch` `pcre2` `perl` `pkgconf` `procps-ng` `readline` `sed`
`shadow` `sysklogd` `tar` `tcl` `texinfo` `util-linux` `which` `xz-utils`
`zlib` `zstd` `audit` `pam`

### Toolchain & build tools
Compilers, build systems, and language runtimes.

`clang` `cmake` `go` `meson` `ninja` `python3` `rust` `zig` `llvm`
`cbindgen` `extra-cmake-modules` `nasm` `blueprint-compiler` `lua`
`glslang` `gn` `gperf` `itstool` `vala`

> `rust`, `go`, `zig` — distributed as pre-built binaries, no source compilation.
> `llvm` — ~100 SBU, backend dla Crystal, D language i clang.

### Programming languages

**JVM:**
`openjdk` *(21 LTS, pre-built)* · `kotlin` · `scala` · `groovy`

**Build tools JVM:**
`gradle` · `maven`

**Scripting:**
`nodejs` *(22 LTS)* · `php` *(8.4)* · `ruby`

**Systems / compiled:**
`nim` *(Python-like syntax → compiles to C → native)* · `dlang` *(LDC2, pre-built)* · `crystal`

**Functional:**
`ghc` *(Haskell, pre-built)* · `ocaml` · `erlang` · `elixir` *(requires erlang)*

**Scientific:**
`julia` *(pre-built)* · `r-lang`

> Already in toolchain: `rust` `go` `zig` `clang` `python3` `perl` `lua`

### Libraries

**Graphics & UI:**
`atk` `at-spi2-core` `cairo` `fontconfig` `freetype` `fribidi` `gdk-pixbuf`
`gtk3` `gtk4` `graphite` `harfbuzz` `libadwaita` `libdrm` `libjpeg-turbo`
`libpng` `libva` `libvpx` `mesa` `pango` `pixman` `vte`

**System & auth:**
`dbus` `elogind` `glib` `gobject-introspection` `libcap` `libev` `libevdev`
`libevent` `libffi` `libinput` `libnl` `libndp` `libseccomp` `libsecret`
`libusb` `mtdev` `nss` `oniguruma` `polkit` `shared-mime-info`

**Crypto & GPG:**
`libassuan` `libgpg-error` `gpgme`

**Compression & data:**
`blas` `boost` `duktape` `gc` `lapack` `libatomic_ops` `libogg` `libvorbis`
`libmad` `flac` `opus` `opusfile` `sqlite`

**Network:**
`c-ares` `libev` `libmnl` `libnetfilter_conntrack` `libnftnl` `libssh2`
`libidn2` `nghttp2` `popt`

**X11/Wayland:**
`libx11` `libxau` `libxcb` `libxcomposite` `libxdamage` `libxdmcp` `libxext`
`libxfixes` `libxft` `libxi` `libxinerama` `libxkbcommon` `libxrender`
`libxtst` `wayland` `wayland-protocols` `xcb-proto` `xcb-util`
`xcb-util-cursor` `xcb-util-keysyms` `xcb-util-wm` `xkeyboard-config`
`xorg-util-macros` `xtrans`

**Neovim/editor deps:**
`libvterm` `libuv` `msgpack-c` `treesitter` `unibilium` `libxml2` `libyaml`
`libglvnd`

### Audio

**Stack:**
`alsa-lib` `alsa-utils` `pipewire` `wireplumber`

**Players (CLI/TUI):**
`cmus` `mpd` `mpc` `ncmpcpp` `sox`

**Codecs:**
`flac` `libmad` `libvorbis` `libogg` `opus` `opusfile`

> `pipewire` built with `-Dsystemd=disabled` for OpenRC compatibility.

### Network
`curl` `iproute2` `iptables` `libmnl` `libnftnl` `libnetfilter_conntrack`
`networkmanager` `openssh` `rsync` `wget` `wpa_supplicant`

> `networkmanager` built with `-Dsession_tracking=elogind` for OpenRC.

### Display server
`xorg-server` `xorg-xinit` `xwayland`

### Drivers

**Xorg DDX (GPU):**
`xf86-video-amdgpu` `xf86-video-intel` `xf86-video-nouveau`
`xf86-video-fbdev` *(fallback)* `xf86-video-vesa` *(fallback)*

**Input:**
`xf86-input-libinput`

**Vulkan:**
`vulkan-loader` *(Khronos ICD loader)*

**Firmware:**
`linux-firmware` *(GPU/WiFi blobs — amdgpu, i915, iwlwifi, ath, brcm)*

**NVIDIA proprietary:**
`nvidia` *(570.x, DKMS kernel module)*

> `mesa` — OpenGL + Vulkan dla AMD (`radeonsi`), Intel (`iris`/`intel`) i nouveau.

### Desktop environments

**KDE Plasma (minimal):**
`kde-minimal` *(meta)* · `plasma-workspace` `kwin` `konsole` `dolphin` `sddm`
`qt6-base` `qt6-declarative` `qt6-svg` `qt6-tools` `qt6-wayland`
`kauth` `kcolorscheme` `kconfig` `kcoreaddons` `kcrash` `kdbusaddons`
`kglobalaccel` `kguiaddons` `ki18n` `kiconthemes` `kio` `kjobwidgets`
`knotifications` `kpackage` `kservice` `ksyntaxhighlighting` `ktextwidgets`
`kwidgetsaddons` `kwindowsystem` `solid` `sonnet` `threadweaver`

**GNOME (minimal):**
`gnome-minimal` *(meta)* · `gnome-shell` `gnome-session` `gnome-terminal`
`nautilus` `mutter` `sddm`

> Both DEs use **SDDM** as login manager — GDM3 requires systemd which Flow Linux does not use.

### Window managers
`dwm` `qtile`

### Terminal emulators
`alacritty` `ghostty` `kitty` `wezterm`

### Browsers
`chromium` `zen-browser`

> `chromium` — deps include `gtk3` (not gtk4). Wayland support compiled in but not required (~250 SBU).
> `zen-browser` — Firefox fork, requires internet during build (downloads Firefox source via `surfer`).

### Media
`ffmpeg` `mpv` `libva` `libvpx` `x264`

### Windows compatibility
`wine` *(9.0, WineHQ — runs Windows .exe on Linux)* · `bottles` *(GUI Wine manager, GNOME/libadwaita)*
`cabextract` · `p7zip` · `xdg-utils`

> `wine` compiled with Wayland + Vulkan support.  
> `bottles` requires `wine` and auto-manages prefixes, DXVK, and Windows runtimes.

### Containers & virtualization
`docker` · `containerd` · `runc` · `docker-compose` · `podman` · `cgroupfs-mount`
`libseccomp` · `iptables`

> `docker` — INSTALL hook auto-registers OpenRC services and creates `docker` group.
> `podman` — daemonless, rootless container engine, Docker-compatible.

### Dev tools
`git` `neovim` `helix` `openssh` `rsync` `wget`

### System monitoring
`htop` `btop` `fastfetch` `neofetch`

### Modern CLI utilities
`bat` *(cat+highlight)* · `fd` *(find)* · `fzf` *(fuzzy finder)* · `jq` *(JSON)*
`ripgrep` *(grep)* · `zoxide` *(smart cd)* · `unzip`

### File managers (TUI)
`mc` *(Midnight Commander)* · `lf` · `ranger` · `nnn`

### Shell & prompt
`fish` `zsh` `starship`

> `fish` and `zsh` have `INSTALL` hooks that wire up WARP tab completions automatically.

### Editors & multiplexers
`vim` `neovim` `helix` `tmux` `zellij`

## Workspace

`pending/` — active build workspace. Packages under development go here before promotion to the main tree.

## Library Nodes (planned)

Future versions of WARP will implement **Library Nodes** — a dependency isolation system where each package gets its own node directory with symlinks to a central `libs/` store. Binaries get `RPATH` set to their node via `patchelf`. This eliminates dependency conflicts without the overhead of Flatpak or Nix.

## Flow Linux

Flow Linux = rolling packages on a stable base. Planned: numbered editions (Flow 1, 2, 3...) defining a frozen ABI contract, with rolling userspace packages on top.

Init system: **OpenRC** (not systemd).

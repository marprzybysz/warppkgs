# warppkgs — Flow Linux package repository

Package repository for the [WARP](https://github.com/marprzybysz/warp) package manager — the sole package manager for Flow Linux.

## Overview

184 packages organized into categories. Each package contains a `WARPBUILD` file with metadata and `build()` / `package()` functions. Some packages have `INSTALL` / `REMOVE` hooks for post-install automation.

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
`zlib` `zstd`

### Toolchain & build tools
Compilers, build systems, and language runtimes.

`clang` `cmake` `go` `meson` `ninja` `python3` `rust` `zig`
`cbindgen` `extra-cmake-modules` `nasm` `blueprint-compiler` `lua`

> `rust`, `go`, `zig` — distributed as pre-built binaries, no source compilation.

### Libraries
Shared libraries used across multiple packages.

**Graphics & UI:** `atk` `at-spi2-core` `cairo` `fontconfig` `freetype`
`gdk-pixbuf` `gtk3` `gtk4` `harfbuzz` `libadwaita` `libdrm` `libjpeg-turbo`
`libpng` `libva` `mesa` `pango` `pixman` `vte`

**System:** `dbus` `elogind` `glib` `libinput` `libevent` `libnl` `libndp`
`libsecret` `nss` `oniguruma` `polkit`

**X11/Wayland:** `libx11` `libxcb` `libxcomposite` `libxdamage` `libxext`
`libxfixes` `libxft` `libxinerama` `libxkbcommon` `libxrender` `wayland`
`wayland-protocols` `xcb-proto` `xcb-util` `xcb-util-cursor`
`xcb-util-keysyms` `xcb-util-wm` `xkeyboard-config`

### Audio
`alsa-lib` `pipewire` `wireplumber`

> `pipewire` built with `-Dsystemd=disabled` for OpenRC compatibility.

### Network
`curl` `iproute2` `networkmanager` `wpa_supplicant`

> `networkmanager` built with `-Dsession_tracking=elogind` for OpenRC.

### Display server
`xorg-server` `xorg-xinit` `xwayland`

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
`ffmpeg` `mpv`

### Shells
`fish` `zsh`

> Both have `INSTALL` hooks that wire up WARP tab completions automatically when installed.

### Editors & tools
`tmux` `vim`

## Workspace

`pending/` — active build workspace. Packages under development go here before promotion to the main tree.

## Library Nodes (planned)

Future versions of WARP will implement **Library Nodes** — a dependency isolation system where each package gets its own node directory with symlinks to a central `libs/` store. Binaries get `RPATH` set to their node via `patchelf`. This eliminates dependency conflicts without the overhead of Flatpak or Nix.

## Flow Linux

Flow Linux = rolling packages on a stable base. Planned: numbered editions (Flow 1, 2, 3...) defining a frozen ABI contract, with rolling userspace packages on top.

Init system: **OpenRC** (not systemd).

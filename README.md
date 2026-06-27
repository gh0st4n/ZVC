# ZVC - Zig Version Control

Tool sederhana untuk menginstall, mengelola, dan menggunakan berbagai versi Zig di sistem Linux dan macOS. Dibuat murni menggunakan POSIX `sh` - tanpa dependency tambahan selain `curl` atau `wget` dan `tar`.

```sh
sudo zvc -i 0.16.0
sudo zvc -s 0.16.0
zig version
```

## Fitur

- Install beberapa versi Zig secara bersamaan
- Deteksi arsitektur dan OS otomatis
- Support binary, source code, dan bootstrap tarball
- Support versi nightly (master)
- Set versi default sistem
- Gunakan versi tertentu secara sementara (per-session)
- Remove per-versi, per-variant, atau semua sekaligus
- Portabel: berjalan di semua arsitektur dan libc (glibc/musl)
- Tidak memerlukan Rust, Python, Node.js, atau runtime lainnya

## Dependency

| Dependency | Keterangan |
|--------------------|----------------------------------------|
| `sh`               | POSIX sh (dash, bash, busybox sh, dll) |
| `curl` atau `wget` | Salah satu wajib tersedia              |
| `tar`              | Untuk ekstraksi tarball                |

## Instalasi

```sh
git clone https://github.com/gh0st4n/ZVC
cd ZVC
sudo sh install.sh
```

Verifikasi:

```sh
zvc -v
```

Untuk menghapus ZVC dari sistem:

```sh
sudo sh uninstall.sh
```

## Penggunaan

### Install Zig

Install versi stabil — arch terdeteksi otomatis:

```sh
sudo zvc -i 0.16.0
```

Tentukan arch secara manual:

```sh
sudo zvc -i 0.16.0 aarch64
```

Install source code atau bootstrap:

```sh
sudo zvc -i 0.16.0 source
sudo zvc -i 0.16.0 bootstrap
```

Install versi nightly (master):

```sh
sudo zvc -i master
sudo zvc -i master source
sudo zvc -i master bootstrap
```

### Lihat Daftar Versi

Versi yang tersedia di ziglang.org:

```sh
zvc -l download
```

Output:
```
  VERSION      VARIANT        PLATFORM
  ──────────────────────────────────────────────────────────────────────────
  master        source         All (Zig Source Code)
  master        bootstrap      All (Zig Bootstrap)
  master        x86_64         Linux / MacOS / Windows / FreeBSD / NetBSD / OpenBSD
  master        aarch64        Linux / MacOS / Windows / FreeBSD / NetBSD / OpenBSD
  ...
```

Versi yang sudah terinstall di sistem:

```sh
zvc -l system
```

Output:
```
  NAME                                     PATH
  ────────────────────────────────────────────────────────────────────────
  zig-x86_64-linux-0.16.0                 /opt/zvc/zig-x86_64-linux-0.16.0
  zig-source-0.16.0                        /opt/zvc/zig-source-0.16.0
```

### Set Versi Default

Menjadikan versi tertentu sebagai `zig` default di seluruh sistem (`/usr/local/bin/zig`):

```sh
sudo zvc -s 0.16.0
sudo zvc -s master
```

Verifikasi:

```sh
zig version
```

Hapus default tanpa uninstall Zig-nya:

```sh
sudo zvc -d
```

### Gunakan Versi Tertentu (Sementara)

Aktifkan versi tertentu hanya untuk session terminal saat ini:

```sh
zvc -u 0.16.0
zvc -u master
```

Langsung jalankan perintah Zig dengan versi tertentu:

```sh
zvc -u 0.16.0 -- build
zvc -u 0.16.0 -- version
zvc -u master -- build -Doptimize=ReleaseSafe
```

Tentukan arch secara manual:

```sh
zvc -u 0.16.0 x86_64 -- build
```

### Remove Zig

Hapus semua Zig yang terinstall:

```sh
sudo zvc -r all
```

Hapus semua variant dari satu versi:

```sh
sudo zvc -r 0.16.0
sudo zvc -r master
sudo zvc -r source
sudo zvc -r bootstrap
```

Hapus satu variant spesifik:

```sh
sudo zvc -r 0.16.0 x86_64
sudo zvc -r 0.16.0 source
sudo zvc -r 0.16.0 bootstrap
```

## Struktur Direktori

```
/opt/zvc/
├── zig-x86_64-linux-0.16.0/        ← binary (x86_64, Linux, stable)
│   ├── zig
│   ├── lib/
│   └── ...
├── zig-aarch64-linux-0.16.0/       ← binary (aarch64, Linux, stable)
├── zig-source-0.16.0/              ← source code tarball
├── zig-bootstrap-0.16.0/           ← bootstrap tarball
└── zig-x86_64-linux-0.17.0-dev.956+2dca73595/  ← master/nightly
```

## Arsitektur yang Didukung

| `uname -m`         | Target Zig | OS |
|--------------------|---------------|-------------------------------------------------|
| `x86_64`           | `x86_64`      | Linux, macOS, Windows, FreeBSD, NetBSD, OpenBSD |
| `aarch64`          | `aarch64`     | Linux, macOS, Windows, FreeBSD, NetBSD, OpenBSD |
| `armv7l`, `armv6l` | `arm`         | Linux, FreeBSD, NetBSD, OpenBSD                 |
| `riscv64`          | `riscv64`     | Linux, FreeBSD, OpenBSD                         |
| `i386`, `i686`     | `x86`         | Linux, Windows, NetBSD                          |
| `loongarch64`      | `loongarch64` | Linux                                           |
| `s390x`            | `s390x`       | Linux                                           |

## Referensi Perintah

```
sudo zvc -i, --install <version> [arch]      Install Zig
zvc  -l, --list [download|system]            Tampilkan daftar Zig
sudo zvc -r, --remove <version|all> [arch]   Hapus Zig
zvc  -u, --use <version> [arch] [-- ...]     Gunakan versi tertentu (sementara)
sudo zvc -s, --set <version> [arch]          Set versi default sistem
sudo zvc -d, --disable                       Hapus symlink default
zvc  -h, --help                              Tampilkan bantuan
zvc  -v, --version                           Tampilkan versi ZVC
```

## Catatan

- `source` dan `bootstrap` tidak memiliki binary `zig` — keduanya digunakan untuk membangun Zig dari source, bukan untuk development langsung
- Versi `master` ter-install dengan nama folder yang menyertakan full version string (misal: `zig-x86_64-linux-0.17.0-dev.956+2dca73595`)
- Binary dari arsitektur berbeda tidak bisa dijalankan di mesin yang tidak kompatibel — ZVC akan memberikan error yang jelas
- Setelah `sudo zvc -d` atau `sudo zvc -r`, jalankan `hash -r` atau buka terminal baru untuk membersihkan cache shell

## Lisensi

MIT License — bebas digunakan, dimodifikasi, dan didistribusikan.

---

<div align="center">

[@T4n-Labs](https://t4n-labs.github.io/site) · [@Gh0sT4n](https://gh0st4n.github.io/site)

</div>

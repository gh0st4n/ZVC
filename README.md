# ZVC - Zig Version Control

Tool sederhana untuk menginstall, mengelola, dan menggunakan berbagai versi Zig di sistem Linux/macOS. Dibuat murni menggunakan POSIX `sh` — tanpa dependency tambahan selain `curl` atau `wget`.

## Fitur

- Install beberapa versi Zig secara bersamaan
- Deteksi arsitektur otomatis
- Set versi default sistem
- Gunakan versi tertentu secara sementara (per-session)
- Portabel: berjalan di semua arsitektur dan libc (glibc/musl)
- Tidak memerlukan Rust, Python, atau runtime lainnya

## Dependency

| Dependency         | Keterangan                             |
|--------------------|----------------------------------------|
| `sh`               | POSIX sh (dash, bash, busybox sh, dll) |
| `curl` atau `wget` | Salah satu wajib tersedia              |
| `tar`              | Untuk ekstraksi tarball                |

## Instalasi

**Auto with Script**
```sh
git clone https://github.com/gh0st4n/zvc
cd zvc
chmod +x *.sh
./install.sh
```

**Manual**
```sh
git clone https://github.com/gh0st4n/zvc
cd zvc
chmod +x *.sh
<package-manager [args install]> curl wget tar
sudo mkdir -p /opt/zvc
sudo mv zvc.sh /usr/local/bin/zvc
```

Setelah install, verifikasi:

```sh
zvc -v
```

## Penggunaan

### Install Zig

```sh
sudo zvc -i 0.13.0
```

Arch terdeteksi otomatis. Untuk menentukan arch secara manual:

```sh
sudo zvc -i 0.13.0 aarch64
```

### Lihat Daftar Versi

Versi yang tersedia di ziglang.org:

```sh
zvc -l download
```

Versi yang sudah terinstall di sistem:

```sh
zvc -l system
```

### Set Versi Default

Menjadikan versi tertentu sebagai `zig` default di seluruh sistem:

```sh
sudo zvc -s 0.13.0
```

Verifikasi:

```sh
zig version
```

### Gunakan Versi Tertentu (Sementara)

Aktifkan versi tertentu hanya untuk session terminal saat ini:

```sh
zvc -u 0.13.0
```

Atau langsung jalankan perintah Zig dengan versi tertentu:

```sh
zvc -u 0.13.0 x86_64 -- build
zvc -u 0.13.0 x86_64 -- version
```

### Hapus Versi

```sh
sudo zvc -r 0.13.0
```

## Struktur Direktori

```
/opt/zvc/
├── zig-linux-x86_64-0.13.0/
│   ├── zig
│   ├── lib/
│   └── ...
├── zig-linux-x86_64-0.12.0/
│   └── ...
└── zig-linux-aarch64-0.13.0/
    └── ...
```

## Arsitektur yang Didukung

| `uname -m`         | Target Zig    |
|--------------------|---------------|
| `x86_64`           | `x86_64`      |
| `aarch64`          | `aarch64`     |
| `armv7l`, `armv6l` | `arm`         |
| `riscv64`          | `riscv64`     |
| `i386`, `i686`     | `x86`         |
| `loongarch64`      | `loongarch64` |
| `s390x`            | `s390x`       |

## Referensi Perintah

```
zvc -i, --install <version> [arch]    Install Zig
zvc -l, --list [download|system]      Tampilkan daftar Zig
zvc -r, --remove <version> [arch]     Hapus Zig
zvc -u, --use <version> [arch]        Gunakan versi tertentu (sementara)
zvc -s, --set <version> [arch]        Set versi default sistem
zvc -h, --help                        Tampilkan bantuan
zvc -v, --version                     Tampilkan versi ZVC
```

## Lisensi

MIT License — bebas digunakan, dimodifikasi, dan didistribusikan.


---

<div align="center">

[@T4n-Labs](https://t4n-labs.github.io/site) · [@Gh0sT4n](https://gh0st4n.github.io/site)

</div>

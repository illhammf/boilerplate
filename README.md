<div align="center">

```text
 ___ _     _   _   __  __   ___      _ _                 _      _
|_ _| |   | | /_\ |  \/  | | _ ) ___(_) |___ _ _ _ __ _ | |__ _| |_ ___
 | || |__ | |/ _ \| |\/| | | _ \/ _ \ | / -_) '_| '_ \ '| / _` |  _/ -_)
|___|____||_/_/ \_\_|  |_| |___/\___/_|_\___|_| | .__/_||_\__,_|\__\___|
                                                 |_|
```

# 🚀 Laravel Boilerplate Pemrograman Web 2026

### Satu perintah → Laravel 12 + Filament + Docker + HTTPS + Repo GitHub. Siap ngoding. ⚡

![Laravel](https://img.shields.io/badge/Laravel-12-FF2D20?style=for-the-badge&logo=laravel&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-8.3-777BB4?style=for-the-badge&logo=php&logoColor=white)
![Filament](https://img.shields.io/badge/Filament-3.3-F59E0B?style=for-the-badge)
![MariaDB](https://img.shields.io/badge/MariaDB-10.11-003545?style=for-the-badge&logo=mariadb&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![WSL](https://img.shields.io/badge/WSL2-Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-Auto_Repo-181717?style=for-the-badge&logo=github)

</div>

---

## 📊 Repository Stats

| Statistik | Total |
|---|---:|
| 👀 Views | <!--VIEW_COUNT--> 0 
| 🙋 Unique Views | <!--UNIQUE_VIEWS--> 0 
| 📦 Clones | <!--CLONE_COUNT--> 0 
| 👤 Unique Clones | <!--UNIQUE_CLONE--> 0 
| ⭐ Stars | <!--STARS--> 0 
| 🍴 Forks | <!--FORKS--> 0 
| 🐞 Open Issues | <!--ISSUES--> 0 
<<<<<<< HEAD
| 🕒 Last Updated | <!--LAST_UPDATED--> 22 November 2026, 12:56 WIB 
=======
| 🕒 Last Updated | <!--LAST_UPDATED--> 22 November 2026 
>>>>>>> 0000416 (docs: update main readme)

---

## 📖 Daftar Isi

1. [Tentang & Quick Start](#-tentang--quick-start)
2. [Fitur Unggulan](#-fitur-unggulan)
3. [Arsitektur & Tech Stack](#-arsitektur--tech-stack)
4. [Persiapan Awal (Sekali Saja)](#-persiapan-awal-sekali-saja)
5. [Cara Pakai `start.sh`](#-cara-pakai-startsh)
6. [Di Balik Layar: Kenapa Dibuat Begini?](#-di-balik-layar-kenapa-dibuat-begini)
7. [Struktur Boilerplate & Hasil Proyek](#-struktur-boilerplate--hasil-proyek)
8. [Shortcut Command](#-shortcut-command)
9. [Alur Membuat Fitur CRUD](#-alur-membuat-fitur-crud)
10. [Database & Xdebug](#-database--xdebug)
11. [Troubleshooting](#-troubleshooting)
12. [FAQ](#-faq)
13. [Keamanan](#-keamanan)
14. [Pengguna macOS](#-pengguna-macos)

---

## 💡 Tentang & Quick Start

Boilerplate ini dibuat untuk praktikum Web Development berbasis Laravel. Idenya sederhana: **kamu tidak perlu lagi setup manual**. Satu perintah `./start.sh nama_proyek` akan menyiapkan folder proyek, sertifikat HTTPS, kontainer Docker, dependensi Composer, database, repository GitHub, sampai membuka VS Code. Kalau ada tahap yang gagal, kamu diberi tahu tahap mana dan cara memperbaikinya, bukan sekadar error misterius.

### ⚡ Quick Start (kalau persiapan awal sudah beres)

```bash
cd ~/boilerplate
./start.sh nama_proyek
```

Lalu jawab beberapa pertanyaan yang muncul, buka `https://nama_proyek.test/admin`, dan mulai ngoding. 🤩

> Belum pernah setup? Mulai dari [Persiapan Awal](#-persiapan-awal-sekali-saja).

---

## ✨ Fitur Unggulan

| | Fitur | Penjelasan |
|---|---|---|
| 🐳 | **Docker siap pakai** | Nginx, PHP 8.3-FPM, dan MariaDB 10.11 di kontainer terpisah |
| 🔒 | **HTTPS lokal otomatis** | Sertifikat dibuat `mkcert`, jadi `https://nama_proyek.test` tidak muncul peringatan |
| 🧰 | **Laravel 12 + Filament 3.3** | Panel admin di `/admin`, sudah termasuk Shield (role & permission) dan Logger (jejak aktivitas) |
| 📦 | **Composer dengan retry** | Dependensi dipasang sebelum kontainer menyala, diulang sampai 3 kali jika jaringan lambat |
| ⏳ | **Menunggu sampai benar-benar siap** | Script memantau web dan `APP_KEY` (maks. 300 detik), bukan sekadar menyalakan kontainer lalu pergi |
| 🛟 | **DNS cadangan (DoH)** | DNS WSL macet? Script beralih ke DNS-over-HTTPS Cloudflare (`1.1.1.1`) untuk GitHub |
| 🐙 | **Repo GitHub otomatis** | Token diverifikasi, repo dibuat, commit awal, lalu push, semua tanpa buka browser |
| 📝 | **README proyek otomatis** | Setiap proyek langsung punya `README.md` berisi URL, panduan tim, dan troubleshooting |
| 🩺 | **Status per tahap** | Ringkasan akhir menampilkan ✅ / ⏳ / ❌ / ✍️ untuk Hosts, Docker, Composer, Web, Repo, dan Push |
| ⚡ | **Shortcut command** | `dcu` `dcd` `dca` `dci` `dcm` `dcf` `dcr` `dcp` |
| 🐞 | **Xdebug tinggal toggle** | Ubah `XDEBUG=true` di `.env`, lalu `dcu` |

---

## 🧱 Arsitektur & Tech Stack

```text
 Browser (Windows)
      │  https://nama_proyek.test
      ▼
 ┌───────────────────────── Docker Compose ─────────────────────────┐
 │                                                                  │
 │   ┌─────────┐  fastcgi   ┌───────────┐   SQL    ┌─────────────┐  │
 │   │  Nginx  │ ─────────▶ │  PHP-FPM  │ ───────▶ │   MariaDB   │  │
 │   │ 80/443  │            │   8.3     │          │ 10.11 :13306│  │
 │   └─────────┘            └─────┬─────┘          └─────────────┘  │
 │                                │                                 │
 │                  volume: ./src (kode Laravel)                    │
 └──────────────────────────────────────────────────────────────────┘
```

| Komponen | Detail |
|---|---|
| Framework | Laravel 12 |
| Bahasa | PHP 8.3 (FPM) |
| Panel Admin | Filament 3.3 (`fila-starter`: Shield + Logger) |
| Database | MariaDB 10.11, port host `13306` |
| Web Server | Nginx + HTTPS (`mkcert`), upload besar hingga 20 MB |
| Container | Docker & Docker Compose v2 |
| Lingkungan | WSL2 (Ubuntu) + Visual Studio Code |
| Version Control | Git & GitHub |
| Locale bawaan | `APP_LOCALE=id` |

---

# 🛠️ Persiapan Awal (Sekali Saja)

> Bagian ini cukup dikerjakan **satu kali** per komputer. Baca pelan-pelan dan jangan terburu-buru. 🙏

### 🚫 Peringatan Wajib Baca

- ❌ Jangan pakai jaringan Esa Unggul (WiFi/LAN)
- 📶 Pastikan jaringan stabil dan tidak lag
- 💾 Siapkan kuota yang banyak karena akan download banyak hal
- 🛠️ Pastikan sudah memasang **Visual Studio Code**, **Docker Desktop**, dan **Navicat v17** dari Djambred
- ⚠️ **Satu proyek saja yang boleh aktif** karena port 80/443 dipakai bergantian. Matikan proyek lain dengan `dcd` sebelum menyalakan yang baru.

### 🌐 Tools Perkuliahan

1. WSL
2. Docker (https://www.docker.com)
3. Navicat (https://shared.djncloud.my.id/tools_tempur/)
4. VSCode (https://code.visualstudio.com/download)
5. GitHub (https://github.com)
6. VPS (sewa 3 bulan)
7. Domain (sewa 1 tahun)
8. Cloudflared (https://www.cloudflare.com)

---

### 1️⃣ Install WSL

1. Buka **Settings → System → Optional Features**
2. Klik **More Windows Features**
3. Centang **Virtual Machine Platform** dan **Windows Subsystem for Linux**
4. Restart komputer
5. Install **Ubuntu** dari Microsoft Store

### 2️⃣ Set WSL ke WSL2

Buka **PowerShell (Run as Administrator)**:

```sh
wsl --set-default-version 2
```

### 3️⃣ Konfigurasi WSL (WAJIB)

```sh
nano /etc/wsl.conf
```

Isi dengan (salin semua):

```ini
[network]
generateResolvConf=false
generateHosts=false
hostname=DemoHost

[boot]
systemd=true
command=service docker start

[user]
default=root

[automount]
enabled=true
root=/
options="metadata,uid=1003,gid=1003,umask=077,fmask=11,case=off"
mountFsTab=true

[interop]
enabled=true
appendWindowsPath=true
```

Referensi: https://learn.microsoft.com/en-us/windows/wsl/wsl-config#configure-global-options-with-wslconfig

Lalu restart WSL dari **PowerShell (bukan dari WSL!)**:

```sh
wsl --shutdown
```

<details>
<summary>🔎 <b>Kenapa konfigurasinya begini?</b></summary>

| Baris | Fungsinya |
|---|---|
| `default=root` | Proyek dibuat di `/root/perkuliahan/...` dan script berjalan sebagai root |
| `generateHosts=false` | File `/etc/hosts` tidak ditimpa tiap WSL restart, jadi domain `.test` tidak hilang |
| `root=/` | Drive Windows muncul sebagai `/c`, bukan `/mnt/c`. Script mendeteksi keduanya untuk mengedit hosts Windows |
| `interop` + `appendWindowsPath` | WSL bisa memanggil `powershell.exe` dan `code` milik Windows |

</details>

### 4️⃣ Install Dependencies

Buka WSL lagi, lalu jalankan:

```bash
apt update && apt upgrade -y
apt install git curl sed netcat-openbsd mkcert -y
apt install python3 python3-pip default-jdk plantuml jq -y
mkcert -install
```

> `start.sh` memeriksa dulu: `git docker mkcert code nc curl sed` dan `docker compose` (v2). Kalau ada yang kurang, script berhenti dan memberi tahu apa yang hilang.

### 5️⃣ Setup ZSH (Opsional, biar ganteng 😎)

```bash
apt install zsh -y
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
nano ~/.zshrc
```

Ubah `plugins=(git)` menjadi:

```sh
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
```

```sh
source ~/.zshrc
```

### 6️⃣ Identitas Git (jangan dilewat!)

Commit awal butuh nama dan email. Tanpa ini, commit gagal dan push tidak jalan.

```bash
git config --global user.name "Nama Kamu"
git config --global user.email "emailkamu@gmail.com"
```

### 7️⃣ Setup GitHub SSH

```bash
ssh-keygen -t rsa -b 4096 -C "emailkamu@gmail.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub
```

Login GitHub → **Settings → SSH and GPG Keys → New SSH Key** → tempel hasilnya. Lalu tes:

```sh
ssh -T git@github.com
```

Kalau muncul `Hi (username kamu)!`, berarti berhasil ✅

### 8️⃣ Clone Boilerplate

```bash
cd ~
git clone https://github.com/illhammf/boilerplate.git
cd boilerplate
```

### 9️⃣ Setup GitHub Token

Buka https://github.com/settings/tokens → **Generate new token (classic)**:

- Nama: `INITSCRIPT`
- Expiration: **No expiration**
- Scope: `repo` (**wajib**), `user`, dan `delete_repo` (opsional)

Simpan ke file di dalam folder `~/boilerplate`:

```sh
nano .github-token     # isi: token kamu
nano .github-user      # isi: username GitHub kamu
```

> 💡 Cukup sekali. Script membaca file ini otomatis, memverifikasinya ke GitHub, dan mengisi `.github-user` sendiri dari pemilik token. File token juga diatur ke mode `600` (hanya bisa dibaca pemilik).
> 🚨 **Jangan upload kedua file ini ke GitHub!**

---

# 🚀 Cara Pakai `start.sh`

```bash
cd ~/boilerplate
./start.sh nama_proyek
```

### Aturan nama proyek

Nama otomatis dirapikan: huruf kecil, spasi dan `_` menjadi `-`, karakter selain huruf, angka, dan `-` dibuang.

| Kamu ketik | Menjadi | Domain |
|---|---|---|
| `Desa_Bojong` | `desa-bojong` | `https://desa-bojong.test` |
| `Toko Online 2` | `toko-online-2` | `https://toko-online-2.test` |

Folder tujuan: `/root/perkuliahan/<nama>`. Kalau folder itu sudah ada, script berhenti supaya tidak menimpa proyek lama.

### 🗺️ Alur Lengkap

```text
./start.sh nama_proyek
   │
   ├─ 1. 🔍 Cek dependensi (git, docker, mkcert, code, nc, curl, sed, docker compose)
   ├─ 2. 📁 Buat folder + salin template (db, nginx, php, src Laravel)
   ├─ 3. 🔐 Buat sertifikat HTTPS dengan mkcert
   ├─ 4. 📄 Render konfigurasi: nginx, .env, .env.example, .gitignore, docker-compose.yml
   ├─ 5. ⚙️  Perbarui alias di ~/.zshrc (blok lama diganti, cadangan: ~/.zshrc.bak)
   ├─ 6. 🌐 Daftarkan domain ke hosts WSL dan Windows   ← pop-up UAC muncul di sini
   ├─ 7. 🐳 Build image → composer install → nyalakan kontainer → tunggu sampai siap
   ├─ 8. 🐙 (opsional) Verifikasi token → buat repo GitHub
   ├─ 9. 📝 Buat README.md proyek → commit awal → push
   └─ 10. 🧠 Buka VS Code → tampilkan ringkasan → muat ulang Zsh
```

### 💬 Pertanyaan yang Akan Muncul

| Urutan | Muncul | Yang perlu dilakukan |
|---|---|---|
| 1 | **Pop-up UAC Windows** (tahap hosts) | Klik **Yes**. Ini izin mengedit `C:\Windows\System32\drivers\etc\hosts`. Perhatikan desktop-mu, pop-up kadang muncul di belakang jendela lain |
| 2 | `Mulai proyek dengan Docker Compose sekarang? (y/n)` | `y` untuk langsung build dan jalan. `n` kalau hanya mau menyiapkan file |
| 3 | `Mau buat repositori GitHub untuk proyek ini? (y/n)` | `y` untuk buat repo otomatis |
| 4 | `Jadikan repositori private? (Y/n)` | Enter = private. `n` = public |
| 5 | Input token (hanya jika tersimpan tidak ada/ditolak) | Tempel token baru (input disembunyikan, maksimal 3 kali coba) |

> ⏳ Build pertama biasanya **5–20 menit**. Itu normal, tunggu saja.
> ⚠️ Selama tahap "Menunggu aplikasi siap", **jangan jalankan** `docker compose restart php`.

### ✅ Kalau Berhasil

Kamu akan melihat kontainer berjalan:

```text
[+] up 3/3
 ✔ Container nama_proyek_db    Healthy
 ✔ Container nama_proyek_php   Started
 ✔ Container nama_proyek_nginx Started
```

Lalu ringkasan akhir berisi alamat aplikasi, kredensial database, status tiap tahap, dan langkah selanjutnya.

| Alamat | Fungsi |
|---|---|
| `https://nama_proyek.test` | Website |
| `https://nama_proyek.test/admin` | Panel Filament |

### 🩺 Arti Status di Ringkasan Akhir

| Badge | Arti | Tindakan |
|---|---|---|
| ✅ Berhasil | Tahap selesai | Tidak ada |
| ⏳ Masih berproses | Kontainer jalan tapi aplikasi belum merespons (mungkin masih migrate) | `docker compose logs -f php`, tunggu `Ready to serve!` |
| ❌ Gagal | Tahap gagal, proyek lokal tetap jadi | Lihat pesan di terminal, lalu [Troubleshooting](#-troubleshooting) |
| ✍️ Perlu manual | Hosts Windows tidak bisa diubah otomatis (UAC ditolak atau PowerShell tidak terdeteksi) | Tambahkan `127.0.0.1 nama_proyek.test` ke hosts Windows |
| ➖ Dilewati | Kamu memilih `n` pada tahap itu | Tidak ada |

### 🔄 Pindah Proyek

```sh
dcd    # matikan proyek yang aktif
cd /root/perkuliahan/proyek_lain
dcu    # nyalakan proyek tujuan
```

### 💻 Buka di VS Code

```sh
cd /root/perkuliahan/nama_proyek
code .
```

Pastikan extension **WSL** sudah terpasang di VS Code.

---

# 🧠 Di Balik Layar: Kenapa Dibuat Begini?

Beberapa keputusan di `start.sh` lahir dari error yang benar-benar terjadi saat dipakai. Ini alasannya:

| Keputusan | Masalah yang dipecahkan |
|---|---|
| **`composer install` dijalankan `start.sh` sebelum kontainer PHP menyala** | Dulu composer berjalan di entrypoint. Kalau terpotong (misalnya karena `docker compose restart php`), folder `vendor/` tertinggal setengah jadi tanpa `autoload.php`, lalu `artisan` error, `APP_KEY` kosong, dan muncul **502 Bad Gateway**. Sekarang kontainer baru menyala setelah `vendor/` lengkap, dan progresnya terlihat di terminal |
| **Composer di-retry 3 kali** | DNS atau internet WSL sering lambat. Sisa `vendor/` dibuang tiap percobaan agar tidak ada file separuh jadi |
| **`wait_until_ready` memantau `/admin/login` + `APP_KEY`** | "Kontainer jalan" belum berarti aplikasi siap. Script menunggu respons HTTP 200/301/302 *dan* `APP_KEY` terisi. Kalau kontainer PHP mati di tengah jalan, 30 baris log terakhir langsung ditampilkan |
| **Cek memakai `--resolve` ke `127.0.0.1`** | Pengecekan tidak bergantung pada file hosts, jadi hasilnya jujur walau hosts Windows belum diubah |
| **Token GitHub diverifikasi dulu (`GET /user`)** | Token salah, kedaluwarsa, atau tanpa scope `repo` ketahuan di awal, bukan setelah semua selesai |
| **File token tidak dihapus saat 401** | Kamu bisa memperbaikinya dengan `nano`, atau memasukkan token baru di run yang sama (maksimal 3 kali) |
| **Username diambil dari pemilik token** | Tidak mungkin salah ketik. Kalau beda dengan `.github-user`, script memakai yang benar dan memberi peringatan |
| **DNS cadangan DoH (`1.1.1.1`)** | Saat DNS WSL macet (`Resolving timed out`), IP `api.github.com` dan `github.com` diambil lewat HTTPS ke Cloudflare lalu dipakai langsung |
| **Push dengan 2 jalur** | Jalur 1: `git push` biasa. Jalur 2: memakai token lewat header sementara, tidak tersimpan di `.git/config` maupun URL remote |
| **Gagal di satu tahap ≠ batal semua** | GitHub atau push gagal? Proyek lokal tetap jadi dan status akhirnya jelas |
| **`.env` root tidak di-commit** | Isinya nilai lokal. Yang di-commit adalah `.env.example`, jadi anggota tim cukup `cp .env.example .env` |
| **Repo bernama `<proyek>-<tahun>`** | Contoh: `desa-bojong-2026`, supaya proyek tiap tahun tidak bentrok |

---

# 🗂️ Struktur Boilerplate & Hasil Proyek

### Isi folder boilerplate

```text
~/boilerplate/
├── start.sh                 # generator utama (Linux/WSL)
├── start_mac.sh             # versi macOS
├── .github-token            # token GitHub   ← JANGAN di-commit
├── .github-user             # username GitHub ← JANGAN di-commit
└── template/                # bahan dasar tiap proyek
    ├── db/                  # my.cnf
    ├── nginx/               # Dockerfile, default.conf.template
    ├── php/                 # Dockerfile, www.conf, local.ini, docker-entrypoint.sh.template
    └── src/                 # template Laravel 12 + Filament
```

### Hasil proyek yang dibuat

```text
/root/perkuliahan/nama_proyek/
├── db/
│   ├── conf.d/              # konfigurasi MariaDB
│   └── data/                # data database (otomatis, tidak di-commit)
├── nginx/
│   ├── default.conf         # hasil render domain proyek
│   └── ssl/                 # sertifikat mkcert (tidak di-commit)
├── php/                     # Dockerfile, entrypoint, konfigurasi PHP
├── src/                     # aplikasi Laravel + Filament
├── .env                     # untuk Docker Compose (tidak di-commit)
├── .env.example             # contoh .env (di-commit)
├── .gitignore
├── docker-compose.yml
└── README.md                # dibuat otomatis
```

> `src/.env` (milik Laravel) dibuat otomatis oleh entrypoint saat kontainer pertama menyala, lengkap dengan `APP_KEY` dan migrate.

---

# ⚡ Shortcut Command

Alias dipasang otomatis ke `~/.zshrc` setiap kali `start.sh` dijalankan. Untuk mengaktifkannya di terminal yang sedang terbuka:

```sh
source /root/.zshrc
```

| Perintah | Fungsi | Contoh |
|---|---|---|
| `dcu` | Nyalakan kontainer (`docker compose up -d`) | `dcu` |
| `dcd` | Matikan kontainer **proyek ini** | `dcd` |
| `dca <perintah>` | Menjalankan `php artisan` di kontainer PHP | `dca migrate` |
| `dci` | Menjalankan `php artisan project:init` | `dci` |
| `dcm <Model>` | Buat **model + migration + seeder + controller** | `dcm Produk` |
| `dcf <Model>` | Buat **Filament resource** dari kolom tabel (jalankan setelah `dca migrate`) | `dcf Produk` |
| `dcr <Model>` | ⚠️ **Hapus** semua file milik Model (ada konfirmasi y/n) | `dcr Produk` |
| `dcp "pesan"` | `git add` → `commit` → `pull --rebase` → `push` | `dcp "tambah fitur produk"` |

<details>
<summary>🔎 <b>Penjelasan tiap perintah</b></summary>

- **`dcu`** harus dijalankan dari folder proyek (ia membaca `docker-compose.yml` di folder itu).
- **`dca`, `dci`, `dcm`, `dcf`, `dcd`** mencari kontainer PHP proyek dari `COMPOSE_PROJECT_NAME` di `.env`. Kalau tidak ketemu, memakai kontainer `*_php` pertama yang berjalan. Kalau tidak ada yang berjalan, muncul pesan agar kamu menjalankan `dcu` dulu.
- **`dcm`** sengaja tidak membuat Filament resource, karena opsi `--generate` butuh tabel yang sudah dimigrasi. Karena itu setelah `dcm` ada petunjuk langkah berikutnya.
- **`dcr`** menghitung nama tabel dengan aturan Laravel (`Str::plural`), lalu menghapus model, controller, seeder, policy, migration `*_create_<tabel>_table.php`, serta resource Filament. **Kalau migration-nya sudah dijalankan, rollback dulu** dengan `dca migrate:rollback`.
- **`dcp`** memakai `git pull origin main --rebase` sebelum push untuk menghindari konflik riwayat. Script mengasumsikan cabang `main`. Kalau tidak ada perubahan, tidak ada commit yang dibuat.

</details>

---

# 🔁 Alur Membuat Fitur CRUD

```text
dcm Produk      →  buat model + migration + seeder + controller
(isi kolom di src/database/migrations/..._create_produks_table.php)
dca migrate     →  buat tabel di database
dcf Produk      →  buat Filament resource (form & tabel dibaca dari kolom database)
dcp "fitur produk"   →  simpan ke GitHub
```

Tips:
- Nama tabel tidak mengikuti aturan jamak bahasa Inggris? Tulis eksplisit di model: `protected $table = 'nama_tabel';`
- Upload file: gunakan validasi `mimes:jpg,jpeg,png,pdf|max:5120` (5 MB).
- Dokumen pribadi (KTP, KK, dan sejenisnya) simpan di disk **privat**, bukan `public`.
- Salah buat? `dcr Produk` untuk menghapus semua file-nya.

---

# 🗄️ Database & Xdebug

### Koneksi Navicat / DBeaver

| Kolom | Isi |
|---|---|
| Host | `127.0.0.1` |
| Port | `13306` |
| User | `root` |
| Password | `p455w0rd` |
| Database | nama proyek (contoh: `desa-bojong`) |

Database dibuat otomatis saat kontainer pertama menyala, dan datanya tersimpan di `db/data/` (tidak di-commit).

### Mengaktifkan Xdebug

Edit `.env` di root proyek:

```env
XDEBUG=true
```

Lalu terapkan:

```sh
dcu
```

---

# 🩺 Troubleshooting

<details>
<summary>❌ <b>502 Bad Gateway</b> atau <code>APP_KEY</code> kosong</summary>

PHP belum siap atau `vendor/` tidak lengkap.

```bash
docker compose logs -f php          # tunggu "Ready to serve!"
ls src/vendor/autoload.php          # harus ada
grep APP_KEY src/.env               # harus berisi base64:...
```

Kalau `vendor/autoload.php` tidak ada:

```bash
docker compose stop php
rm -rf src/vendor
docker compose run --rm --no-deps -w /var/www/html --entrypoint composer php install
docker compose up -d
```

</details>

<details>
<summary>❌ <b><code>docker compose ps</code> kosong / port 80, 443, 13306 bentrok</b></summary>

Kontainer mati karena proyek lain sedang memakai port yang sama. Hanya satu proyek yang boleh aktif.

```bash
cd /root/perkuliahan/proyek_lain && dcd
cd /root/perkuliahan/nama_proyek && dcu
```

</details>

<details>
<summary>❌ <b>Composer gagal 3 kali</b></summary>

Biasanya DNS atau internet WSL lambat. Cek koneksi:

```bash
curl -I https://repo.packagist.org
```

Lalu ulangi dari folder proyek:

```bash
docker compose run --rm --no-deps -w /var/www/html --entrypoint composer php install
```

</details>

<details>
<summary>❌ <b>Token GitHub ditolak (401) atau tanpa scope <code>repo</code></b></summary>

Buat ulang token classic dengan scope `repo`, lalu perbarui:

```bash
nano ~/boilerplate/.github-token
```

Script juga bisa langsung meminta token baru di run yang sama (maksimal 3 kali).

</details>

<details>
<summary>❌ <b>Tidak ada koneksi ke api.github.com / <code>Resolving timed out</code></b></summary>

Itu masalah koneksi atau DNS, bukan token. Script otomatis mencoba DNS cadangan (DoH). Kalau tetap gagal, perbaiki internet-nya lalu pilih **Coba lagi**. Cek bahwa patch DoH terpasang di scriptmu:

```bash
grep -c "_doh_resolve" ~/boilerplate/start.sh    # harus lebih dari 0
```

</details>

<details>
<summary>❌ <b>Commit awal gagal</b></summary>

Identitas Git belum diset:

```bash
git config --global user.name "Nama Kamu"
git config --global user.email "emailkamu@gmail.com"
git commit -m "🎉 Initial commit"
```

</details>

<details>
<summary>❌ <b><code>git push</code> gagal</b></summary>

```bash
git push -u origin main
```

Kalau repo dengan nama itu sudah ada dan berisi commit lain, push akan ditolak. Hapus repo lama di GitHub, atau gunakan nama proyek lain.

</details>

<details>
<summary>✍️ <b>Hosts Windows "Perlu manual"</b></summary>

UAC ditolak atau PowerShell tidak terdeteksi. Buka **Notepad sebagai Administrator**, buka `C:\Windows\System32\drivers\etc\hosts`, lalu tambahkan:

```text
127.0.0.1 nama_proyek.test
```

</details>

<details>
<summary>❌ <b><code>mkcert</code> tidak ditemukan / sertifikat tidak dipercaya browser</b></summary>

```bash
apt install mkcert -y
mkcert -install
```

Setelah itu restart browser.

</details>

<details>
<summary>❌ <b>Docker tidak jalan / build lama</b></summary>

Pastikan **Docker Desktop aktif**. Build pertama normalnya 5–20 menit, tunggu saja.

</details>

<details>
<summary>❌ <b>Perintah <code>code</code> tidak ditemukan</b></summary>

`start.sh` mewajibkan perintah `code`. Jalankan:

```sh
ls / | grep -E '^c$|^d$'
```

Kalau muncul `c`:

```sh
ls "/c/Program Files" | grep -i "code\|vs"
find "/c/Program Files" -maxdepth 3 \( -iname "code" -o -iname "code.cmd" -o -iname "Code.exe" \) 2>/dev/null
```

Kalau `cmd.exe` tidak terbaca dari PATH, panggil langsung:

```sh
"/c/Windows/System32/cmd.exe" /c "where code"
ls "/c/Windows/System32/cmd.exe"
```

Kalau file itu ada, berarti interop Windows ada dan hanya PATH-nya yang belum terbaca.

Kalau `find` menemukan, misalnya:

```text
/c/Program Files/VSCode-win32-x64-1.112.0/bin/code
```
atau
```text
/c/Program Files/Microsoft VS Code/bin/code
```

maka isi `~/.zshrc` harus memakai **`/c/...`, bukan `/mnt/c/...`** (karena `root=/` di `wsl.conf`):

```sh
export PATH="$PATH:/c/Program Files/VSCode-win32-x64-1.112.0/bin"
```

Lalu:

```sh
source ~/.zshrc
hash -r
which code
code .
```

</details>

---

# ❓ FAQ

**Boleh membuat banyak proyek?**
Boleh, tapi hanya satu yang boleh menyala dalam satu waktu (port 80/443 dan 13306). Pindah dengan `dcd` lalu `dcu`.

**Apakah script aman dijalankan ulang?**
Nama proyek yang sudah ada ditolak (folder tidak ditimpa). Blok alias di `~/.zshrc` selalu diganti, bukan ditambah dobel, dan cadangannya tersimpan di `~/.zshrc.bak`.

**Aku pilih "n" waktu ditanya Docker. Apa yang terjadi?**
File proyek tetap dibuat. Nyalakan nanti dengan `docker compose up -d --build` dari folder proyek.

**Bagaimana kalau teman satu tim mau menjalankan proyekku?**
README di setiap proyek (dibuat otomatis) berisi langkah lengkapnya: clone, `cp .env.example .env`, buat sertifikat, daftarkan domain, build, lalu jalankan.

**Password database kok sederhana?**
Itu hanya untuk lingkungan lokal. Jangan dipakai di server produksi.

---

# 🔐 Keamanan

- `.github-token` dan `.github-user` **tidak boleh** di-commit. Tambahkan keduanya ke `.gitignore` boilerplate jika belum.
- Jangan bagikan token ke siapa pun. Kalau bocor, hapus di GitHub dan buat yang baru.
- Pilih **private** saat membuat repo jika proyek berisi data sensitif.
- Jangan commit data pribadi atau file upload pengguna.
- Kredensial database bawaan hanya untuk lokal.

---

# 🍎 Pengguna macOS

```sh
./start_mac.sh
```

---

<div align="center">

### 🥳 Sampai sini berarti setup-mu sudah selesai!

**Tinggal ngoding, gasss!** 💻🔥

> "Konsistensi Mengalahkan Bakat Saat Bakat Tidak Muncul."

Dibuat dengan ❤️ oleh **Ilham** · Pemrograman Web 2026

</div>
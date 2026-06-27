<div align="center">

# Laravel Boilerplate Pemrograman Web 2026

### Starter Kit Laravel + Blade + Docker + WSL + GitHub

![Laravel](https://img.shields.io/badge/Laravel-Framework-red?style=for-the-badge&logo=laravel)
![PHP](https://img.shields.io/badge/PHP-Backend-777BB4?style=for-the-badge&logo=php)
![Docker](https://img.shields.io/badge/Docker-Container-2496ED?style=for-the-badge&logo=docker)
![WSL](https://img.shields.io/badge/WSL-Ubuntu-E95420?style=for-the-badge&logo=ubuntu)
![GitHub](https://img.shields.io/badge/GitHub-Version_Control-181717?style=for-the-badge&logo=github)

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
| 🕒 Last Updated | <!--LAST_UPDATED--> 27 June 2026, 10:54 WIB 

---

## Tentang Boilerplate Ini

Repository ini digunakan sebagai starter project untuk praktikum Web Development berbasis Laravel. <br> 
Di dalamnya sudah mendukung setup WSL, Docker, GitHub, Laravel, Blade, dan shortcut command agar proses ngoding lebih cepat.

---

# SETUP PEMROGRAMAN WEB 2026 (WSL + GITHUB + DOCKER)

---

Tolong dibaca dengan cermat dan teliti agar tidak terjadi kesalahan dalam Instalasi/Setup. <br>
Jangan terlalu terburu-buru dan silahkan ikutin tahapannya. <br>
Semangattt!

## Deskripsi

Tutorial ini menjelaskan langkah-langkah setup environment Mata Kuliah Web Development menggunakan:

- WSL (Linux di Windows)
- Visual Studio Code System
- Docker (Container)
- GitHub (Version Control)
- Laravel (Framework PHP)

---

## 🚫 PERINGATAN WAJIB BACA!!!

- Jangan pakai jaringan Esa Unggul (Wifi/LAN)
- Pastikan Jaringan kamu stabil dan tidak LAG
- Siapkan Kuota yang banyak karena akan download banyak hal
- Sudah menginstall Visual Studio Code System, Docker, Navicat v17 dari Djambred

## 🌐 TOOLS PERKULIAHAN
1. WSL
2. Docker (https://www.docker.com)
3. Navicat (https://shared.djncloud.my.id/tools_tempur/)
4. VSCode (https://code.visualstudio.com/download)
5. Github (https://github.com)
6. VPS (sewa 3 bulan)
7. Domain (sewa 1 tahun)
8. Cloudflared (https://www.cloudflare.com)

---

kalo sudah SIAP, kita gass lanjut ke tahapannya hehe 😁

---

## 1. Install WSL

### Langkah:

1. Buka **Settings → System → Optional Features**
2. Klik **More Windows Features**
3. Centang:
   - Virtual Machine Platform
   - Windows Subsystem for Linux
4. Restart komputer

### Install Ubuntu

- **Install Ubuntu dari Microsoft Store**

---

## 2. Set WSL ke WSL2 & ROOT

Buka **PowerShell** (Run as Administrator):

```sh
wsl --set-default-version 2
```

---

## 3. Konfigurasi WSL (WAJIB)

**Edit file:**

```sh
nano /etc/wsl.conf
```

nanti sekalian ganti jika kamu masih **user**, ganti jadi **root**

**Isi konfigurasi (copy semua dan masukkan kedalamnya):**

```bash
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

atau bisa didapatkan dari: <br>
https://learn.microsoft.com/en-us/windows/wsl/wsl-config#configure-global-options-with-wslconfig

**lalu Restart WSL:**
Jalankan ini di PowerShell, **jangan di WSL!!!**

```sh
wsl --shutdown
```

---

## 4. Install Dependencies

### Buka WSL lagi

jalankan:
_bisa langsung semua ataupun satu per satu_
```bash
apt update && apt upgrade -y
apt install git -y
apt install python3 python3-pip -y
apt install default-jdk -y
apt install plantuml -y
apt install jq -y
```

---

## 5. Setup ZSH (Optional biar Ganteng)

### ZSH
```bash
apt install zsh -y
```

### oh my Zsh
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

**Install plugin:**

```bash
git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
```

**Edit config:**

```sh
nano ~/.zshrc
```

**Cari dan ubah Ubah:**

```sh
plugins=(git)
```

Menjadi:

```sh
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
```

**Reload:**

```sh
source ~/.zshrc
```

---

## 6. Setup GitHub SSH

Jalankan:
_bisa langsung semua ataupun satu per satu_
```bash
ssh-keygen -t rsa -b 4096 -C "emailkamu@gmail.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub
```

Tambahkan ke GitHub:
_Login Github dulu_

Klik
**Settings → SSH Keys → Add New Key**
masukkan SSH key nya

**Test koneksi:**

```sh
ssh -T git@github.com
```

Kalo sudah muncul Hi (username Github Kamu), berarti sudah Berhasil dan gas lanjut

---

## 7. Clone Repository

```bash
cd ~
git clone https://github.com/illhammf/boilerplate.git
cd boilerplate
```

---

## 8. Setup GitHub Token

Buka:
https://github.com/settings/tokens

atau klik <br>
Settings - Developer Settings - Personal Access Tokens - Tokens (classic)

Buat Token Baru (Generate new token):

```sh
Token Classic
kasih nama INITSCRIPT
No expiration (tidak ada kadaluarsa)
```

Lalu Centang:
- repo
- user
- delete_repo

**Simpan ke file:**

_Jalankan ini satu-satu_
```sh
nano .github-token
nano .github-user
```
**Isi:**

```sh
.github-token → token
.github-user → username GitHub kamu
```

**Jangan upload file ini ke GitHub!**

---

## 9. Jalankan Project

masuk ke dalam Boilerplate
```sh
cd boilerplate
```

lalu lanjut
```bash
./start.sh nama_proyek
```

ini disesuaikan sesuai kelas masing-masing, bisa ***crkosongsatu*** atau ***crkosongdua***

**Troubleshooting / Kalo terjadi Error**
❌ mkcert tidak ditemukan (install dulu)

```sh
apt install mkcert -y
mkcert -install
```

❌ Permission denied (publickey)
```sh
SSH belum dikonfigurasi dengan benar
```

❌ Docker build lama
```sh
ditunggu aja, Normalnya (5–20 menit)
```

❌ Docker tidak jalan
```sh
Pastikan Docker Desktop aktif!
```

❌ Code tidak ditemukan
Jalankan ini
```sh
ls / | grep -E '^c$|^d$'
```

Kalau muncul c, lanjut:
```sh
ls "/c/Program Files"
```

Terus cari VS Code:
```sh
ls "/c/Program Files" | grep -i "code\|vs"
```

Lalu cari executable-nya:
```sh
find "/c/Program Files" -maxdepth 3 \( -iname "code" -o -iname "code.cmd" -o -iname "Code.exe" \) 2>/dev/null
```

Karena cmd.exe juga nggak kebaca dari PATH, coba panggil langsung pakai absolute path:
```sh
"/c/Windows/System32/cmd.exe" /c "where code"
```

Kalau itu juga gagal, cek dulu apakah folder Windows-nya ada:
```sh
ls "/c/Windows/System32/cmd.exe"
```
Kalau file itu ada, berarti interop Windows ada, cuma PATH-nya belum kebaca.

Kalau hasil find nanti misalnya ketemu seperti ini:
```sh
/c/Program Files/VSCode-win32-x64-1.112.0/bin/code
```
atau:
```sh
/c/Program Files/Microsoft VS Code/bin/code
```
maka isi .zshrc harus pakai ***/c/..., bukan /mnt/c/...***

Contohnya:
```sh
export PATH=$PATH:'/c/Program Files/VSCode-win32-x64-1.112.0/bin'
```

Lalu reload:
```sh
source ~/.zshrc
hash -r
which code
code .
```

nanti hasil diatas dimasukkan ke dalam ***nano ~/.zshrc***
contoh punyaku:
```sh
export PATH="$PATH:/c/Program Files/VSCode-win32-x64-1.112.0/bin"
```

---

## 10. Masuk ke filenya

```sh
cd /root/perkuliahan/nama_proyek
```
_sesuaikan dengan proyek masing-masing_

---

## 11. Reload Environment

```sh
source /root/.zshrc
```

 ### Gas kita tes 
 
coba **docker compose up**
```sh
dcu
```

jika hasilnya:
```text
[+] up 4/4
 ✔ Network crkosongdua_default Created                                                                                 0.2ss
 ✔ Container crkosongdua_db    Healthy                                                                                 12.6s
 ✔ Container crkosongdua_php   Started                                                                                 12.5s
 ✔ Container crkosongdua_nginx Started                                                                             12.7s
 ```
 
berarti sukses dan coba **tes di web browser** masukkan:

```sh
crkosongdua.test / crkosongsatu.test
```

Jika Keluar halaman Laravel, berarti BERHASIL <br>
Jika tidak, cek ulang siapa tau ada kesalahan (kalo bingung tanya AI)

untuk menghentikan DOCKER tinggal di **compose down**

```sh
dcd
```

dan hasilnya akan:
```text
[+] down 4/4
 ✔ Container crkosongdua_nginx Removed                                                                                  0.6s
 ✔ Container crkosongdua_php   Removed                                                                                  0.5s
 ✔ Container crkosongdua_db    Removed                                                                                  1.0s
 ✔ Network crkosongdua_default Removed                                                                                  0.3s
```

---

## 12. Buka di VS Code

Ketik ini di Terminal VS Code atau lanjutin di WSL tadi juga gapapa:

```sh
cd /root/perkuliahan/crkosongdua
```
crkosongdua adalah contoh proyek

lalu

```sh
code .
```

nanti akan otomastis masuk ke **Visual Studio Code** <br>
_pastikan extension untuk WSL sudah dipasang di VSCode kamu!!!_

---

```text
Kalo sudah sampai tahap itu, Mantapp kamu sudah selesai Set-up nya :),
tinggal praktikum tanggal 13 April 2026 🤩
```

---

## SETUP TERAKHIR DIDALAM TERMINAL WSL (opsional)
1. SETELAH SELESAI SEMUA BISA LAKUKAN SOURCE ULANG ZSHRC ATAU BISA COPY PASTE CMD DIBAWAH INI
```php
source /root/.zshrc
```
2. AKAN ADA TAMBAHAN PERINTAH SEPERTI
- dcu untuk docker-compose up -d
```php
dcu
```
- dcd untuk docker-compose down
```php
dcd
```
- dcm untuk create model, controller, seeder, migration, filament resource
```php
dcm Test
```
- dci untuk project init dimana sudah termasuk migrate, seed, fresh
```php
dci
```
- dcr untuk model, controller, seeder, migration, filament resource
```php
dcr Test
```
- dcp untuk git add, git commit dan git push
```php
dcp testing
```
- dca untuk php artisan
```php
dca make:middleware Testing
```

---

# UNTUK PENGGUNA MAC OS
## BISA LANGSUNG EKSEKUSI
```php
./start_mac.sh
```

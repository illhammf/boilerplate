# Catatan Setup Boilerplate
## ⚠️ Perhatian
Baca panduan ini dengan cermat sebelum menjalankan boilerplate.

---

## 1. Crosscheck Requirement
Pastikan WSL sudah masuk sebagai root:
```bash
whoami
```

Output yang benar:
```sh
root
```

Install jq:
```sh
apt install jq -y
```

---

## 2. Setup GitHub Token
Buka halaman token GitHub:
```sh
https://github.com/settings/tokens
```
Langkah:

1. Masuk ke Personal Access Token
2. Pilih Tokens (classic)
3. Klik Generate new token
4. Isi note: initscript
5. Set expiration: No expiration
6. Centang permission:
    - repo
    - user
    - delete_repo jika ingin memakai delete-repo.sh

### Buat file credential di dalam folder boilerplate:
```sh
touch .github-token
touch .github-user
```

### Isi file .github-token dengan token GitHub.
Contoh:
```sh
PASTE_YOUR_TOKEN_HERE
```
### Isi file .github-user dengan username GitHub.
Contoh:
```sh
illhammf
```

---

## 3. Setup Windows PowerShell

***Jalankan PowerShell sebagai Administrator.***

Install Chocolatey:
```sh
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

Install mkcert:
```sh
choco install mkcert
```
Install local certificate:
```sh
mkcert -install
```
Setelah selesai, **restart laptop**.

---

## 4. Jika Chocolatey Error

Jalankan PowerShell sebagai Administrator.

Hapus folder Chocolatey:
```sh
Set-ExecutionPolicy Bypass -Scope Process -Force;
[System.IO.Directory]::Delete("$env:ProgramData\chocolatey", $true)
```
Hapus path Chocolatey dari environment:
```sh
$envPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
$newPath = ($envPath -split ";") -ne "C:\ProgramData\chocolatey\bin" -join ";"
[Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::Machine)
```

---

## 5. Menjalankan Boilerplate

Masuk ke folder boilerplate:
```sh
cd ~/boilerplate
```
Jalankan script:
```sh
./start.sh nama-project
```
Contoh:
```sh
./start.sh pemweb
```

---

## 6. Setup Terakhir di WSL

Reload konfigurasi ZSH:
```sh
source /root/.zshrc
```

---

## 7. Daftar Alias
Menjalankan Docker
```sh
dcu
```
Mematikan Docker
```sh
dcd
```
Membuat model, migration, seeder, controller, dan Filament resource
```sh
dcm Test
```
Menjalankan project init
```sh
dci
```
Menghapus model, migration, seeder, controller, dan Filament resource
```sh
dcr Test
```
Commit dan push otomatis
```sh
dcp "pesan commit"
```
Menjalankan perintah artisan
```sh
dca make:middleware Testing
```

---

## 8. Untuk Pengguna MacOS

Jalankan:
```sh
./start_mac.sh
```

---

Update
Mon Jun 15 08:53:09 WIB 2026
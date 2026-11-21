#!/bin/bash
# =============================================================================
#  Ilham Boilerplate - Generator proyek Laravel + Filament + Docker (WSL)
#  Pemakaian : ./start.sh nama-proyek
#  Hasil     : /root/perkuliahan/<nama-proyek> dengan domain https://<nama>.test
# =============================================================================
set -euo pipefail # Berhenti jika ada error, variabel belum di-set, atau pipe gagal

# --- Variabel global (diisi selama skrip berjalan) ---
YEAR="$(date +%Y)"
GITHUB_USER="unknown" # Diisi oleh create_github_repo
GITHUB_REMOTE=""      # URL repo GitHub; kosong = tidak push ke GitHub

# --- Fungsi Bantuan untuk Pencatatan Log ---
log_info() { echo "ℹ️  $1"; }
log_success() { echo "✅ $1"; }
log_warning() { echo "⚠️  $1"; }
log_error() {
  echo "❌ $1" >&2
  exit 1
}

# =============================================================================
#  ALUR UTAMA
# =============================================================================
main() {
  # Validasi awal
  if [ -z "${1:-}" ]; then
    log_error " 📁 Harap berikan nama proyek. Contoh: ./start.sh proyek-saya"
  fi

  # Sanitasi nama proyek: huruf kecil, spasi/underscore jadi '-', buang karakter lain
  local PROJECT_NAME="$1"
  PROJECT_NAME=$(echo "$PROJECT_NAME" |
    tr '[:upper:]' '[:lower:]' |
    tr ' _' '-' |
    sed 's/[^a-z0-9-]//g')

  if [ -z "$PROJECT_NAME" ]; then
    log_error " 📁 Nama proyek tidak valid setelah disanitasi. Gunakan huruf, angka, atau '-'."
  fi

  local SCRIPT_DIR
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  local ROOT_DIR="/root/perkuliahan/$PROJECT_NAME"
  local TEMPLATE_DIR="$SCRIPT_DIR/template"
  if [ -d "$ROOT_DIR" ]; then
    log_error " 📁 Folder project '$ROOT_DIR' sudah ada!!!. Hapus dulu atau ganti nama lain."
  fi

  local DOMAIN="${PROJECT_NAME}.test"
  local HOST_ENTRY="127.0.0.1 $DOMAIN"

  # Jalankan alur kerja
  check_dependencies
  setup_directories "$ROOT_DIR"
  copy_template_files "$ROOT_DIR" "$TEMPLATE_DIR"
  generate_ssl_certs "$ROOT_DIR" "$DOMAIN"
  render_configs "$ROOT_DIR" "$PROJECT_NAME" "$DOMAIN" "$TEMPLATE_DIR"
  generate_docker_compose "$ROOT_DIR"
  update_zshrc "$HOME/.zshrc"
  update_hosts_file "$HOST_ENTRY" "$DOMAIN"

  # Pindah ke direktori proyek
  cd "$ROOT_DIR"

  # Langkah akhir
  start_containers
  create_github_repo "$SCRIPT_DIR" "$PROJECT_NAME"
  generate_readme "$ROOT_DIR" "$PROJECT_NAME" "$DOMAIN"
  init_git_and_push
  final_steps "$ROOT_DIR" "$PROJECT_NAME"
}

# =============================================================================
#  FUNGSI-FUNGSI PEMBANTU
# =============================================================================

# Memeriksa apakah semua dependensi yang diperlukan sudah terpasang
check_dependencies() {
  log_info "🔍 Memeriksa dependensi..."
  for cmd in git docker mkcert code nc curl sed; do
    if ! command -v "$cmd" &>/dev/null; then
      log_error "⚠️ Perintah '$cmd' tidak ditemukan. Harap install terlebih dahulu!!!."
    fi
  done
  if ! docker compose version &>/dev/null; then
    log_error "⚠️ Perintah 'docker compose' tidak berfungsi. Pastikan Docker Anda mendukung Compose v2 atau Docker Desktop terbaru."
  fi
}

# Membuat struktur direktori proyek
setup_directories() {
  local ROOT_DIR="$1"
  log_info " 📁 Membuat struktur folder di $ROOT_DIR..."
  mkdir -p "$ROOT_DIR/db/conf.d" "$ROOT_DIR/nginx/ssl" "$ROOT_DIR/php" "$ROOT_DIR/src"
  # .gitkeep agar direktori src tidak kosong (sesuai logika entrypoint)
  touch "$ROOT_DIR/src/.gitkeep"
}

# Menyalin file template ke proyek baru
copy_template_files() {
  local ROOT_DIR="$1"
  local TEMPLATE_DIR="$2"
  log_info " 😪 Menyalin file template..."
  if [ ! -d "$TEMPLATE_DIR" ]; then
    log_error "⚠️ Direktori template '$TEMPLATE_DIR' tidak ditemukan."
  fi

  # Salin konfigurasi Docker (kecuali entrypoint, disalin terpisah di bawah)
  cp "$TEMPLATE_DIR/db/my.cnf" "$ROOT_DIR/db/conf.d/"
  cp "$TEMPLATE_DIR/nginx/Dockerfile" "$ROOT_DIR/nginx/"
  cp "$TEMPLATE_DIR/php/Dockerfile" "$ROOT_DIR/php/"
  cp "$TEMPLATE_DIR/php/www.conf" "$ROOT_DIR/php/"
  cp "$TEMPLATE_DIR/php/local.ini" "$ROOT_DIR/php/"

  # Salin seluruh template aplikasi Laravel dari src
  log_info " 📂 Menyalin template aplikasi dari template/src/..."
  if [ -z "$(ls -A "$TEMPLATE_DIR/src/")" ]; then log_error "⚠️ Direktori 'template/src' kosong!"; fi
  cp -a "$TEMPLATE_DIR/src/." "$ROOT_DIR/src/"

  # Salin skrip entrypoint dan beri izin eksekusi
  if [ ! -f "$TEMPLATE_DIR/php/docker-entrypoint.sh.template" ]; then
    log_error "File 'template/php/docker-entrypoint.sh.template' tidak ditemukan!"
  fi
  cp "$TEMPLATE_DIR/php/docker-entrypoint.sh.template" "$ROOT_DIR/php/docker-entrypoint.sh"
  chmod +x "$ROOT_DIR/php/docker-entrypoint.sh"
}

# Membuat sertifikat SSL lokal dengan mkcert
generate_ssl_certs() {
  local ROOT_DIR="$1"
  local DOMAIN="$2"
  local NGINX_SSL="$ROOT_DIR/nginx/ssl"
  local CERT_PATH="$NGINX_SSL/$DOMAIN.crt"
  local KEY_PATH="$NGINX_SSL/$DOMAIN.key"

  if [[ -f "$CERT_PATH" && -f "$KEY_PATH" ]]; then
    log_info "Sertifikat untuk $DOMAIN sudah ada!!! Melewati."
    return
  fi

  log_info " ✉️ Membuat sertifikat SSL untuk $DOMAIN..."
  if [ ! -d "$(mkcert -CAROOT)" ]; then
    log_info " ⚠️ Local CA tidak ditemukan, menjalankan 'mkcert -install'..."
    mkcert -install
  fi
  mkcert -cert-file "$CERT_PATH" -key-file "$KEY_PATH" "$DOMAIN" "localhost" "127.0.0.1"
  log_success " 💌 Sertifikat SSL berhasil dibuat dan berlokasi di $NGINX_SSL"
}

# Membuat file konfigurasi dari template (nginx, .env, .env.example, .gitignore)
render_configs() {
  local ROOT_DIR="$1"
  local PROJECT_NAME="$2"
  local DOMAIN="$3"
  local TEMPLATE_DIR="$4"

  log_info "📄 Menghasilkan file-file konfigurasi..."

  # Nginx: ganti placeholder {{DOMAIN}} dengan domain proyek
  sed -e "s|{{DOMAIN}}|$DOMAIN|g" "$TEMPLATE_DIR/nginx/default.conf.template" >"$ROOT_DIR/nginx/default.conf"

  # .env root: dibaca Docker Compose. TIDAK di-commit (lihat .gitignore).
  # File src/.env (milik Laravel) dibuat otomatis oleh docker-entrypoint.sh.
  cat <<EOF >"$ROOT_DIR/.env"
# Variabel ini digunakan oleh docker-compose.yml
COMPOSE_PROJECT_NAME=${PROJECT_NAME}
PROJECT_NAME=${PROJECT_NAME}

# Ubah ke true lalu jalankan 'docker compose up -d' untuk mengaktifkan Xdebug
XDEBUG=false
EOF

  # .env.example: salinan .env yang DI-COMMIT, supaya anggota tim
  # cukup menjalankan 'cp .env.example .env' setelah clone.
  cat <<EOF >"$ROOT_DIR/.env.example"
# Salin file ini menjadi .env:  cp .env.example .env
# Variabel ini digunakan oleh docker-compose.yml
COMPOSE_PROJECT_NAME=${PROJECT_NAME}
PROJECT_NAME=${PROJECT_NAME}

# Ubah ke true lalu jalankan 'docker compose up -d' untuk mengaktifkan Xdebug
XDEBUG=false
EOF

  # .gitignore proyek (src/ punya .gitignore Laravel sendiri untuk storage, dll.)
  cat <<'EOF' >"$ROOT_DIR/.gitignore"
# Data database MariaDB (dibuat otomatis oleh kontainer)
db/data/

# Sertifikat SSL lokal (dibuat ulang di tiap laptop dengan mkcert)
nginx/ssl/

# Dependencies
src/vendor/
src/node_modules/

# IDE & OS files
.idea/
.vscode/
.DS_Store
Thumbs.db

# Environment files (berisi nilai lokal). .env.example TETAP di-commit.
.env
src/.env
EOF
}

# Membuat docker-compose.yml
generate_docker_compose() {
  local ROOT_DIR="$1"

  log_info "🐋 Membuat file docker-compose.yml..."
  # Heredoc pakai 'EOF' (dikutip) supaya ${...} ditulis apa adanya
  # dan baru dibaca Docker Compose dari file .env.
  cat <<'EOF' >"$ROOT_DIR/docker-compose.yml"
services:
  php:
    build:
      context: ./php
    container_name: ${COMPOSE_PROJECT_NAME}_php
    # Teruskan variabel PROJECT_NAME ke dalam kontainer
    environment:
      - PROJECT_NAME=${PROJECT_NAME}
      - XDEBUG=${XDEBUG:-false}
    volumes:
      - ./src:/var/www/html
    depends_on:
      db:
        condition: service_healthy
  nginx:
    build:
      context: ./nginx
    container_name: ${COMPOSE_PROJECT_NAME}_nginx
    ports:
      - "443:443"
      - "80:80"
    volumes:
      - ./src:/var/www/html
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
      - ./nginx/ssl:/etc/nginx/ssl:ro
    depends_on:
      - php
  db:
    image: mariadb:10.11
    container_name: ${COMPOSE_PROJECT_NAME}_db
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
    ports:
      - "13306:3306"
    environment:
      # Database ini akan dibuat saat kontainer pertama kali dijalankan
      MYSQL_DATABASE: ${PROJECT_NAME}
      MYSQL_ROOT_PASSWORD: p455w0rd
    volumes:
      - ./db/conf.d:/etc/mysql/conf.d
      - ./db/data:/var/lib/mysql
EOF
  log_success " 🐳 File docker-compose.yml berhasil dibuat..."
}

# Cek apakah file hosts sudah memuat "127.0.0.1 <domain>" (persis, bukan sebagian)
_hosts_has_entry() {
  local FILE="$1"
  local DOMAIN="$2"
  local D_RE="${DOMAIN//./\\.}" # titik di-escape agar dibaca harfiah oleh regex
  grep -qE "^[[:space:]]*127\.0\.0\.1[[:space:]]+(.*[[:space:]])?${D_RE}([[:space:]]|$)" "$FILE" 2>/dev/null
}

# Menambahkan domain ke file hosts WSL dan Windows
update_hosts_file() {
  local HOST_ENTRY="$1"
  local DOMAIN="$2"

  log_info "Memeriksa file hosts..."

  # --- Hosts WSL ---
  if ! _hosts_has_entry /etc/hosts "$DOMAIN"; then
    log_info "Menambahkan $DOMAIN ke /etc/hosts WSL..."
    if [ "$(id -u)" -eq 0 ]; then
      echo "$HOST_ENTRY" >>/etc/hosts
    else
      echo "$HOST_ENTRY" | sudo tee -a /etc/hosts >/dev/null
    fi
  fi

  # --- Hosts Windows ---
  # Lokasi drive C berbeda tergantung wsl.conf: /mnt/c (bawaan) atau /c (root = /)
  local WIN_ROOT=""
  for d in /mnt/c /c; do
    if [ -d "$d/Windows/System32" ]; then
      WIN_ROOT="$d"
      break
    fi
  done

  if [ -z "$WIN_ROOT" ] || ! command -v powershell.exe &>/dev/null; then
    log_warning "Drive Windows/PowerShell tidak terdeteksi. Tambahkan '$HOST_ENTRY' ke hosts Windows secara manual."
    return
  fi

  local win_hosts_path="$WIN_ROOT/Windows/System32/drivers/etc/hosts"
  if _hosts_has_entry "$win_hosts_path" "$DOMAIN"; then
    log_success "$DOMAIN sudah ada di file hosts Windows."
    return
  fi

  log_info "Mencoba memperbarui file hosts Windows..."
  log_warning " ⚠️  PERHATIKAN DESKTOP ANDA! Pop-up UAC akan muncul meminta izin Administrator."
  local ps_script_path_win="C:\\Windows\\Temp\\update_hosts.ps1"
  local ps_script_path_wsl="$WIN_ROOT/Windows/Temp/update_hosts.ps1"

  if ! cat <<EOF >"$ps_script_path_wsl"; then
\$HostFile = "C:\\Windows\\System32\\drivers\\etc\\hosts"
\$Entry = "$HOST_ENTRY"
if (!(Select-String -Path \$HostFile -Pattern \$Entry -SimpleMatch -Quiet)) { Add-Content -Path \$HostFile -Value \$Entry }
EOF
    log_warning "Tidak bisa menulis skrip sementara di Windows Temp. Tambahkan '$HOST_ENTRY' ke hosts Windows secara manual."
    return
  fi

  # '|| true' supaya skrip tidak berhenti kalau UAC ditolak
  powershell.exe -Command "Start-Process powershell.exe -ArgumentList '-ExecutionPolicy Bypass -File \"$ps_script_path_win\"' -Verb RunAs" || true
  sleep 3
  if _hosts_has_entry "$win_hosts_path" "$DOMAIN"; then
    log_success "File hosts Windows berhasil diperbarui."
  else
    log_warning "Gagal memperbarui file hosts Windows. Tambahkan '$HOST_ENTRY' secara manual!!!"
  fi
}

# Menjalankan kontainer Docker
start_containers() {
  local start_now=""
  read -r -p "🚀 Mulai proyek dengan Docker Compose sekarang? (y/n): " start_now
  if [[ "$start_now" =~ ^[Yy]$ ]]; then
    log_info " 🛠️ Membangun dan menjalankan kontainer..."
    if docker compose up -d --build; then
      log_success " 📢 Kontainer berjalan di latar belakang. Lihat log dengan 'docker compose logs -f php'"
      log_info " ⏳ Setup pertama (composer install + migrate) butuh beberapa menit. Pantau lewat log di atas."
    else
      log_warning "Gagal menjalankan kontainer. Cek error di atas, lalu jalankan 'dcu' dari folder proyek."
    fi
  fi
}

# Membuat repositori GitHub (belum push; push dilakukan di init_git_and_push)
# Memanggil GitHub API dengan retry jika koneksi gagal.
# Pemakaian : _github_api METHOD URL TOKEN [JSON]
# Hasil     : variabel global GH_STATUS, GH_BODY, GH_HEADERS, GH_ERR
_github_api() {
  local METHOD="$1" URL="$2" TOKEN="$3" DATA="${4:-}"
  local HDR_FILE ERR_FILE OUT attempt=1
  HDR_FILE=$(mktemp)
  ERR_FILE=$(mktemp)
  GH_STATUS="000"
  GH_BODY=""
  GH_HEADERS=""
  GH_ERR=""

  while [ "$attempt" -le 3 ]; do
    local ARGS=(-sS --connect-timeout 10 --max-time 30 -X "$METHOD"
      -D "$HDR_FILE" -w "\n%{http_code}"
      -H "Authorization: Bearer $TOKEN"
      -H "Accept: application/vnd.github+json"
      -H "X-GitHub-Api-Version: 2022-11-28")
    [ -n "$DATA" ] && ARGS+=(-d "$DATA")

    # -sS: senyap, tapi pesan error curl tetap ditangkap ke ERR_FILE
    OUT=$(curl "${ARGS[@]}" "$URL" 2>"$ERR_FILE") || true
    GH_STATUS=$(printf '%s' "$OUT" | tail -n1)
    [[ "$GH_STATUS" =~ ^[0-9]{3}$ ]] || GH_STATUS="000"
    GH_BODY=$(printf '%s' "$OUT" | sed '$d')
    GH_ERR=$(cat "$ERR_FILE")
    [ "$GH_STATUS" != "000" ] && break

    log_warning "Percobaan $attempt/3: tidak bisa terhubung ke GitHub. $GH_ERR"
    attempt=$((attempt + 1))
    [ "$attempt" -le 3 ] && sleep 5
  done

  GH_HEADERS=$(cat "$HDR_FILE")
  rm -f "$HDR_FILE" "$ERR_FILE"
}

# Meminta token dari keyboard (input disembunyikan). Prompt ke stderr,
# token yang sudah dibersihkan dicetak ke stdout.
_ask_github_token() {
  local T=""
  read -r -s -p "🔑 Masukkan GitHub Personal Access Token (classic, centang scope 'repo'): " T
  echo >&2
  printf '%s' "$T" | tr -d '[:space:]'
}

# Variabel global tambahan: token yang SUDAH terverifikasi (dipakai saat push)
GITHUB_TOKEN_OK=""

# Membuat repositori GitHub (push dilakukan di init_git_and_push)
create_github_repo() {
  local SCRIPT_DIR="$1"
  local PROJECT_NAME="$2"
  local USER_FILE="$SCRIPT_DIR/.github-user"
  local TOKEN_FILE="$SCRIPT_DIR/.github-token"

  # Username tersimpan (dipakai juga di README walau tidak membuat repo)
  if [ -f "$USER_FILE" ]; then
    GITHUB_USER=$(tr -d '[:space:]' <"$USER_FILE")
  fi

  local create_repo=""
  read -r -p " 🌐 Mau buat repositori GitHub untuk proyek ini? (y/n): " create_repo
  if [[ ! "$create_repo" =~ ^[Yy]$ ]]; then
    return 0
  fi

  # --- 1. Ambil token: dari file, atau minta dari keyboard ---
  local GITHUB_TOKEN=""
  if [ -f "$TOKEN_FILE" ]; then
    GITHUB_TOKEN=$(tr -d '[:space:]' <"$TOKEN_FILE")
    log_info "Memakai token tersimpan di $TOKEN_FILE"
  fi

  # --- 2. Verifikasi token ke GitHub (GET /user). Kalau ditolak, langsung
  #        minta token baru di run yang sama (maks 3 kali), tidak perlu ulang start.sh ---
  local asked=0
  while :; do
    if [ -z "$GITHUB_TOKEN" ]; then
      asked=$((asked + 1))
      if [ "$asked" -gt 3 ]; then
        log_warning "3 kali token gagal. Proyek tetap dibuat secara lokal tanpa GitHub."
        return 0
      fi
      GITHUB_TOKEN=$(_ask_github_token)
      if [ -z "$GITHUB_TOKEN" ]; then
        log_warning "Token kosong, coba lagi."
        continue
      fi
    fi

    log_info "🔐 Memverifikasi token ke GitHub..."
    _github_api GET "https://api.github.com/user" "$GITHUB_TOKEN"
    case "$GH_STATUS" in
    200)
      break
      ;;
    401)
      log_warning "Token ditolak GitHub (401): salah, kedaluwarsa, atau sudah di-regenerate. Masukkan token yang baru."
      rm -f "$TOKEN_FILE"
      GITHUB_TOKEN=""
      ;;
    000)
      log_warning "Tidak ada koneksi ke api.github.com (bukan masalah token). Cek: curl -I https://api.github.com"
      log_warning "Proyek tetap dibuat secara lokal tanpa GitHub."
      return 0
      ;;
    *)
      log_warning "Gagal memverifikasi token. Status: $GH_STATUS. Pesan: $GH_BODY"
      log_warning "Proyek tetap dibuat secara lokal tanpa GitHub."
      return 0
      ;;
    esac
  done

  # Token valid: simpan (hanya bisa dibaca pemilik)
  printf '%s\n' "$GITHUB_TOKEN" >"$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"

  # Username diambil langsung dari pemilik token, jadi tidak mungkin salah ketik
  local LOGIN
  LOGIN=$(printf '%s' "$GH_BODY" | grep -m1 -o '"login": *"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' || true)
  if [ -n "$LOGIN" ]; then
    if [ "$GITHUB_USER" != "unknown" ] && [ "$GITHUB_USER" != "$LOGIN" ]; then
      log_warning "Username tersimpan '$GITHUB_USER' berbeda dengan pemilik token '$LOGIN'. Memakai '$LOGIN'."
    fi
    GITHUB_USER="$LOGIN"
    printf '%s\n' "$GITHUB_USER" >"$USER_FILE"
  fi
  log_success "Token valid. Login sebagai: $GITHUB_USER"

  # Token classic (ghp_...) wajib punya scope 'repo' untuk membuat repositori
  local SCOPES
  SCOPES=$(printf '%s' "$GH_HEADERS" | grep -i '^x-oauth-scopes:' | head -n1 | cut -d: -f2- | tr -d '\r' || true)
  if [[ "$GITHUB_TOKEN" == ghp_* ]] && ! printf '%s' "$SCOPES" | grep -qE '(^|[[:space:],])repo([[:space:]]*,|[[:space:]]*$)'; then
    log_warning "Token tidak punya scope 'repo' (scope saat ini:${SCOPES:- tidak ada})."
    log_warning "Buat ulang token classic dengan mencentang 'repo', lalu hapus file $TOKEN_FILE."
    log_warning "Proyek tetap dibuat secara lokal tanpa GitHub."
    return 0
  fi

  # --- 3. Pilih visibilitas, lalu buat repositori ---
  local is_private="" PRIVATE="true"
  read -r -p " 🔒 Jadikan repositori private? (Y/n): " is_private
  if [[ "$is_private" =~ ^[Nn]$ ]]; then
    PRIVATE="false"
  fi

  local REPO_NAME="${PROJECT_NAME}-${YEAR}"
  log_info " 🚨 Membuat repositori GitHub: $GITHUB_USER/$REPO_NAME (private: $PRIVATE)"
  _github_api POST "https://api.github.com/user/repos" "$GITHUB_TOKEN" \
    "{\"name\":\"$REPO_NAME\",\"private\":$PRIVATE}"

  case "$GH_STATUS" in
  201)
    log_success " 🤩 Repositori GitHub '$REPO_NAME' berhasil dibuat..."
    ;;
  422)
    log_warning "Repositori '$REPO_NAME' sudah ada di akun $GITHUB_USER. Melanjutkan push ke repo tersebut..."
    ;;
  403 | 404)
    log_warning "GitHub menolak pembuatan repo ($GH_STATUS). Pastikan token punya scope 'repo'. Pesan: $GH_BODY"
    log_warning "Proyek tetap dibuat secara lokal tanpa GitHub."
    return 0
    ;;
  000)
    log_warning "Koneksi ke GitHub terputus saat membuat repo. Proyek tetap dibuat secara lokal tanpa GitHub."
    return 0
    ;;
  *)
    log_warning "Gagal membuat repositori. Status: $GH_STATUS. Pesan: $GH_BODY"
    log_warning "Proyek tetap dibuat secara lokal tanpa GitHub."
    return 0
    ;;
  esac

  GITHUB_TOKEN_OK="$GITHUB_TOKEN"
  GITHUB_REMOTE="https://github.com/$GITHUB_USER/$REPO_NAME.git"
}

# Membuat README.md otomatis.
# Heredoc dikutip ('EOF') sehingga backtick dan $ ditulis apa adanya (tidak
# dieksekusi Bash). Nilai dinamis memakai placeholder {{...}} yang diganti sed.
generate_readme() {
  local ROOT_DIR="$1"
  local PROJECT_NAME="$2"
  local DOMAIN="$3"
  local REPO_URL="${GITHUB_REMOTE%.git}"
  [ -z "$REPO_URL" ] && REPO_URL="https://github.com/$GITHUB_USER/${PROJECT_NAME}-${YEAR}"

  log_info "📝 Membuat README.md..."
  cat <<'EOF' | sed \
    -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
    -e "s|{{DOMAIN}}|$DOMAIN|g" \
    -e "s|{{YEAR}}|$YEAR|g" \
    -e "s|{{GITHUB_USER}}|$GITHUB_USER|g" \
    -e "s|{{REPO_URL}}|$REPO_URL|g" >"$ROOT_DIR/README.md"
## ⚠️ Noted:
### Indonesia:
Readme ini dibuat secara otomatis menggunakan skrip `start.sh` dengan template yang sudah disiapkan.
Anda bisa mengeditnya sesuai kebutuhan setelah proyek dibuat.

### in English:
This README was automatically generated using the `start.sh` script and a pre-configured template.
You can edit it as needed after the project has been created.

<div align="center">

# 🚀 {{PROJECT_NAME}}

### Laravel Boilerplate Project {{YEAR}}

Built with ❤️ using Laravel, Docker, WSL & Filament

![Laravel](https://img.shields.io/badge/Laravel-12-FF2D20?style=for-the-badge&logo=laravel&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-8.3-777BB4?style=for-the-badge&logo=php&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-10.11-003545?style=for-the-badge&logo=mariadb&logoColor=white)
![Filament](https://img.shields.io/badge/Filament-v3-F59E0B?style=for-the-badge)

[![GitHub](https://img.shields.io/badge/Open-GitHub-black?style=for-the-badge&logo=github)]({{REPO_URL}})

</div>

---

## 📖 Tentang Project

**{{PROJECT_NAME}}** merupakan aplikasi berbasis Laravel yang dibuat menggunakan **Ilham Boilerplate {{YEAR}}**.

Project ini sudah dikonfigurasi dengan berbagai kebutuhan modern untuk pengembangan aplikasi web.

---

## ✨ Fitur Bawaan

- ✅ Laravel 12
- ✅ Docker Environment
- ✅ Nginx Web Server
- ✅ PHP 8.3
- ✅ MariaDB 10.11
- ✅ Filament Admin Panel (v3)
- ✅ GitHub Integration
- ✅ WSL Ubuntu Support
- ✅ HTTPS Local Domain
- ✅ Seeder & Migration Ready

---

## 👥 Setup untuk Anggota Tim (setelah clone)

Jalankan dari WSL Ubuntu. Pastikan Docker, mkcert, dan git sudah terpasang.

```bash
# 1. Clone dan masuk ke folder proyek
git clone {{REPO_URL}}.git
cd {{PROJECT_NAME}}-{{YEAR}}

# 2. Buat file .env untuk Docker Compose
cp .env.example .env

# 3. Buat sertifikat SSL lokal
mkdir -p nginx/ssl
mkcert -install
mkcert -cert-file nginx/ssl/{{DOMAIN}}.crt -key-file nginx/ssl/{{DOMAIN}}.key {{DOMAIN}} localhost 127.0.0.1

# 4. Daftarkan domain ke hosts WSL
echo "127.0.0.1 {{DOMAIN}}" | sudo tee -a /etc/hosts

# 5. Jalankan kontainer (composer install, src/.env, APP_KEY, dan migrate dibuat otomatis)
docker compose up -d --build
docker compose logs -f php   # tunggu sampai muncul "Ready to serve!"
```

Tambahkan juga baris `127.0.0.1 {{DOMAIN}}` ke file hosts Windows
(`C:\Windows\System32\drivers\etc\hosts`, buka Notepad sebagai Administrator).

---

## 🚀 Quick Start

### Menjalankan Docker

```bash
docker compose up -d
```

atau

```bash
dcu
```

### Masuk Container PHP

```bash
docker compose exec php bash
```

### Menjalankan Migration

```bash
dca migrate
```

### Menjalankan Seeder

```bash
dca db:seed
```

### Mematikan Docker

```bash
docker compose down
```

atau

```bash
dcd
```

---

## 🌐 URL Aplikasi

### Website Proyek

```text
https://{{DOMAIN}}
```

### Admin Panel

```text
https://{{DOMAIN}}/admin
```

---

## 🐳 Docker Services

| Service | Port |
|----------|----------|
| Nginx | 80 / 443 |
| PHP-FPM | Internal |
| MariaDB | 13306 (host) |

Koneksi Navicat: host `127.0.0.1`, port `13306`, user `root`, password `p455w0rd`.

---

## 📂 Struktur Project

```text
.
├── db/            # Konfigurasi & data MariaDB
├── nginx/         # Konfigurasi Nginx & sertifikat SSL lokal
├── php/           # Dockerfile, entrypoint, konfigurasi PHP
└── src/           # Aplikasi Laravel
    ├── app/
    ├── bootstrap/
    ├── config/
    ├── database/
    ├── public/
    ├── resources/
    ├── routes/
    ├── storage/
    └── tests/
```

---

## 🛠️ Tech Stack

| Teknologi | Digunakan Untuk |
|------------|------------|
| Laravel | Backend Framework |
| PHP | Server Side Language |
| MariaDB | Database |
| Docker | Containerization |
| Nginx | Web Server |
| Filament | Admin Panel |
| WSL Ubuntu | Development Environment |
| GitHub | Version Control |

---

## 📋 Checklist Pengembangan

- [ ] Setup Database
- [ ] Setup Authentication
- [ ] Membuat Migration
- [ ] Membuat Seeder
- [ ] Membuat Admin Panel
- [ ] Deploy Production
- [ ] Tambahkan Fitur Lainnya

---

## Command Line Tools

| Command | Deskripsi |
|---------|-----------|
| `dcu` | Jalankan Docker Compose |
| `dcd` | Matikan Docker Compose proyek ini |
| `dca <perintah>` | Jalankan perintah Artisan di kontainer PHP (contoh: `dca migrate`) |
| `dci` | Jalankan `php artisan project:init` |
| `dcp "pesan"` | Git add, commit, pull --rebase, dan push dengan pesan commit |
| `dcm ModelName` | Buat model + migration + seeder + controller |
| `dcf ModelName` | Buat Filament resource dari kolom tabel (jalankan setelah `dca migrate`) |
| `dcr ModelName` | Hapus model, migration, seeder, controller, policy, dan Filament resource |
| `code .` | Buka proyek di Visual Studio Code |

Alur membuat fitur CRUD baru: `dcm Nama` → isi file migration → `dca migrate` → `dcf Nama`.

---

## 👨‍💻 Developer

**{{GITHUB_USER}}**

Generated automatically using:

```text
Ilham Boilerplate {{YEAR}}
```

---

## 🎯 Quote of The Project

> "Konsistensi Mengalahkan Bakat Saat Bakat Tidak Muncul."

🔥 Happy Coding Yaa!!!
EOF
}

# Inisialisasi Git lokal, commit awal, lalu push jika repo GitHub tersedia
# Inisialisasi Git lokal, commit awal, lalu push jika repo GitHub tersedia
init_git_and_push() {
  log_info " 🚨 Inisialisasi Git dan commit awal..."
  git init -q
  git branch -M main
  git add .

  # Commit butuh identitas git (user.name & user.email)
  if ! git commit -q -m "🎉 Initial commit"; then
    log_warning "Commit gagal. Set identitas dulu: git config --global user.name \"Nama\" && git config --global user.email \"email@contoh.com\""
    log_warning "Lalu jalankan manual: git commit -m \"🎉 Initial commit\""
    return 0
  fi
  log_success "Commit awal berhasil."

  if [ -z "$GITHUB_REMOTE" ]; then
    return 0
  fi

  # set-url kalau origin sudah ada, add kalau belum
  git remote add origin "$GITHUB_REMOTE" 2>/dev/null || git remote set-url origin "$GITHUB_REMOTE"

  # Coba push biasa dulu (pakai credential helper yang sudah ada di laptop)
  if git push -u origin main; then
    log_success "Proyek berhasil di-push otomatis ke GitHub Nih..."
    return 0
  fi

  # Cadangan: push memakai token yang sudah terverifikasi. Token hanya dipakai
  # untuk perintah ini, tidak disimpan di .git/config maupun URL remote.
  log_info "Push biasa gagal, mencoba ulang dengan token GitHub..."
  local AUTH
  AUTH=$(printf '%s:%s' "$GITHUB_USER" "$GITHUB_TOKEN_OK" | base64 | tr -d '\n')
  if git -c credential.helper= -c "http.https://github.com/.extraheader=AUTHORIZATION: basic $AUTH" \
    push -u origin main; then
    log_success "Proyek berhasil di-push ke GitHub (via token)."
  else
    log_warning "Push gagal. Coba lagi nanti dengan: git push -u origin main"
  fi
}

# Memperbarui ~/.zshrc dengan alias dan fungsi untuk proyek boilerplate
update_zshrc() {
  local ZSHRC_FILE="$1"
  log_info "Memperbarui fungsi dan alias di $ZSHRC_FILE..."
  touch "$ZSHRC_FILE" # pastikan file ada agar sed tidak gagal

  # Hapus blok lama (termasuk baris judulnya) agar tidak dobel
  sed -i.bak \
    -e '/# === ALIAS & FUNCTIONS UNTUK PROYEK BOILERPLATE ===/d' \
    -e '/# === BOILERPLATE START ===/,/# === BOILERPLATE END ===/d' \
    "$ZSHRC_FILE"

  cat <<'EOF' >>"$ZSHRC_FILE"

# === ALIAS & FUNCTIONS UNTUK PROYEK BOILERPLATE ===
# === BOILERPLATE START ===
# Hapus alias lama dengan nama yang sama agar definisi fungsi di bawah tidak bentrok
unalias dca dci dcd dcm dcr dcf 2>/dev/null || true

# Cari kontainer PHP milik proyek di folder saat ini (dari COMPOSE_PROJECT_NAME di
# .env root proyek). Jika tidak ketemu, pakai kontainer *_php pertama yang berjalan.
_get_php_container_name() {
  local ROOT P
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  if [ -f "$ROOT/.env" ]; then
    P=$(grep -E '^COMPOSE_PROJECT_NAME=' "$ROOT/.env" | head -n 1 | cut -d '=' -f 2- | tr -d '\r"')
    if [ -n "$P" ] && docker ps --format '{{.Names}}' | grep -qx "${P}_php"; then
      echo "${P}_php"
      return 0
    fi
  fi
  docker ps --filter "name=_php" --format '{{.Names}}' | head -n 1
}

# Versi "wajib ada": tampilkan error jika kontainer PHP tidak berjalan
_php_c() {
  local C
  C=$(_get_php_container_name)
  if [ -z "$C" ]; then
    echo "❌ Kontainer PHP tidak ditemukan. Jalankan 'dcu' dari folder proyek dulu." >&2
    return 1
  fi
  echo "$C"
}

# dca <perintah artisan>  -> contoh: dca migrate, dca db:seed
dca() {
  local C
  C=$(_php_c) || return 1
  docker exec -it "$C" php artisan "$@"
}

# dci -> php artisan project:init
dci() {
  local C
  C=$(_php_c) || return 1
  docker exec -it "$C" php artisan project:init
}

# dcm <Model> -> model + migration + seeder + controller (TANPA Filament resource,
# karena --generate butuh tabel yang sudah dimigrasi)
dcm() {
  [ -z "$1" ] && { echo "❌ Usage: dcm <ModelName>"; return 1; }
  local C
  C=$(_php_c) || return 1
  docker exec -it "$C" php artisan make:model "$1" -msc || return 1
  echo ""
  echo "✅ Model, migration, seeder, dan controller '$1' berhasil dibuat."
  echo "👉 Langkah berikutnya:"
  echo "   1. Isi kolom di file migration (database/migrations/..._create_..._table.php)"
  echo "   2. (Opsional) Tentukan nama tabel di model: protected \$table = 'nama_tabel';"
  echo "   3. dca migrate"
  echo "   4. dcf $1   # buat Filament resource dari kolom tabel"
}

# dcf <Model> -> Filament resource yang form & tabelnya dibaca dari kolom database
dcf() {
  [ -z "$1" ] && { echo "❌ Usage: dcf <ModelName>"; return 1; }
  local C
  C=$(_php_c) || return 1
  docker exec -it "$C" php artisan make:filament-resource "$1" --generate
}

# dcr <Model> -> hapus model, migration, seeder, controller, policy, Filament resource
dcr() {
  [ -z "$1" ] && { echo "❌ Usage: dcr <ModelName>"; return 1; }
  local C N TABLE ans
  C=$(_php_c) || return 1
  N="$1"

  # Nama tabel dihitung dengan aturan Laravel (Str::plural), sama seperti make:model -m
  TABLE=$(docker exec "$C" php -r "require 'vendor/autoload.php'; echo Illuminate\Support\Str::snake(Illuminate\Support\Str::pluralStudly('$N'));" 2>/dev/null)
  [ -z "$TABLE" ] && { echo "❌ Gagal menghitung nama tabel untuk '$N'."; return 1; }

  echo "⚠️  Akan menghapus semua file untuk '$N' (migration: *_create_${TABLE}_table.php)."
  echo "   Jika migration-nya sudah dijalankan, rollback dulu: dca migrate:rollback"
  printf "Lanjutkan? (y/n): "
  read ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "Dibatalkan."; return 0; }

  docker exec "$C" rm -f \
    "app/Models/$N.php" \
    "app/Http/Controllers/${N}Controller.php" \
    "database/seeders/${N}Seeder.php" \
    "app/Policies/${N}Policy.php"
  docker exec "$C" find database/migrations -type f -name "*_create_${TABLE}_table.php" -delete
  # Filament v3 membuat XResource.php DAN folder XResource/ (berisi Pages)
  docker exec "$C" rm -rf \
    "app/Filament/Admin/Resources/${N}Resource.php" \
    "app/Filament/Admin/Resources/${N}Resource" \
    "app/Filament/Resources/${N}Resource.php" \
    "app/Filament/Resources/${N}Resource"
  echo "🗑  File untuk '$N' berhasil dihapus."
}

# dcp "pesan" -> add, commit, pull --rebase, push
dcp() {
  [ $# -eq 0 ] && {
    echo "❌ Usage: dcp \"commit message\""
    return 1
  }

  git add .

  if git diff --cached --quiet; then
    echo "⚠️ Tidak ada perubahan"
    return 0
  fi

  git commit -m "$*" || {
    echo "❌ Commit gagal."
    return 1
  }

  git pull origin main --rebase || {
    echo "❌ Pull/Rebase gagal. Cek internet, conflict, atau koneksi GitHub."
    return 1
  }

  git push origin main || {
    echo "❌ Push gagal. Cek internet/DNS/GitHub."
    return 1
  }

  echo "✅ Push berhasil..., sii Gantengg 👍"
}

# dcd -> matikan kontainer proyek ini
dcd() {
  local C
  C=$(_php_c) || return 1
  docker compose -p "${C%_php}" down
}

alias dcu='docker compose up -d'
# === BOILERPLATE END ===
EOF
}

# Menampilkan ringkasan dan langkah akhir setelah setup selesai
final_steps() {
  local ROOT_DIR="$1"
  local PROJECT_NAME="$2"

  log_info "🧠 Membuka proyek di Visual Studio Code..."
  code "$ROOT_DIR" || log_warning "VS Code gagal dibuka. Buka manual dengan: code $ROOT_DIR"
  log_success "🎉 Aishh Gantengg, Project '$PROJECT_NAME' berhasil dibuat!"
  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║              🎉 PROJECT BERHASIL DIBUAT 🎉              ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""

  echo "🚀 Nama Project : $PROJECT_NAME"
  echo "📅 Tahun        : $YEAR"
  echo "👨‍💻 Developer    : $GITHUB_USER"
  echo ""

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  echo "🌐 Website"
  echo "   https://${PROJECT_NAME}.test"
  echo ""

  echo "⚙️ Admin Panel"
  echo "   https://${PROJECT_NAME}.test/admin"
  echo ""

  echo "📁 Folder Project"
  echo "   $ROOT_DIR"
  echo ""

  echo "🐳 Docker Status"
  echo "   docker compose ps"
  echo ""

  echo "🔗 Repository GitHub"
  if [ -n "$GITHUB_REMOTE" ]; then
    echo "   ${GITHUB_REMOTE%.git}"
  else
    echo "   (tidak dibuat)"
  fi
  echo ""

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  echo "💡 Langkah Selanjutnya"
  echo ""
  echo "1. docker compose logs -f php   # tunggu sampai 'Ready to serve!'"
  echo "2. docker compose ps"
  echo "3. dca migrate                   # (sudah otomatis dijalankan entrypoint)"
  echo "4. dca db:seed"
  echo ""

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  echo "🛠️ Commands"
  echo "   dcu            # docker compose up -d"
  echo "   dcd            # docker compose down"
  echo "   dca <cmd>      # php artisan <cmd> di kontainer PHP"
  echo "   dci            # php artisan project:init"
  echo "   dcp \"pesan\"    # git add, commit, pull --rebase, push"
  echo "   dcm ModelName  # model + migration + seeder + controller"
  echo "   dcf ModelName  # Filament resource (setelah dca migrate)"
  echo "   dcr ModelName  # hapus model, migration, seeder, controller, policy, resource"
  echo ""

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  local QUOTES=(
    "🔥 Keep Coding!"
    "🚀 Push Your Limits!"
    "💡 Learn Something New Today!"
    "🎯 Consistency Beats Talent!"
    "⚡ Small Progress Every Day!"
    "🏆 One Commit Closer To Success!"
    "☕ Drink Coffee, Write Code, Repeat!"
    "🐛 No Bug Is Permanent!"
    "📚 Belajar Hari Ini, Jago Besok!"
    "👨‍💻 Build Something Awesome!"
    "🌙 Late Night Coding Session Activated!"
    "🚢 Ship It!"
    "🤩 Si Ganteng!!!"
  )

  echo "Ada quote untuk kamu nih..."
  local RANDOM_QUOTE=${QUOTES[$RANDOM % ${#QUOTES[@]}]}
  echo "$RANDOM_QUOTE"
  echo ""
  echo "Semoga project ini bisa jadi awal yang baik untuk perjalanan coding kamu. Jangan lupa untuk terus belajar dan eksplorasi hal baru. Happy coding!!!"
  echo ""

  echo "Generated by Ilham Boilerplate $YEAR"

  log_info "Direktori/Lokasi proyek: $ROOT_DIR"
  log_info "Memuat ulang shell Zsh untuk menerapkan alias baru..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exec zsh
}

# --- Jalankan Skrip ---
main "$@"
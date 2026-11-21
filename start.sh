#!/bin/bash
# =============================================================================
#  Ilham Boilerplate - Generator proyek Laravel + Filament + Docker (WSL)
#  Pemakaian : ./start.sh nama-proyek
#  Hasil     : /root/perkuliahan/<nama-proyek> dengan domain https://<nama>.test
#
#  Alur singkat:
#   1. Cek dependensi, buat folder, salin template, buat SSL, render config
#   2. Daftarkan domain ke hosts WSL & Windows
#   3. Build image -> composer install (terlihat di terminal, ada retry)
#      -> jalankan kontainer -> TUNGGU sampai web benar-benar siap
#   4. Buat repo GitHub (token & username dibaca dari file, tanpa input ulang)
#   5. Buat README.md otomatis -> commit -> push
#   6. Tampilkan ringkasan akhir
# =============================================================================
set -euo pipefail # Berhenti jika ada error, variabel belum di-set, atau pipe gagal

# --- Variabel global (diisi selama skrip berjalan) ---
YEAR="$(date +%Y)"
GITHUB_USER="unknown" # Diisi oleh create_github_repo
GITHUB_REMOTE=""      # URL repo GitHub; kosong = tidak push ke GitHub
GITHUB_TOKEN_OK=""    # Token yang SUDAH terverifikasi (dipakai saat push cadangan)

# Status tiap tahap, ditampilkan di ringkasan akhir.
# Nilai: ok | pending | fail | skip | manual
STATUS_HOSTS="ok"
STATUS_DOCKER="skip"
STATUS_COMPOSER="skip"
STATUS_APP="skip"
STATUS_GITHUB="skip"
STATUS_PUSH="skip"

# Lama menunggu aplikasi siap setelah kontainer jalan (detik)
READY_TIMEOUT=300

# --- Warna terminal (otomatis mati kalau output bukan terminal) ---
if [ -t 1 ]; then
  C_RESET=$'\e[0m' C_BOLD=$'\e[1m' C_DIM=$'\e[2m'
  C_RED=$'\e[31m' C_GREEN=$'\e[32m' C_YELLOW=$'\e[33m'
  C_BLUE=$'\e[34m' C_MAGENTA=$'\e[35m' C_CYAN=$'\e[36m'
else
  C_RESET="" C_BOLD="" C_DIM="" C_RED="" C_GREEN="" C_YELLOW=""
  C_BLUE="" C_MAGENTA="" C_CYAN=""
fi

# --- Fungsi Bantuan untuk Pencatatan Log ---
log_info() { echo "${C_CYAN}ℹ️  $1${C_RESET}"; }
log_success() { echo "${C_GREEN}✅ $1${C_RESET}"; }
log_warning() { echo "${C_YELLOW}⚠️  $1${C_RESET}"; }
log_error() {
  echo "${C_RED}❌ $1${C_RESET}" >&2
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
  setup_containers "$ROOT_DIR" "$PROJECT_NAME" "$DOMAIN"
  create_github_repo "$SCRIPT_DIR" "$PROJECT_NAME"
  generate_readme "$ROOT_DIR" "$PROJECT_NAME" "$DOMAIN"
  init_git_and_push
  final_steps "$ROOT_DIR" "$PROJECT_NAME" "$DOMAIN"
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

# Kredensial GitHub (jaga-jaga kalau tersimpan di folder proyek)
.github-token
.github-user
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
    STATUS_HOSTS="manual"
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
    STATUS_HOSTS="manual"
    return
  fi

  # '|| true' supaya skrip tidak berhenti kalau UAC ditolak
  powershell.exe -Command "Start-Process powershell.exe -ArgumentList '-ExecutionPolicy Bypass -File \"$ps_script_path_win\"' -Verb RunAs" || true
  sleep 3
  if _hosts_has_entry "$win_hosts_path" "$DOMAIN"; then
    log_success "File hosts Windows berhasil diperbarui."
  else
    log_warning "Gagal memperbarui file hosts Windows. Tambahkan '$HOST_ENTRY' secara manual!!!"
    STATUS_HOSTS="manual"
  fi
}


# -----------------------------------------------------------------------------
#  DOCKER: build -> composer install -> up -> tunggu sampai siap
# -----------------------------------------------------------------------------

# Kenapa composer install dijalankan di sini, bukan dibiarkan ke entrypoint?
#  - Progresnya terlihat langsung di terminal dan ada retry kalau DNS WSL lambat.
#  - Kontainer PHP baru dinyalakan setelah vendor/ LENGKAP. Dulu, kalau
#    composer install di entrypoint terpotong (misalnya karena 'docker compose
#    restart php' saat setup pertama), folder vendor/ tertinggal setengah jadi
#    tanpa autoload.php -> artisan error -> APP_KEY kosong -> 502 Bad Gateway.
# Entrypoint tetap bertugas membuat src/.env, APP_KEY, dan migrate.

# Menjalankan perintah di kontainer PHP sekali pakai (tanpa entrypoint, tanpa db).
# Pemakaian: _php_oneoff <program> [argumen...]
_php_oneoff() {
  local PROGRAM="$1"
  shift
  docker compose run --rm --no-deps \
    -w /var/www/html \
    -e COMPOSER_ALLOW_SUPERUSER=1 \
    --entrypoint "$PROGRAM" \
    php "$@"
}

# composer install dengan retry. Hasil: STATUS_COMPOSER = ok | fail | skip
install_dependencies() {
  local ROOT_DIR="$1"

  if [ -f "$ROOT_DIR/src/vendor/autoload.php" ]; then
    log_info "📦 vendor/ sudah lengkap, composer install dilewati."
    STATUS_COMPOSER="ok"
    return 0
  fi

  if [ ! -f "$ROOT_DIR/src/composer.json" ]; then
    log_warning "src/composer.json tidak ditemukan. composer install dilewati."
    STATUS_COMPOSER="fail"
    return 0
  fi

  # Pastikan image PHP memang punya composer
  if ! _php_oneoff sh -c 'command -v composer' >/dev/null 2>&1; then
    log_warning "Composer tidak ditemukan di image PHP. Instalasi diserahkan ke entrypoint."
    STATUS_COMPOSER="skip"
    return 0
  fi

  local attempt=1
  while [ "$attempt" -le 3 ]; do
    log_info "📦 composer install (percobaan $attempt/3). Setup pertama butuh beberapa menit..."
    # Buang sisa vendor/ setengah jadi dari percobaan sebelumnya
    rm -rf "$ROOT_DIR/src/vendor"
    if _php_oneoff composer install --no-interaction --prefer-dist; then
      if [ -f "$ROOT_DIR/src/vendor/autoload.php" ]; then
        log_success "📦 Dependensi Composer terpasang lengkap."
        STATUS_COMPOSER="ok"
        return 0
      fi
    fi
    log_warning "composer install gagal. Biasanya karena DNS/internet WSL sedang lambat."
    attempt=$((attempt + 1))
    [ "$attempt" -le 3 ] && sleep 10
  done

  log_warning "composer install gagal 3 kali. Cek koneksi: curl -I https://repo.packagist.org"
  log_warning "Ulangi manual nanti dari folder proyek:"
  log_warning "  docker compose run --rm --no-deps -w /var/www/html --entrypoint composer php install"
  STATUS_COMPOSER="fail"
}

# Membaca nilai APP_KEY dari src/.env (kosong kalau file/kunci belum ada)
_read_app_key() {
  local ENV_FILE="$1"
  [ -f "$ENV_FILE" ] || return 0
  grep -E '^APP_KEY=' "$ENV_FILE" | head -n1 | cut -d= -f2- | tr -d '\r" ' || true
}

# Status kontainer PHP: running | exited | restarting | ... (kosong = belum ada)
_php_state() {
  local NAME="$1"
  docker inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null || true
}

# Menunggu sampai aplikasi benar-benar bisa diakses. Hasil: STATUS_APP
wait_until_ready() {
  local ROOT_DIR="$1"
  local PROJECT_NAME="$2"
  local DOMAIN="$3"
  local PHP_NAME="${PROJECT_NAME}_php"
  local ENV_FILE="$ROOT_DIR/src/.env"
  local elapsed=0 code="000" state="" key=""

  log_info "⏳ Menunggu aplikasi siap (src/.env, APP_KEY, migrate). Maksimal ${READY_TIMEOUT} detik..."
  log_info "   Jangan jalankan 'docker compose restart php' selama proses ini."

  while [ "$elapsed" -lt "$READY_TIMEOUT" ]; do
    state=$(_php_state "$PHP_NAME")
    if [ "$state" = "exited" ] || [ "$state" = "dead" ]; then
      echo ""
      log_warning "Kontainer PHP berhenti saat setup. 30 baris log terakhir:"
      docker compose logs --tail=30 php || true
      STATUS_APP="fail"
      return 0
    fi

    # --resolve: langsung ke 127.0.0.1, tidak tergantung file hosts
    code=$(curl -sk --max-time 5 -o /dev/null -w '%{http_code}' \
      --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN/admin/login" 2>/dev/null || true)
    [[ "$code" =~ ^[0-9]{3}$ ]] || code="000"
    key=$(_read_app_key "$ENV_FILE")

    if [[ "$code" =~ ^(200|301|302)$ ]] && [ -n "$key" ]; then
      printf '\r%*s\r' 70 ''
      log_success "🌐 Aplikasi siap diakses (HTTP $code, APP_KEY terisi) dalam ${elapsed} detik."
      STATUS_APP="ok"
      return 0
    fi

    printf '\r   ⏱️  %3ss | kontainer: %-10s | HTTP: %s | APP_KEY: %s ' \
      "$elapsed" "${state:-?}" "$code" "$([ -n "$key" ] && echo ada || echo belum)"
    sleep 5
    elapsed=$((elapsed + 5))
  done
  echo ""

  # Cadangan: vendor lengkap & kontainer jalan, tapi APP_KEY masih kosong
  if [ -f "$ENV_FILE" ] && [ -z "$(_read_app_key "$ENV_FILE")" ] &&
    [ -f "$ROOT_DIR/src/vendor/autoload.php" ] && [ "$(_php_state "$PHP_NAME")" = "running" ]; then
    log_warning "APP_KEY masih kosong. Membuatnya sekarang..."
    docker compose exec -T php php artisan key:generate --force || true
  fi

  code=$(curl -sk --max-time 5 -o /dev/null -w '%{http_code}' \
    --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN/admin/login" 2>/dev/null || true)
  if [[ "$code" =~ ^(200|301|302)$ ]] && [ -n "$(_read_app_key "$ENV_FILE")" ]; then
    log_success "🌐 Aplikasi siap diakses (HTTP $code)."
    STATUS_APP="ok"
  else
    log_warning "Aplikasi belum merespons normal (HTTP $code). Mungkin masih migrate."
    log_warning "Pantau dengan: docker compose logs -f php   (tunggu 'Ready to serve!')"
    STATUS_APP="pending"
  fi
}

# Build image, pasang dependensi, jalankan kontainer, lalu tunggu siap
setup_containers() {
  local ROOT_DIR="$1"
  local PROJECT_NAME="$2"
  local DOMAIN="$3"

  local start_now=""
  read -r -p "🚀 Mulai proyek dengan Docker Compose sekarang? (y/n): " start_now
  if [[ ! "$start_now" =~ ^[Yy]$ ]]; then
    log_info "Docker dilewati. Nanti jalankan dari folder proyek: docker compose up -d --build"
    return 0
  fi

  log_info " 🛠️ Membangun image Docker..."
  if ! docker compose build; then
    log_warning "Build image gagal. Cek error di atas, lalu jalankan 'docker compose up -d --build' dari folder proyek."
    STATUS_DOCKER="fail"
    return 0
  fi

  install_dependencies "$ROOT_DIR"

  log_info " 🐳 Menjalankan kontainer..."
  if ! docker compose up -d; then
    log_warning "Gagal menjalankan kontainer. Cek error di atas, lalu jalankan 'dcu' dari folder proyek."
    STATUS_DOCKER="fail"
    return 0
  fi
  STATUS_DOCKER="ok"
  log_success " 📢 Kontainer berjalan di latar belakang."

  wait_until_ready "$ROOT_DIR" "$PROJECT_NAME" "$DOMAIN"
}

# -----------------------------------------------------------------------------
#  GITHUB
# -----------------------------------------------------------------------------

# Cadangan DNS: tanya IP sebuah domain ke Cloudflare (DNS-over-HTTPS).
# Koneksinya langsung ke IP 1.1.1.1, jadi tetap jalan walau DNS WSL macet.
# Pemakaian: _doh_resolve api.github.com   -> mencetak IP (kosong kalau gagal)
_doh_resolve() {
  curl -s --max-time 10 -H 'accept: application/dns-json' \
    "https://1.1.1.1/dns-query?name=$1&type=A" 2>/dev/null |
    grep -o '"data":"[0-9.]*"' | head -n1 | cut -d'"' -f4 || true
}

# IP cadangan hasil DoH (dipakai ulang oleh API GitHub dan git push)
GH_API_IP=""

# Memanggil GitHub API dengan retry jika koneksi gagal.
# Kalau gagal karena DNS ("Resolving timed out"), percobaan berikutnya memakai
# IP dari DoH lewat curl --resolve, jadi tidak bergantung pada DNS WSL lagi.
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
    [ -n "$GH_API_IP" ] && ARGS+=(--resolve "api.github.com:443:$GH_API_IP")

    # -sS: senyap, tapi pesan error curl tetap ditangkap ke ERR_FILE
    OUT=$(curl "${ARGS[@]}" "$URL" 2>"$ERR_FILE") || true
    GH_STATUS=$(printf '%s' "$OUT" | tail -n1)
    [[ "$GH_STATUS" =~ ^[0-9]{3}$ ]] || GH_STATUS="000"
    GH_BODY=$(printf '%s' "$OUT" | sed '$d')
    GH_ERR=$(cat "$ERR_FILE")
    [ "$GH_STATUS" != "000" ] && break

    log_warning "Percobaan $attempt/3: tidak bisa terhubung ke GitHub. $GH_ERR"

    # DNS WSL macet -> ambil IP api.github.com lewat DoH (sekali saja)
    if [ -z "$GH_API_IP" ] && printf '%s' "$GH_ERR" | grep -qi 'resolv'; then
      GH_API_IP=$(_doh_resolve api.github.com)
      if [ -n "$GH_API_IP" ]; then
        log_info "🛟 DNS WSL macet. Memakai DNS cadangan (1.1.1.1): api.github.com = $GH_API_IP"
        attempt=$((attempt + 1))
        continue # langsung coba lagi tanpa jeda
      fi
    fi

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

# Membuat repositori GitHub (push dilakukan di init_git_and_push).
# Token & username dibaca dari ~/boilerplate/.github-token dan .github-user,
# jadi tidak perlu input ulang selama tokennya masih valid.
create_github_repo() {
  local SCRIPT_DIR="$1"
  local PROJECT_NAME="$2"
  local USER_FILE="$SCRIPT_DIR/.github-user"
  local TOKEN_FILE="$SCRIPT_DIR/.github-token"

  # Username tersimpan (dipakai juga di README walau tidak membuat repo)
  if [ -f "$USER_FILE" ]; then
    GITHUB_USER=$(tr -d '[:space:]' <"$USER_FILE")
    [ -z "$GITHUB_USER" ] && GITHUB_USER="unknown"
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
  #        minta token baru di run yang sama (maks 3 kali) ---
  local asked=0
  while :; do
    if [ -z "$GITHUB_TOKEN" ]; then
      asked=$((asked + 1))
      if [ "$asked" -gt 3 ]; then
        log_warning "3 kali token gagal. Proyek tetap dibuat secara lokal tanpa GitHub."
        STATUS_GITHUB="fail"
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
      # File token TIDAK dihapus: tetap bisa diedit manual (nano ~/boilerplate/.github-token).
      # File baru ditimpa setelah token pengganti lolos verifikasi.
      log_warning "Token ditolak GitHub (401): salah, kedaluwarsa, atau sudah di-regenerate."
      log_warning "Masukkan token baru di bawah, atau batalkan (Ctrl+C) lalu perbarui lewat: nano $TOKEN_FILE"
      GITHUB_TOKEN=""
      ;;
    000)
      # Bukan masalah token: koneksi/DNS. Token TIDAK diganti; tawarkan coba lagi.
      log_warning "Tidak ada koneksi ke api.github.com (bukan masalah token)."
      local again=""
      read -r -p " 🔁 Coba lagi? Perbaiki dulu internet/DNS-nya kalau perlu (Y/n): " again
      if [[ "$again" =~ ^[Nn]$ ]]; then
        log_warning "Proyek tetap dibuat secara lokal tanpa GitHub."
        STATUS_GITHUB="fail"
        return 0
      fi
      ;;
    *)
      log_warning "Gagal memverifikasi token. Status: $GH_STATUS. Pesan: $GH_BODY"
      log_warning "Proyek tetap dibuat secara lokal tanpa GitHub."
      STATUS_GITHUB="fail"
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
    log_warning "Buat ulang token classic dengan mencentang 'repo', lalu perbarui: nano $TOKEN_FILE"
    log_warning "Proyek tetap dibuat secara lokal tanpa GitHub."
    STATUS_GITHUB="fail"
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
    log_warning "Kalau repo itu sudah berisi commit lain, push akan ditolak. Hapus repo lamanya dulu di GitHub bila perlu."
    ;;
  403 | 404)
    log_warning "GitHub menolak pembuatan repo ($GH_STATUS). Pastikan token punya scope 'repo'. Pesan: $GH_BODY"
    log_warning "Proyek tetap dibuat secara lokal tanpa GitHub."
    STATUS_GITHUB="fail"
    return 0
    ;;
  000)
    log_warning "Koneksi ke GitHub terputus saat membuat repo. Proyek tetap dibuat secara lokal tanpa GitHub."
    STATUS_GITHUB="fail"
    return 0
    ;;
  *)
    log_warning "Gagal membuat repositori. Status: $GH_STATUS. Pesan: $GH_BODY"
    log_warning "Proyek tetap dibuat secara lokal tanpa GitHub."
    STATUS_GITHUB="fail"
    return 0
    ;;
  esac

  STATUS_GITHUB="ok"
  GITHUB_TOKEN_OK="$GITHUB_TOKEN"
  GITHUB_REMOTE="https://github.com/$GITHUB_USER/$REPO_NAME.git"
}

# -----------------------------------------------------------------------------
#  README & GIT
# -----------------------------------------------------------------------------

# Membuat README.md otomatis.
# Heredoc dikutip ('EOF') sehingga backtick dan $ ditulis apa adanya (tidak
# dieksekusi Bash). Nilai dinamis memakai placeholder {{...}} yang diganti sed.
generate_readme() {
  local ROOT_DIR="$1"
  local PROJECT_NAME="$2"
  local DOMAIN="$3"
  local REPO_NAME="${PROJECT_NAME}-${YEAR}"
  local REPO_URL="${GITHUB_REMOTE%.git}"
  # Kalau repo gagal dibuat, link tetap menunjuk ke nama repo yang benar
  [ -z "$REPO_URL" ] && REPO_URL="https://github.com/$GITHUB_USER/$REPO_NAME"
  local GENERATED_AT
  GENERATED_AT="$(date '+%d-%m-%Y %H:%M')"

  log_info "📝 Membuat README.md..."
  cat <<'EOF' | sed \
    -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
    -e "s|{{REPO_NAME}}|$REPO_NAME|g" \
    -e "s|{{DOMAIN}}|$DOMAIN|g" \
    -e "s|{{YEAR}}|$YEAR|g" \
    -e "s|{{GITHUB_USER}}|$GITHUB_USER|g" \
    -e "s|{{REPO_URL}}|$REPO_URL|g" \
    -e "s|{{GENERATED_AT}}|$GENERATED_AT|g" >"$ROOT_DIR/README.md"
<div align="center">

# 🚀 {{PROJECT_NAME}}

### Laravel + Filament + Docker · Project {{YEAR}}

Built with ❤️ using Laravel, Filament, Docker & WSL

![Laravel](https://img.shields.io/badge/Laravel-12-FF2D20?style=for-the-badge&logo=laravel&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-8.3-777BB4?style=for-the-badge&logo=php&logoColor=white)
![Filament](https://img.shields.io/badge/Filament-v3-F59E0B?style=for-the-badge)
![MariaDB](https://img.shields.io/badge/MariaDB-10.11-003545?style=for-the-badge&logo=mariadb&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white)

[![GitHub](https://img.shields.io/badge/Open-GitHub-black?style=for-the-badge&logo=github)]({{REPO_URL}})

</div>

> ℹ️ README ini dibuat otomatis oleh `start.sh` (Ilham Boilerplate) pada {{GENERATED_AT}}.
> Silakan diedit sesuai kebutuhan proyek.

---

## 📑 Daftar Isi

- [Tentang Project](#-tentang-project)
- [URL Aplikasi](#-url-aplikasi)
- [Setup untuk Anggota Tim](#-setup-untuk-anggota-tim-setelah-clone)
- [Perintah Sehari-hari](#-perintah-sehari-hari)
- [Alur Membuat Fitur CRUD](#-alur-membuat-fitur-crud)
- [Docker Services & Database](#-docker-services--database)
- [Struktur Project](#-struktur-project)
- [Troubleshooting](#-troubleshooting)
- [Checklist Pengembangan](#-checklist-pengembangan)

---

## 📖 Tentang Project

**{{PROJECT_NAME}}** adalah aplikasi web berbasis Laravel 12 dengan panel admin Filament 3,
dijalankan sepenuhnya di Docker (Nginx HTTPS + PHP 8.3-FPM + MariaDB 10.11).

| Fitur Bawaan | Keterangan |
|---|---|
| ✅ Laravel 12 + Filament 3 | Panel admin siap pakai di `/admin` |
| ✅ Filament Shield & Logger | Manajemen role/permission dan jejak aktivitas |
| ✅ HTTPS lokal | Domain `https://{{DOMAIN}}` via mkcert |
| ✅ Setup otomatis | `src/.env`, `APP_KEY`, dan migrate dibuat oleh entrypoint |
| ✅ Alias terminal | `dca`, `dcm`, `dcf`, `dcp`, dan lainnya |

---

## 🌐 URL Aplikasi

| Halaman | URL |
|---|---|
| Website | https://{{DOMAIN}} |
| Admin Panel | https://{{DOMAIN}}/admin |
| Repository | {{REPO_URL}} |

---

## 👥 Setup untuk Anggota Tim (setelah clone)

Jalankan dari **WSL Ubuntu**. Pastikan Docker, mkcert, dan git sudah terpasang.

```bash
# 1. Clone dan masuk ke folder proyek
git clone {{REPO_URL}}.git
cd {{REPO_NAME}}

# 2. Buat file .env untuk Docker Compose
cp .env.example .env

# 3. Buat sertifikat SSL lokal
mkdir -p nginx/ssl
mkcert -install
mkcert -cert-file nginx/ssl/{{DOMAIN}}.crt -key-file nginx/ssl/{{DOMAIN}}.key {{DOMAIN}} localhost 127.0.0.1

# 4. Daftarkan domain ke hosts WSL
echo "127.0.0.1 {{DOMAIN}}" | sudo tee -a /etc/hosts

# 5. Build image lalu pasang dependensi Composer (progres terlihat langsung)
docker compose build
docker compose run --rm --no-deps -w /var/www/html --entrypoint composer php install

# 6. Jalankan kontainer (src/.env, APP_KEY, dan migrate dibuat otomatis)
docker compose up -d
docker compose logs -f php   # tunggu sampai muncul "Ready to serve!", lalu Ctrl+C
```

Tambahkan juga baris `127.0.0.1 {{DOMAIN}}` ke file hosts Windows
(`C:\Windows\System32\drivers\etc\hosts`, buka Notepad sebagai Administrator).

> ⚠️ Jangan menjalankan `docker compose restart php` saat setup pertama masih berjalan.

---

## ⚡ Perintah Sehari-hari

| Command | Deskripsi |
|---|---|
| `dcu` | Jalankan kontainer (`docker compose up -d`) |
| `dcd` | Matikan kontainer proyek ini |
| `dca <perintah>` | Perintah Artisan di kontainer PHP (contoh: `dca migrate`) |
| `dci` | Jalankan `php artisan project:init` |
| `dcp "pesan"` | Git add, commit, pull --rebase, lalu push |
| `dcm ModelName` | Buat model + migration + seeder + controller |
| `dcf ModelName` | Buat Filament resource dari kolom tabel (setelah `dca migrate`) |
| `dcr ModelName` | Hapus model, migration, seeder, controller, policy, dan resource |
| `docker compose exec php bash` | Masuk ke kontainer PHP |
| `docker compose logs -f php` | Lihat log kontainer PHP |

---

## 🧩 Alur Membuat Fitur CRUD

```text
dcm Nama  →  isi file migration  →  dca migrate  →  dcf Nama
```

Jika nama tabel tidak mengikuti aturan jamak bahasa Inggris, set di model:
`protected $table = 'nama_tabel';`

---

## 🐳 Docker Services & Database

| Service | Port |
|---|---|
| Nginx | 80 / 443 |
| PHP-FPM | Internal (9000) |
| MariaDB | 13306 (host) |

Koneksi Navicat/DBeaver: host `127.0.0.1`, port `13306`, user `root`, password `p455w0rd`,
database `{{PROJECT_NAME}}`.

---

## 📂 Struktur Project

```text
.
├── db/              # Konfigurasi & data MariaDB (data tidak di-commit)
├── nginx/           # Konfigurasi Nginx & sertifikat SSL lokal (ssl/ tidak di-commit)
├── php/             # Dockerfile, entrypoint, konfigurasi PHP
├── src/             # Aplikasi Laravel
├── .env.example     # Salin menjadi .env (dibaca Docker Compose)
└── docker-compose.yml
```

---

## 🩺 Troubleshooting

| Gejala | Solusi |
|---|---|
| `502 Bad Gateway` | PHP belum siap. Cek `docker compose logs -f php`, tunggu "Ready to serve!" |
| `vendor/autoload.php` tidak ada | `docker compose stop php` → `rm -rf src/vendor` → perintah composer di langkah 5 → `docker compose up -d` |
| `APP_KEY` kosong | Pastikan vendor lengkap dulu, lalu `docker compose restart php` |
| Domain tidak bisa dibuka | Cek baris `127.0.0.1 {{DOMAIN}}` di hosts WSL **dan** Windows |
| Port 80/443/13306 dipakai | Matikan proyek lain dulu dengan `dcd` di folder proyek tersebut |
| `git push` lambat/timeout | DNS WSL lambat; ulangi beberapa saat lagi |

---

## 📋 Checklist Pengembangan

- [ ] Setup database & migration
- [ ] Setup role & permission (Filament Shield)
- [ ] Membuat resource admin
- [ ] Membuat halaman pengguna
- [ ] Seeder data awal
- [ ] Pengujian
- [ ] Deploy

---

<div align="center">

👨‍💻 Developer: **{{GITHUB_USER}}** · Generated with **Ilham Boilerplate {{YEAR}}**

> "Konsistensi Mengalahkan Bakat Saat Bakat Tidak Muncul."

🔥 Happy Coding Yaa!!!

</div>
EOF
}

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
    [ -n "$GITHUB_REMOTE" ] && STATUS_PUSH="fail"
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
    STATUS_PUSH="ok"
    return 0
  fi

  # Cadangan: push memakai token yang sudah terverifikasi. Token hanya dipakai
  # untuk perintah ini, tidak disimpan di .git/config maupun URL remote.
  log_info "Push biasa gagal, mencoba ulang dengan token GitHub..."
  local AUTH
  AUTH=$(printf '%s:%s' "$GITHUB_USER" "$GITHUB_TOKEN_OK" | base64 | tr -d '\n')
  # Kalau DNS WSL macet, arahkan git ke IP github.com hasil DoH (butuh git >= 2.37)
  local RESOLVE_OPT=()
  local GH_IP
  GH_IP=$(_doh_resolve github.com)
  [ -n "$GH_IP" ] && RESOLVE_OPT=(-c "http.curloptResolve=github.com:443:$GH_IP")
  if git -c credential.helper= -c "http.https://github.com/.extraheader=AUTHORIZATION: basic $AUTH" \
    "${RESOLVE_OPT[@]}" push -u origin main; then
    log_success "Proyek berhasil di-push ke GitHub (via token)."
    STATUS_PUSH="ok"
  else
    log_warning "Push gagal. Coba lagi nanti dengan: git push -u origin main"
    STATUS_PUSH="fail"
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


# -----------------------------------------------------------------------------
#  RINGKASAN AKHIR
# -----------------------------------------------------------------------------

# Garis pemisah selebar 62 karakter
_line() { printf '%s\n' "${C_DIM}──────────────────────────────────────────────────────────────${C_RESET}"; }

# Judul bagian: _section "🌐" "Akses Aplikasi"
_section() {
  echo ""
  printf '%s\n' "${C_BOLD}${C_MAGENTA}$1  $2${C_RESET}"
  _line
}

# Baris label + nilai: _row "Label" "Nilai"
_row() { printf '   %-16s %s\n' "$1" "$2"; }

# Ubah kode status menjadi teks berwarna
_badge() {
  case "$1" in
  ok) printf '%s' "${C_GREEN}✅ Berhasil${C_RESET}" ;;
  pending) printf '%s' "${C_YELLOW}⏳ Masih berproses${C_RESET}" ;;
  fail) printf '%s' "${C_RED}❌ Gagal${C_RESET}" ;;
  manual) printf '%s' "${C_YELLOW}✍️  Perlu manual${C_RESET}" ;;
  *) printf '%s' "${C_DIM}➖ Dilewati${C_RESET}" ;;
  esac
}

# Baris perintah + penjelasan: _cmd "dca migrate" "Jalankan migration"
_cmd() { printf '   %s%-18s%s %s\n' "${C_CYAN}" "$1" "${C_RESET}" "${C_DIM}$2${C_RESET}"; }

# Menampilkan ringkasan dan langkah akhir setelah setup selesai
final_steps() {
  local ROOT_DIR="$1"
  local PROJECT_NAME="$2"
  local DOMAIN="$3"
  local REPO_TEXT="(tidak dibuat)"
  [ -n "$GITHUB_REMOTE" ] && REPO_TEXT="${GITHUB_REMOTE%.git}"

  log_info "🧠 Membuka proyek di Visual Studio Code..."
  code "$ROOT_DIR" || log_warning "VS Code gagal dibuka. Buka manual dengan: code $ROOT_DIR"

  echo ""
  printf '%s\n' "${C_BOLD}${C_GREEN}╔════════════════════════════════════════════════════════════╗${C_RESET}"
  printf '%s\n' "${C_BOLD}${C_GREEN}║                                                            ║${C_RESET}"
  printf '%s\n' "${C_BOLD}${C_GREEN}║               🎉  PROJECT BERHASIL DIBUAT  🎉              ║${C_RESET}"
  printf '%s\n' "${C_BOLD}${C_GREEN}║                                                            ║${C_RESET}"
  printf '%s\n' "${C_BOLD}${C_GREEN}╚════════════════════════════════════════════════════════════╝${C_RESET}"
  echo ""
  printf '   %s\n' "${C_BOLD}Aishh Gantengg, project '${PROJECT_NAME}' sudah jadi! 😎${C_RESET}"

  _section "📦" "Informasi Project"
  _row "Nama Project" "$PROJECT_NAME"
  _row "Tahun" "$YEAR"
  _row "Developer" "$GITHUB_USER"
  _row "Folder" "$ROOT_DIR"

  _section "🌐" "Akses Aplikasi"
  _row "Website" "${C_BOLD}https://${DOMAIN}${C_RESET}"
  _row "Admin Panel" "${C_BOLD}https://${DOMAIN}/admin${C_RESET}"
  _row "Repository" "$REPO_TEXT"
  _row "Database" "127.0.0.1:13306 · root / p455w0rd · db: $PROJECT_NAME"

  _section "🩺" "Status Setup"
  _row "Hosts Windows" "$(_badge "$STATUS_HOSTS")"
  _row "Docker" "$(_badge "$STATUS_DOCKER")"
  _row "Composer" "$(_badge "$STATUS_COMPOSER")"
  _row "Aplikasi Web" "$(_badge "$STATUS_APP")"
  _row "Repo GitHub" "$(_badge "$STATUS_GITHUB")"
  _row "Push GitHub" "$(_badge "$STATUS_PUSH")"

  _section "💡" "Langkah Selanjutnya"
  if [ "$STATUS_APP" = "ok" ]; then
    echo "   1. Buka ${C_BOLD}https://${DOMAIN}/admin${C_RESET} di browser"
    echo "   2. dca db:seed          # isi data awal (jika ada seeder)"
    echo "   3. Mulai fitur pertama: dcm Nama → isi migration → dca migrate → dcf Nama"
  elif [ "$STATUS_DOCKER" = "skip" ]; then
    echo "   1. cd $ROOT_DIR"
    echo "   2. docker compose build"
    echo "   3. docker compose run --rm --no-deps -w /var/www/html --entrypoint composer php install"
    echo "   4. docker compose up -d && docker compose logs -f php   # tunggu 'Ready to serve!'"
  else
    echo "   1. docker compose logs -f php   # tunggu 'Ready to serve!', jangan restart php"
    echo "   2. Kalau ada error vendor/autoload.php, lihat bagian Troubleshooting di README.md"
    echo "   3. Buka https://${DOMAIN}/admin setelah log menampilkan 'Ready to serve!'"
  fi
  if [ "$STATUS_HOSTS" = "manual" ]; then
    echo "   ⚠️  Tambahkan '127.0.0.1 ${DOMAIN}' ke C:\\Windows\\System32\\drivers\\etc\\hosts"
  fi
  if [ "$STATUS_PUSH" = "fail" ]; then
    echo "   ⚠️  Push belum berhasil. Ulangi: git push -u origin main"
  fi

  _section "🛠️" "Perintah Andalan"
  _cmd "dcu" "docker compose up -d"
  _cmd "dcd" "docker compose down (proyek ini)"
  _cmd "dca <cmd>" "php artisan <cmd> di kontainer PHP"
  _cmd "dci" "php artisan project:init"
  _cmd "dcm Model" "model + migration + seeder + controller"
  _cmd "dcf Model" "Filament resource (setelah dca migrate)"
  _cmd "dcr Model" "hapus semua file milik Model"
  _cmd "dcp \"pesan\"" "add, commit, pull --rebase, push"

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
  local RANDOM_QUOTE=${QUOTES[$RANDOM % ${#QUOTES[@]}]}

  _section "✨" "Quote Hari Ini"
  printf '   %s\n' "${C_BOLD}${C_YELLOW}${RANDOM_QUOTE}${C_RESET}"
  echo ""
  echo "   Semoga project ini jadi awal yang baik untuk perjalanan coding kamu."
  echo "   Terus belajar dan eksplorasi hal baru. Happy coding!!!"
  echo ""
  _line
  printf '%s\n' "   ${C_DIM}Generated by Ilham Boilerplate ${YEAR} · README.md sudah dibuat otomatis${C_RESET}"
  _line
  echo ""

  log_info "Memuat ulang shell Zsh untuk menerapkan alias baru..."
  exec zsh
}

# --- Jalankan Skrip ---
main "$@"
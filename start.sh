#!/bin/bash
set -euo pipefail # Untuk memastikan skrip berhenti jika ada error, variabel tidak di-set, atau perintah gagal

# --- Fungsi Bantuan untuk Pencatatan Log ---
log_info() { echo "ℹ️  $1"; }
log_success() { echo "✅ $1"; }
log_warning() { echo "⚠️  $1"; }
log_error() {
  echo "❌ $1" >&2
  exit 1
}

# --- Fungsi Utama ---
main() {
  # Validasi awal
  if [ -z "${1:-}" ]; then
    log_error " 📁 Harap berikan nama proyek. Contoh: ./start.sh proyek-saya"
  fi

  # Inisialisasi variabel proyek
  local PROJECT_NAME="$1"
  PROJECT_NAME=$(echo "$PROJECT_NAME" \
    | tr '[:upper:]' '[:lower:]' \
    | tr ' _' '-' \
    | sed 's/[^a-z0-9-]//g')

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
  final_steps "$ROOT_DIR" "$PROJECT_NAME" "$SCRIPT_DIR"
}

# --- Fungsi-fungsi Pembantu ---
# Fungsi untuk memeriksa apakah semua dependensi yang diperlukan sudah terpasang
check_dependencies() {
    log_info "🔍 Memeriksa dependensi..."
    for cmd in git docker mkcert code nc; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "⚠️ Perintah '$cmd' tidak ditemukan. Harap install terlebih dahulu!!!."
        fi
    done
    if ! docker compose version &>/dev/null; then
        log_error "⚠️ Perintah 'docker compose' tidak berfungsi. Pastikan Docker Anda mendukung Compose v2 atau Docker Desktop terbaru."
    fi
}

# Fungsi untuk membuat struktur direktori yang diperlukan untuk proyek
setup_directories() {
  local ROOT_DIR="$1"
  log_info " 📁 Membuat struktur folder di $ROOT_DIR..."
  mkdir -p "$ROOT_DIR/db/conf.d" "$ROOT_DIR/nginx/ssl" "$ROOT_DIR/php" "$ROOT_DIR/src"
  # Buat .gitkeep agar direktori src tidak kosong, sesuai logika entrypoint
  touch "$ROOT_DIR/src/.gitkeep"
}

# Fungsi untuk menyalin file template ke dalam struktur proyek yang baru dibuat
copy_template_files() {
  local ROOT_DIR="$1"
  local TEMPLATE_DIR="$2"
  log_info " 😪 Menyalin file template..."
  if [ ! -d "$TEMPLATE_DIR" ]; then
    log_error "⚠️ Direktori template '$TEMPLATE_DIR' tidak ditemukan."
  fi
  # Salin semua template kecuali entrypoint
  cp "$TEMPLATE_DIR/db/my.cnf" "$ROOT_DIR/db/conf.d/"
  cp "$TEMPLATE_DIR/nginx/Dockerfile" "$ROOT_DIR/nginx/"
  cp "$TEMPLATE_DIR/php/Dockerfile" "$ROOT_DIR/php/"
  cp "$TEMPLATE_DIR/php/www.conf" "$ROOT_DIR/php/"
  cp "$TEMPLATE_DIR/php/local.ini" "$ROOT_DIR/php/"
  # Salin seluruh template aplikasi Laravel Anda dari src
  log_info " 📂 Menyalin template aplikasi dari template/src/..."
  if [ -z "$(ls -A "$TEMPLATE_DIR/src/")" ]; then log_error "⚠️ Direktori 'template/src' kosong!"; fi
  cp -a "$TEMPLATE_DIR/src/." "$ROOT_DIR/src/"

  # Salin skrip entrypoint Anda dan berikan izin eksekusi
  if [ ! -f "$TEMPLATE_DIR/php/docker-entrypoint.sh.template" ]; then
      log_error "File 'template/php/docker-entrypoint.sh.template' tidak ditemukan!"
  fi
  cp "$TEMPLATE_DIR/php/docker-entrypoint.sh.template" "$ROOT_DIR/php/docker-entrypoint.sh"
  chmod +x "$ROOT_DIR/php/docker-entrypoint.sh"
}

# Fungsi untuk menghasilkan sertifikat SSL menggunakan mkcert
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

# Fungsi untuk menghasilkan file konfigurasi dengan menggantikan placeholder
render_configs() {
  local ROOT_DIR="$1"
  local PROJECT_NAME="$2"
  local DOMAIN="$3"
  local TEMPLATE_DIR="$4"

  log_info "📄 Menghasilkan file-file konfigurasi..."
  # Nginx Config
  sed -e "s|{{DOMAIN}}|$DOMAIN|g" "$TEMPLATE_DIR/nginx/default.conf.template" >"$ROOT_DIR/nginx/default.conf"

  # .env file untuk Docker Compose di host
  cat <<EOF >"$ROOT_DIR/.env"
# Variabel ini digunakan oleh docker-compose.yml
COMPOSE_PROJECT_NAME=${PROJECT_NAME}
PROJECT_NAME=${PROJECT_NAME}
EOF

  # .gitignore
  cat <<EOF >"$ROOT_DIR/.gitignore"
# Docker data
db/data/
# Dependencies
src/vendor/
src/node_modules/
# IDE & OS files
.idea/
.vscode/
.DS_Store
# Environment files
.env
src/.env
EOF
}

# Fungsi untuk menghasilkan file docker-compose.yml dengan konfigurasi dinamis
generate_docker_compose() {
  local ROOT_DIR="$1"

  log_info "🐋 Membuat file docker-compose.yml..."
  cat <<EOF >"$ROOT_DIR/docker-compose.yml"
services:
  php:
    build:
      context: ./php
    container_name: \${COMPOSE_PROJECT_NAME}_php
    # Teruskan variabel PROJECT_NAME ke dalam kontainer
    environment:
      - PROJECT_NAME=\${PROJECT_NAME}
      - XDEBUG=\${XDEBUG:-false}
    volumes:
      - ./src:/var/www/html
    depends_on:
      db:
        condition: service_healthy
  nginx:
    build:
      context: ./nginx
    container_name: \${COMPOSE_PROJECT_NAME}_nginx
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
    container_name: \${COMPOSE_PROJECT_NAME}_db
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
      MYSQL_DATABASE: \${PROJECT_NAME}
      MYSQL_ROOT_PASSWORD: p455w0rd
    volumes:
      - ./db/conf.d:/etc/mysql/conf.d
      - ./db/data:/var/lib/mysql
EOF
  log_success " 🐳 File docker-compose.yml berhasil dibuat..."
}

# Fungsi untuk memperbarui file hosts di WSL dan Windows
update_hosts_file() {
  local HOST_ENTRY="$1"
  local DOMAIN="$2"

  log_info "Memeriksa file hosts..."
  if ! grep -q "$HOST_ENTRY" /etc/hosts; then
    log_info "Menambahkan $DOMAIN ke /etc/hosts WSL (membutuhkan sudo)..."
    echo "$HOST_ENTRY" | sudo tee -a /etc/hosts >/dev/null
  fi
  local win_hosts_path="/c/Windows/System32/drivers/etc/hosts"
  if grep -q "$HOST_ENTRY" "$win_hosts_path" &>/dev/null; then
    log_success "$DOMAIN sudah ada di file hosts Windows."
    return
  fi
  log_info "Mencoba memperbarui file hosts Windows..."
  log_warning " ⚠️  PERHATIKAN DESKTOP ANDA! Pop-up UAC akan muncul meminta izin Administrator."
  local ps_script_path_win="C:\\Windows\\Temp\\update_hosts.ps1"
  local ps_script_path_wsl="/c/Windows/Temp/update_hosts.ps1"
  cat <<EOF > "$ps_script_path_wsl"
\$HostFile = "C:\\Windows\\System32\\drivers\\etc\\hosts"
\$Entry = "$HOST_ENTRY"
if (!(Select-String -Path \$HostFile -Pattern \$Entry -Quiet)) { Add-Content -Path \$HostFile -Value \$Entry }
EOF
  powershell.exe -Command "Start-Process powershell.exe -ArgumentList '-ExecutionPolicy Bypass -File \"$ps_script_path_win\"' -Verb RunAs"
  sleep 3
  if grep -q "$HOST_ENTRY" "$win_hosts_path" &>/dev/null; then
    log_success "File hosts Windows berhasil diperbarui."
  else
    log_warning "Gagal memperbarui file hosts Windows. Lakukan secara manual!!!"
  fi
}

# Fungsi untuk menampilkan langkah akhir dan informasi proyek setelah setup selesai
start_containers() {
  read -p "🚀 Mulai proyek dengan Docker Compose sekarang? (y/n): " start_now
  if [[ "$start_now" =~ ^[Yy]$ ]]; then
    log_info " 🛠️ Membangun dan menjalankan kontainer..."
    docker compose up -d --build
    log_success " 📢 Kontainer sedang berjalan di latar belakang. Anda bisa melihat log dengan 'docker compose logs -f'"
  fi
}

# Fungsi untuk membuat repositori GitHub dan melakukan push awal
create_github_repo() {
  local SCRIPT_DIR="$1"
  local PROJECT_NAME="$2"
  read -p " 🌐 Mau buat repositori GitHub untuk proyek ini? (y/n): " create_repo
  if [[ ! "$create_repo" =~ ^[Yy]$ ]]; then
    return
  fi
  local GITHUB_USER
  if [ -f "$SCRIPT_DIR/.github-user" ]; then
    GITHUB_USER=$(<"$SCRIPT_DIR/.github-user")
  else
    read -p "👤 Masukkan username GitHub Anda: " GITHUB_USER
    echo "$GITHUB_USER" >"$SCRIPT_DIR/.github-user"
  fi
  local GITHUB_TOKEN
  if [ -f "$SCRIPT_DIR/.github-token" ]; then
    GITHUB_TOKEN=$(<"$SCRIPT_DIR/.github-token")
  else
    read -s -p "🔑 Masukkan GitHub Personal Access Token Anda (token klasik): " GITHUB_TOKEN
    echo
    echo "$GITHUB_TOKEN" >"$SCRIPT_DIR/.github-token"
  fi
  local REPO_NAME="${PROJECT_NAME}-$(date +%Y)"
  log_info " 🚨 Mencoba membuat repositori GitHub: $GITHUB_USER/$REPO_NAME"
  local RESPONSE
  RESPONSE=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" -d "{\"name\":\"$REPO_NAME\", \"private\":false}" "https://api.github.com/user/repos")
  local BODY
  BODY=$(echo "$RESPONSE" | sed '$d')
  local STATUS
  STATUS=$(echo "$RESPONSE" | tail -n1)
  local GITHUB_HTTPS="https://github.com/$GITHUB_USER/$REPO_NAME.git"
  if [ "$STATUS" = "201" ]; then
    log_success " 🤩 Repositori GitHub '$REPO_NAME' berhasil dibuat..."
  elif [ "$STATUS" = "422" ]; then
    log_warning "Repositori '$REPO_NAME' sudah ada. Melanjutkan..."
  else
    log_error " ⚠️ Gagal membuat repositori. Status: $STATUS. Pesan: $BODY"
    return
  fi
  log_info " 🚨 Inisialisasi Git dan push awal..."

# Generate README otomatis
cat > README.md <<EOF
### ⚠️ Noted:
Readme ini dibuat secara otomatis menggunakan skrip start.sh dengan template yang sudah disiapkan. 
Anda bisa mengeditnya sesuai kebutuhan setelah proyek dibuat

<div align="center">

# 🚀 $PROJECT_NAME

### Laravel Boilerplate Project $(date +%Y)

Built with ❤️ using Laravel, Docker, WSL & Filament

![Laravel](https://img.shields.io/badge/Laravel-11-FF2D20?style=for-the-badge&logo=laravel&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-8.3-777BB4?style=for-the-badge&logo=php&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=for-the-badge&logo=mariadb&logoColor=white)
![Filament](https://img.shields.io/badge/Filament-v3-F59E0B?style=for-the-badge)

[![GitHub](https://img.shields.io/badge/Open-GitHub-black?style=for-the-badge&logo=github)](https://github.com/$GITHUB_USER/$PROJECT_NAME-$(date +%Y))

</div>

---

## 📖 Tentang Project

**$PROJECT_NAME** merupakan aplikasi berbasis Laravel yang dibuat menggunakan **Ilham Boilerplate $(date +%Y)**.

Project ini sudah dikonfigurasi dengan berbagai kebutuhan modern untuk pengembangan aplikasi web.

---

## ✨ Fitur Bawaan

- ✅ Laravel
- ✅ Docker Environment
- ✅ Nginx Web Server
- ✅ PHP 8.3
- ✅ MariaDB
- ✅ Filament Admin Panel
- ✅ GitHub Integration
- ✅ WSL Ubuntu Support
- ✅ HTTPS Local Domain
- ✅ Seeder & Migration Ready

---

## 🚀 Quick Start

### Menjalankan Docker

\`\`\`bash
docker compose up -d
\`\`\`

atau

\`\`\`bash
dcu
\`\`\`

### Masuk Container PHP

\`\`\`bash
docker compose exec php bash
\`\`\`

### Menjalankan Migration

\`\`\`bash
php artisan migrate
\`\`\`

### Menjalankan Seeder

\`\`\`bash
php artisan db:seed
\`\`\`

### Mematikan Docker
\`\`\`bash
docker compose down
\`\`\`

atau

\`\`\`bash
dcd
\`\`\`

---

## 🌐 URL Aplikasi

### Website Proyek

\`\`\`text
https://$PROJECT_NAME.test
\`\`\`

### Admin Panel

\`\`\`text
https://$PROJECT_NAME.test/admin
\`\`\`

---

## 🐳 Docker Services

| Service | Port |
|----------|----------|
| Nginx | 80 / 443 |
| PHP-FPM | Internal |
| MariaDB | 13306 |

---

## 📂 Struktur Project

\`\`\`text
app/
bootstrap/
config/
database/
public/
resources/
routes/
storage/
tests/
\`\`\`

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
| \`dcu\` | Jalankan Docker Compose |
| \`dcd\` | Matikan Docker Compose |
| \`dca\` | Masuk ke dalam kontainer PHP dan jalankan perintah Artisan |
| \`dcp "pesan"\` | Git add, commit, pull --rebase, dan push dengan pesan commit |
| \`dcm ModelName\` | | Buat model Laravel lengkap dengan migration, seeder, controller, policy, dan resource Filament |
| \`dcr ModelName\` | Hapus file model, migration, seeder, controller, policy, dan resource Filament untuk model yang diberikan |
| \`code .\` | Buka proyek di Visual Studio Code |

---

## 👨‍💻 Developer

**$GITHUB_USER**

Generated automatically using:

\`\`\`text
Ilham Boilerplate $(date +%Y)
\`\`\`

---

## 🎯 Quote of The Project

> "Konsistensi Mengalahkan Bakat Saat Bakat Tidak Muncul."

🔥 Happy Coding!!!
EOF

  git init
  git branch -M main
  git add .
  git commit -m "🎉 Initial commit"
  git remote add origin "$GITHUB_HTTPS"
  git push -u origin main
  log_success "Proyek berhasil di-push otomatis ke GitHub Nih..."
}

# Fungsi untuk memperbarui file .zshrc dengan alias dan fungsi khusus untuk proyek
update_zshrc() {
  local ZSHRC_FILE="$1"
  log_info "Memperbarui fungsi dan alias di $ZSHRC_FILE..."
  sed -i.bak '/# === BOILERPLATE START ===/,/# === BOILERPLATE END ===/d' "$ZSHRC_FILE"
  cat <<'EOF' >>"$ZSHRC_FILE"

# === ALIAS & FUNCTIONS UNTUK PROYEK BOILERPLATE ===
# === BOILERPLATE START ===
_get_php_container_name() { docker ps --filter "name=_php" --format "{{.Names}}" | head -n 1; } 
dcr() { [ -z "$1" ] && { echo "❌ Usage: dcr <ModelName>"; return 1; }; local C=$(_get_php_container_name); [ -z "$C" ] && { echo "❌ Kontainer PHP tidak ditemukan."; return 1; }; local N="$1"; local NS=$(echo "$N" | sed -E 's/([a-z])([A-Z])/\1_\2/g' | tr '[:upper:]' '[:lower:]'); local NP="${NS}s"; echo "🗑 Menghapus file untuk '$N'..."; docker exec "$C" rm -f "app/Models/$N.php" "app/Http/Controllers/${N}Controller.php" "database/seeders/${N}Seeder.php" "app/Policies/${N}Policy.php"; docker exec "$C" find database/migrations -type f -name "*create_${NP}_table.php" -delete; docker exec "$C" rm -rf "app/Filament/Admin/Resources/${N}Resource.php"; }
dcm() { [ -z "$1" ] && { echo "❌ Usage: dcm <ModelName>"; return 1; }; local C=$(_get_php_container_name); [ -z "$C" ] && { echo "❌ Kontainer PHP tidak ditemukan."; return 1; }; docker exec -it "$C" php artisan make:model "$1" -msc; docker exec -it "$C" php artisan make:filament-resource "$1" --generate; }
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

    echo "✅ Push berhasil..., Mantappp 👍"
}
dcd() { local P=$(docker ps --format "{{.Names}}" | grep _php | head -n 1 | cut -d'_' -f1); [ -n "$P" ] && docker compose -p "$P" down || echo "❌ Tidak dapat mendeteksi proyek."; }
alias dcu='docker compose up -d'
alias dca='docker exec -it $(_get_php_container_name) php artisan'
alias dci='docker exec -it $(docker ps --filter "name=_php" --format "{{.Names}}" | head -n 1) php artisan project:init'
# === BOILERPLATE END ===
EOF
}

# Fungsi untuk menampilkan langkah akhir dan informasi proyek setelah setup selesai
final_steps() {
  local ROOT_DIR="$1"
  local PROJECT_NAME="$2"
  local SCRIPT_DIR="$3"
  local GITHUB_USER="unknown"

  if [ -f "$SCRIPT_DIR/.github-user" ]; then
    GITHUB_USER=$(<"$SCRIPT_DIR/.github-user")
  fi
  log_info "🧠 Membuka proyek di Visual Studio Code..."
  code "$ROOT_DIR"
  log_success "🎉 Aishh Gantengg, Project '$PROJECT_NAME' berhasil dibuat!"
  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║              🎉 PROJECT BERHASIL DIBUAT 🎉              ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""

  echo "🚀 Nama Project : $PROJECT_NAME"
  echo "📅 Tahun        : $(date +%Y)"
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
  echo "   /root/perkuliahan/${PROJECT_NAME}"
  echo ""

  echo "🐳 Docker Status"
  echo "   docker compose ps"
  echo ""

  echo "🔗 Repository GitHub"
  echo "   https://github.com/${GITHUB_USER}/${PROJECT_NAME}-"$(date +%Y)
  echo ""

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  echo "💡 Langkah Selanjutnya"
  echo ""
  echo "1. code ."
  echo "2. docker compose ps"
  echo "3. php artisan migrate"
  echo "4. php artisan db:seed"
  echo ""

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  echo "🛠️ Commands"
  echo "   dcu            # docker compose up -d"
  echo "   dcd            # docker compose down"
  echo "   dca            # docker exec -it <php_container> php artisan"
  echo "   dcp \"pesan\"    # git add, commit, pull --rebase, push dengan pesan commit"
  echo "   dcm ModelName  # buat model + migration + seeder + controller + policy + filament resource"
  echo "   dcr ModelName  # hapus file model, migration, seeder, controller, policy, filament resource"
  echo ""

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""


  QUOTES=(
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
  RANDOM_QUOTE=${QUOTES[$RANDOM % ${#QUOTES[@]}]}

  echo "$RANDOM_QUOTE"
  echo ""
  echo "Semoga project ini bisa jadi awal yang baik untuk perjalanan coding kamu. Jangan lupa untuk terus belajar dan eksplorasi hal baru. Happy coding!!!"
  echo ""

  echo "Generated by Ilham Boilerplate " $(date +%Y)

  log_info "Direktori/Lokasi proyek: $ROOT_DIR"
  log_info "Memuat ulang shell Zsh untuk menerapkan alias baru..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exec zsh
}

# --- Jalankan Skrip ---
main "$@"

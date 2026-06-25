#!/bin/bash
set -euo pipefail

echo "⚠️  WARNING!"
echo "Script ini akan menghapus:"
echo "- Semua Docker containers"
echo "- Semua Docker volumes"
echo "- Semua user-defined networks"
echo "- Semua unused images/cache"
echo ""
echo "Database project Docker bisa ikut hilang."
echo ""

read -rp "Ketik CLEAN untuk lanjut: " confirm
if [[ "$confirm" != "CLEAN" ]]; then
  echo "❌ Dibatalkan."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker tidak berjalan."
  exit 1
fi

echo "🛑 Menghapus semua containers..."
docker rm -f $(docker ps -aq) 2>/dev/null || echo "ℹ️ Tidak ada container."

echo "📦 Menghapus semua volumes..."
docker volume rm -f $(docker volume ls -q) 2>/dev/null || echo "ℹ️ Tidak ada volume."

echo "🌐 Menghapus user-defined networks..."
docker network rm $(docker network ls --format '{{.Name}}' | grep -vE '^(bridge|host|none)$') 2>/dev/null || echo "ℹ️ Tidak ada network custom."

echo "🧼 Membersihkan image/cache..."
docker system prune -a --volumes -f

echo "✅ Docker environment berhasil dibersihkan."
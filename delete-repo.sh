#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "❌ Usage: $0 <repo-prefix>"
  echo "✅ Example: $0 test-"
  exit 1
fi

PREFIX="$1"

if [ ! -f ".github-user" ] || [ ! -f ".github-token" ]; then
  echo "❌ File .github-user atau .github-token tidak ditemukan."
  exit 1
fi

GITHUB_USER=$(<.github-user)
GITHUB_TOKEN=$(<.github-token)

echo "🔍 Mencari repository milik: $GITHUB_USER"
echo "🏷️ Prefix: $PREFIX"
echo ""

REPOS=$(curl -s \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/user/repos?per_page=100" | \
  jq -r --arg prefix "^$PREFIX" '.[] | select(.name | test($prefix)) | .full_name')

if [ -z "$REPOS" ]; then
  echo "ℹ️ Tidak ada repository dengan prefix '$PREFIX'."
  exit 0
fi

echo "⚠️ Repository yang akan dihapus:"
echo "$REPOS" | sed 's/^/  🗑️  /'
echo ""

read -rp "Ketik DELETE untuk lanjut menghapus: " CONFIRM

if [ "$CONFIRM" != "DELETE" ]; then
  echo "❌ Dibatalkan."
  exit 1
fi

for REPO in $REPOS; do
  echo "🚨 Menghapus $REPO..."
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X DELETE \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO")

  if [ "$STATUS" = "204" ]; then
    echo "✅ Berhasil menghapus $REPO"
  else
    echo "❌ Gagal menghapus $REPO. Status: $STATUS"
  fi
done

echo ""
echo "✅ Selesai."
#!/bin/sh
set -e

# Copier .env.example si .env absent (premier déploiement sans volume persisté)
if [ ! -f .env ]; then
  echo "==> .env absent, copie depuis .env.example"
  cp .env.example .env
fi

if [ -z "$APP_KEY" ] && ! grep -q "APP_KEY=base64:" .env 2>/dev/null; then
  echo "==> key:generate (première initialisation)"
  php artisan key:generate --force
fi

echo "==> migrate"
php artisan migrate --force

echo "==> storage:link"
php artisan storage:link || true

# Configuration automatique du fichier de clé JaaS si JAAS_PRIVATE_KEY est présent
if [ -n "$JAAS_PRIVATE_KEY" ]; then
  echo "==> configuration clé privée JaaS..."
  mkdir -p storage/app/jaas
  if echo "$JAAS_PRIVATE_KEY" | grep -q "^LS0t"; then
    echo "$JAAS_PRIVATE_KEY" | base64 -d > storage/app/jaas/edoctor_privatekey.pk
  else
    printf "%b\n" "$JAAS_PRIVATE_KEY" > storage/app/jaas/edoctor_privatekey.pk
  fi
  chmod 600 storage/app/jaas/edoctor_privatekey.pk
fi

echo "==> cache"
php artisan config:cache
php artisan route:cache
php artisan view:cache

echo "==> starting server on port ${PORT:-8000}"
exec php artisan serve --host=0.0.0.0 --port="${PORT:-8000}"

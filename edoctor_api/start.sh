#!/bin/sh

# Copier .env.example si .env absent (premier déploiement sans volume persisté)
if [ ! -f .env ]; then
  echo "==> .env absent, copie depuis .env.example"
  cp .env.example .env
fi

if [ -z "$APP_KEY" ] && ! grep -q "APP_KEY=base64:" .env 2>/dev/null; then
  echo "==> key:generate (première initialisation)"
  php artisan key:generate --force || true
fi

echo "==> migrate"
php artisan migrate --force || true

echo "==> storage:link"
php artisan storage:link || true

# Configuration automatique du fichier de clé JaaS si JAAS_PRIVATE_KEY est présent
if [ -n "$JAAS_PRIVATE_KEY" ]; then
  echo "==> configuration clé privée JaaS..."
  mkdir -p storage/app/jaas
  if echo "$JAAS_PRIVATE_KEY" | grep -q "^LS0t"; then
    echo "$JAAS_PRIVATE_KEY" | base64 -d > storage/app/jaas/edoctor_privatekey.pk 2>/dev/null || true
  else
    printf "%b\n" "$JAAS_PRIVATE_KEY" > storage/app/jaas/edoctor_privatekey.pk 2>/dev/null || true
  fi
  chmod 600 storage/app/jaas/edoctor_privatekey.pk 2>/dev/null || true
fi

echo "==> cache"
php artisan config:clear || true
php artisan route:clear || true
php artisan config:cache || true
php artisan route:cache || true
php artisan view:cache || true

echo "==> starting server on port ${PORT:-8000}"
exec php artisan serve --host=0.0.0.0 --port="${PORT:-8000}"

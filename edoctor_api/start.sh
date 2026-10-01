#!/bin/sh
set -e

# Copier .env.example si .env absent (premier déploiement sans volume persisté)
if [ ! -f .env ]; then
  echo "==> .env absent, copie depuis .env.example"
  cp .env.example .env
fi

echo "==> key:generate"
php artisan key:generate --force

echo "==> migrate"
php artisan migrate --force

echo "==> storage:link"
php artisan storage:link || true

echo "==> cache"
php artisan config:cache
php artisan route:cache
php artisan view:cache

echo "==> starting server on port ${PORT:-8000}"
exec php artisan serve --host=0.0.0.0 --port="${PORT:-8000}"

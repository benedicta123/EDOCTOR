# ==========================================
# Étape 1 : Compilation Flutter Web
# ==========================================
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

# Optimisation du cache Docker pour les dépendances
COPY pubspec.yaml ./
RUN flutter pub get

# Copie du code source et compilation Web
COPY . .
RUN flutter build web --release

# ==========================================
# Étape 2 : Serveur Web Nginx ultra-léger
# ==========================================
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

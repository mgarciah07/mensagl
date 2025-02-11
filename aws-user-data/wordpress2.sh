#!/bin/bash

######## Verificar si el script esta siendo ejecutado por el usuario root
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ser ejecutado como root."
    exit 1  # Salir con un codigo de error
else
echo "Eres root. Ejecutando el comando..."


# Variables
DB_NAME="wordpress"
DB_USER="wordpress"
DB_PASSWORD="Admin123"
DB_HOST="instancias-reto-mysqlrds-nyoyclo3kfeh.cwvnqbc5y9vt.us-east-1.rds.amazonaws.com"
WP_URL="https://marcosticket.duckdns.org/"
WP_DIR="/var/www/html/wordpress"
NEW_LOGIN_PATH="acceso-admin"
WP_PREFIX="equipo1_"

# Instalamos dependencias
echo "🔄 Instalando Apache y PHP..."
apt update
apt install -y apache2 mysql-client php libapache2-mod-php php-mysql wget unzip curl php-cli php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip php-ftp

# Verificar si WP-CLI está instalado
if ! command -v wp &> /dev/null; then
    echo "🛠️ Instalando WP-CLI..."
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
    echo "✅ WP-CLI instalado correctamente."
else
    echo "✅ WP-CLI ya está instalado."
fi

# Validar que WP-CLI funciona correctamente
if ! wp --info &> /dev/null; then
    echo "❌ WP-CLI no se encuentra en el PATH. Verifica la instalación manualmente."
    exit 1
fi

# Descargamos WordPress si no existe
if [ ! -d "$WP_DIR" ]; then
    echo "📥 Descargando WordPress..."
    cd /var/www/html
    wget -q https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    mv wordpress "/var/html/www/"
    rm -f latest.tar.gz
else
    echo "✅ WordPress ya está descargado."
fi

# Configurar wp-config.php sin modificar la base de datos
if [ ! -f "$WP_DIR/wp-config.php" ]; then
    echo "📝 Creando wp-config.php..."
    cp "$WP_DIR/wp-config-sample.php" "$WP_DIR/wp-config.php"
    sed -i "s/database_name_here/$DB_NAME/" "$WP_DIR/wp-config.php"
    sed -i "s/username_here/$DB_USER/" "$WP_DIR/wp-config.php"
    sed -i "s/password_here/$DB_PASSWORD/" "$WP_DIR/wp-config.php"
    sed -i "s/localhost/$DB_HOST/" "$WP_DIR/wp-config.php"
    sed -i "s/\$table_prefix = 'wp_';/\$table_prefix = '${WP_PREFIX}';/" "$WP_DIR/wp-config.php"

    echo "🔧 Configurando HTTPS detrás de HAProxy..."
    cat <<EOL >> "$WP_DIR/wp-config.php"

    # Forzar HTTPS si está detrás de un proxy como HAProxy
    if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
    }
EOL

    echo "define('FS_METHOD', 'direct');" >> "$WP_DIR/wp-config.php"
    echo "define('WP_SITEURL', '$WP_URL');" >> "$WP_DIR/wp-config.php"
    echo "define('WP_HOME', '$WP_URL');" >> "$WP_DIR/wp-config.php"
else
    echo "✅ wp-config.php ya existe, no se modifica."
fi

# Verificar conexión a la base de datos sin modificar las tablas
echo "🔎 Verificando conexión a la base de datos..."
wp db check --allow-root --path="$WP_DIR"
if [ $? -ne 0 ]; then
    echo "❌ Error: No se puede conectar a la base de datos. Verifica las credenciales en wp-config.php"
    exit 1
fi

echo "✅ Conexión exitosa a la base de datos."

# Configurar permisos
echo "🔑 Configurando permisos..."
chown -R www-data:www-data "$WP_DIR"
find "$WP_DIR" -type d -exec chmod 755 {} \;
find "$WP_DIR" -type f -exec chmod 644 {} \;

# Configurar Apache
echo "🌐 Configurando Apache..."
a2enmod rewrite
sed -i 's|DocumentRoot .*|DocumentRoot /var/www/html/wordpress|' /etc/apache2/sites-available/000-default.conf
systemctl restart apache2

# Instalar idioma si no está presente
echo "🌍 Verificando idioma de WordPress..."
wp core language install es_ES --allow-root --path="$WP_DIR"
wp site switch-language es_ES --allow-root --path="$WP_DIR"

# Instalar y activar plugins si no están activados
echo "📦 Verificando plugins..."
PLUGINS=("supportcandy" "ultimate-member" "wps-hide-login")

for PLUGIN in "${PLUGINS[@]}"; do
    if ! wp plugin is-active "$PLUGIN" --allow-root --path="$WP_DIR"; then
        echo "📥 Instalando y activando $PLUGIN..."
        wp plugin install "$PLUGIN" --activate --allow-root --path="$WP_DIR"
    else
        echo "✅ Plugin $PLUGIN ya está activado."
    fi
done

# Configurar seguridad en .htaccess si no existe
HTACCESS_FILE="$WP_DIR/.htaccess"
if [ ! -f "$HTACCESS_FILE" ]; then
    echo "🔒 Configurando .htaccess para seguridad..."
    cat <<EOL > "$HTACCESS_FILE"
# Bloquear acceso a archivos críticos
<FilesMatch "\.htaccess|htpasswd|wp-config\.php|xmlrpc\.php|readme\.html|license\.txt$">
    Order Allow,Deny
    Deny from all
</FilesMatch>

# Bloquear ejecución de archivos PHP en uploads, plugins y themes
<Directory "$WP_DIR/wp-content/uploads">
    <FilesMatch "\.php$">
        Order Allow,Deny
        Deny from all
    </FilesMatch>
</Directory>

<Directory "$WP_DIR/wp-content/plugins">
    <FilesMatch "\.php$">
        Order Allow,Deny
        Deny from all
    </FilesMatch>
</Directory>

<Directory "$WP_DIR/wp-content/themes">
    <FilesMatch "\.php$">
        Order Allow,Deny
        Deny from all
    </FilesMatch>
</Directory>

# Desactivar listado de directorios
Options -Indexes
EOL
else
    echo "✅ .htaccess ya existe, no se modifica."
fi

# Configurar URL de acceso personalizado con WPS Hide Login
echo "🔧 Configurando WPS Hide Login..."
wp option update whl_page "$NEW_LOGIN_PATH" --allow-root --path="$WP_DIR"

echo "✅ Instalación y configuración completadas."
echo "🔗 Ahora puedes acceder a WordPress en: ${WP_URL}${NEW_LOGIN_PATH}"

fi
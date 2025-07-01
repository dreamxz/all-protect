#!/bin/bash

# ============================================
# 🛡️ PTERODACTYL ALL-IN-ONE PROTECT INSTALLER
# ============================================

DB_USER="root"
PANEL_DIR="/var/www/pterodactyl"
ENV_FILE="$PANEL_DIR/.env"

# Ambil nama database dari .env Laravel
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Tidak menemukan file .env di $PANEL_DIR"
  exit 1
fi

DB=$(grep DB_DATABASE "$ENV_FILE" | cut -d '=' -f2)

if [[ -z "$DB" ]]; then
  echo "❌ Gagal membaca nama database dari .env"
  exit 1
fi

echo "📦 Menggunakan database: $DB"

# ===============================
# 1. ANTI DELETE USER & SERVER
# ===============================
echo "🔐 Memasang Anti-Delete User & Server..."
mysql -u $DB_USER <<EOF
USE $DB;

DROP TRIGGER IF EXISTS prevent_user_delete;
DROP TRIGGER IF EXISTS prevent_server_delete;

DELIMITER $$
CREATE TRIGGER prevent_user_delete
BEFORE DELETE ON users
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = '❌ Penghapusan user diblokir!';
END$$

CREATE TRIGGER prevent_server_delete
BEFORE DELETE ON servers
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = '❌ Penghapusan server diblokir!';
END$$
DELIMITER ;

EOF

# ===============================
# 2. ANTI DELETE NODE
# ===============================
echo "🛑 Memasang Anti-Delete Node..."
mysql -u $DB_USER <<EOF
USE $DB;

DROP TRIGGER IF EXISTS prevent_node_delete;

DELIMITER $$
CREATE TRIGGER prevent_node_delete
BEFORE DELETE ON nodes
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = '❌ Penghapusan node diblokir!';
END$$
DELIMITER ;

EOF

# ===============================
# 3. ANTI DELETE EGG
# ===============================
echo "🥚 Memasang Anti-Delete Egg..."
mysql -u $DB_USER <<EOF
USE $DB;

DROP TRIGGER IF EXISTS prevent_egg_delete;

DELIMITER $$
CREATE TRIGGER prevent_egg_delete
BEFORE DELETE ON eggs
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = '❌ Penghapusan egg diblokir!';
END$$
DELIMITER ;

EOF

# ===============================
# 4. ANTI EDIT SETTING
# ===============================
echo "⚙️ Memasang Anti-Edit Setting..."
mysql -u $DB_USER <<EOF
USE $DB;

DROP TRIGGER IF EXISTS prevent_setting_edit;

DELIMITER $$
CREATE TRIGGER prevent_setting_edit
BEFORE UPDATE ON settings
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = '❌ Perubahan setting diblokir!';
END$$
DELIMITER ;

EOF

# ===============================
# 5. ANTI INTIP PANEL (LARAVEL)
# ===============================
echo "🕶️ Memasang Anti-Intip Panel..."
if [[ -d "$PANEL_DIR" ]]; then
  cd "$PANEL_DIR"
  BACKUP="app/Repositories/Eloquent/ServerRepository.php.bak"
  TARGET="app/Repositories/Eloquent/ServerRepository.php"

  if [[ ! -f "$BACKUP" ]]; then
    cp "$TARGET" "$BACKUP"
  fi

  sed -i "/public function getUserServers/i\\
    \\t// Anti-intip filter otomatis\n\
    \\tif (!\$user->root_admin) {\n\
    \\t    \$this->model = \$this->model->where('owner_id', \$user->id);\n\
    \\t}" "$TARGET"

  echo "✅ Anti-intip Laravel berhasil dipasang!"
else
  echo "❌ Panel tidak ditemukan di: $PANEL_DIR"
fi

# ===============================
# SELESAI
# ===============================
echo ""
echo "✅ SEMUA PROTEKSI TELAH DIPASANG!"
echo "📌 Jalankan di VPS:"
echo "php artisan config:clear && php artisan cache:clear"

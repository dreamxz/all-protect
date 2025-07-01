#!/bin/bash

# ============================================
# 🛡️ PTERODACTYL ALL-IN-ONE PROTECT INSTALLER
# ============================================

DB="panel"
DB_USER="root"
ADMIN_ID=1
PANEL_DIR="/var/www/pterodactyl"

# Cek apakah root
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ Jalankan sebagai root!"
  exit 1
fi

echo "🚀 Memulai instalasi semua proteksi ke panel Pterodactyl..."

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
  IF OLD.id != $ADMIN_ID THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Hanya admin utama yang boleh hapus user!';
  END IF;
END$$

CREATE TRIGGER prevent_server_delete
BEFORE DELETE ON servers
FOR EACH ROW
BEGIN
  IF OLD.owner_id != $ADMIN_ID THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Hanya admin utama yang boleh hapus server!';
  END IF;
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
  IF (SELECT id FROM users WHERE id = OLD.created_by) != $ADMIN_ID THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Hanya admin utama yang boleh hapus node!';
  END IF;
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
  IF (SELECT id FROM users WHERE id = OLD.author_id) != $ADMIN_ID THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Hanya admin utama yang boleh hapus egg!';
  END IF;
END$$
DELIMITER ;
EOF

# ===============================
# 4. ANTI EDIT SETTINGS
# ===============================
echo "⚙️ Memasang Anti-Edit Settings..."

mysql -u $DB_USER <<EOF
USE $DB;
DROP TRIGGER IF EXISTS prevent_setting_edit;

DELIMITER $$
CREATE TRIGGER prevent_setting_edit
BEFORE UPDATE ON settings
FOR EACH ROW
BEGIN
  IF (SELECT id FROM users WHERE id = NEW.updated_by) != $ADMIN_ID THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Hanya admin utama yang boleh ubah pengaturan!';
  END IF;
END$$
DELIMITER ;
EOF

# ===============================
# 5. ANTI INTIP PANEL
# ===============================
echo "🕶️ Memasang Anti-Intip Panel..."

if [[ -d "$PANEL_DIR" ]]; then
  cd $PANEL_DIR
  BACKUP="app/Repositories/Eloquent/ServerRepository.php.bak"
  TARGET="app/Repositories/Eloquent/ServerRepository.php"

  if [[ ! -f $BACKUP ]]; then
    cp $TARGET $BACKUP
  fi

  sed -i "/public function getUserServers/i\\
    \\t// Anti-intip otomatis (kecuali admin utama)\n\
    \\tif (\$user->id != $ADMIN_ID) {\n\
    \\t    \$this->model = \$this->model->where('owner_id', \$user->id);\n\
    \\t}" $TARGET

  echo "✅ Anti-intip berhasil dipasang!"
else
  echo "❌ Folder panel tidak ditemukan di: $PANEL_DIR"
fi

# ===============================
# SELESAI
# ===============================
echo ""
echo "✅ Semua proteksi telah berhasil dipasang!"
echo "📌 Jalankan ini untuk menyegarkan cache Laravel:"
echo "   php artisan config:clear && php artisan cache:clear"

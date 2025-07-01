#!/bin/bash

# ============================================
# 🛡️ SUPERADMIN-ONLY PROTECTOR (ID 1)
# Blokir semua aksi kecuali oleh admin ID 1
# ============================================

DB_USER="root"
PANEL_DIR="/var/www/pterodactyl"
ENV_FILE="$PANEL_DIR/.env"
TARGET_FILE="$PANEL_DIR/app/Repositories/Eloquent/ServerRepository.php"
BACKUP_FILE="$TARGET_FILE.bak"
SUPERADMIN_ID=1

# Ambil DB name dari .env
DB=$(grep DB_DATABASE "$ENV_FILE" | cut -d '=' -f2)

if [[ -z "$DB" ]]; then
  echo "❌ Gagal baca nama database dari .env"
  exit 1
fi

echo "📦 Menggunakan database: $DB"
echo "🔒 Hanya admin ID $SUPERADMIN_ID yang diizinkan."

# Proteksi database actions
mysql -u $DB_USER <<EOF
USE $DB;

-- Hapus trigger lama
DROP TRIGGER IF EXISTS prevent_user_delete;
DROP TRIGGER IF EXISTS prevent_server_delete;
DROP TRIGGER IF EXISTS prevent_node_delete;
DROP TRIGGER IF EXISTS prevent_egg_delete;
DROP TRIGGER IF EXISTS prevent_setting_edit;

DELIMITER $$

-- Delete User
CREATE TRIGGER prevent_user_delete
BEFORE DELETE ON users
FOR EACH ROW
BEGIN
  IF OLD.id != $SUPERADMIN_ID THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Hanya admin ID 1 yang boleh hapus user!';
  END IF;
END$$

-- Delete Server
CREATE TRIGGER prevent_server_delete
BEFORE DELETE ON servers
FOR EACH ROW
BEGIN
  IF OLD.owner_id != $SUPERADMIN_ID THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Hanya admin ID 1 yang boleh hapus server!';
  END IF;
END$$

-- Delete Node
CREATE TRIGGER prevent_node_delete
BEFORE DELETE ON nodes
FOR EACH ROW
BEGIN
  IF OLD.created_by != $SUPERADMIN_ID THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Hanya admin ID 1 yang boleh hapus node!';
  END IF;
END$$

-- Delete Egg
CREATE TRIGGER prevent_egg_delete
BEFORE DELETE ON eggs
FOR EACH ROW
BEGIN
  IF $SUPERADMIN_ID != 1 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '❌ Hanya admin ID 1 yang boleh hapus egg!';
  END IF;
END$$

-- Edit Settings
CREATE TRIGGER prevent_setting_edit
BEFORE UPDATE ON settings
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = '❌ Hanya admin ID 1 yang boleh edit setting!';
END$$

DELIMITER ;
EOF

# Laravel Anti-Intip (ID 1 only)
echo "🕶️ Memasang Anti-Intip Panel Laravel (khusus ID 1)..."

if [[ -f "$TARGET_FILE" ]]; then
  if [[ ! -f "$BACKUP_FILE" ]]; then
    cp "$TARGET_FILE" "$BACKUP_FILE"
    echo "📦 Backup dibuat: $BACKUP_FILE"
  fi

  awk -v id="$SUPERADMIN_ID" '
  /public function getUserServersUser \$user/, /^}/ {
    if (!done++) {
      print "    public function getUserServers(User $user) {"
      print "        // 🕶️ Hanya admin ID 1 boleh lihat semua server"
      print "        if ($user->id !== " id ") {"
      print "            return $this->model->where(\"owner_id\", $user->id)->get();"
      print "        }"
      print "        return $this->model->get();"
      print "    }"
      next
    }
  }
  { print }
  ' "$BACKUP_FILE" > "$TARGET_FILE"

  echo "✅ Anti-intip Laravel diterapkan untuk hanya admin ID $SUPERADMIN_ID."

  cd "$PANEL_DIR"
  php artisan config:clear
  php artisan cache:clear
  echo "♻️ Laravel cache dibersihkan."

else
  echo "❌ File target Laravel tidak ditemukan: $TARGET_FILE"
fi

echo ""
echo "✅ SEMUA PROTEKSI SUPERADMIN BERHASIL DIPASANG!"

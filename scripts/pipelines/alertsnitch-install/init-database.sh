#!/usr/bin/env bash
set -euo pipefail

# ========= configurations =========
DB_NAME="alertsnitch"
DB_USER="alertsnitch"
DB_PASS="123456"

SQL_BOOTSTRAP="/data/nfs-data/rancher/alertsnitch/sql/0.0.1-bootstrap.sql"
SQL_FINGERPRINT="/data/nfs-data/rancher/alertsnitch/sql/0.1.0-fingerprint.sql"

# check SQL files
if [[ ! -f "${SQL_BOOTSTRAP}" ]]; then
  echo "ERROR: Cannot find ${SQL_BOOTSTRAP}"
  exit 1
fi

if [[ ! -f "${SQL_FINGERPRINT}" ]]; then
  echo "ERROR: Cannot find ${SQL_FINGERPRINT}"
  exit 1
fi

read -s -p "Input MySQL root password: " ROOT_PASS
echo

echo ">>> Creating database and user..."

mysql -u root -p"${ROOT_PASS}" <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_general_ci;

CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';

GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

echo ">>> Importing bootstrap SQL script: ${SQL_BOOTSTRAP}"
mysql -u root -p"${ROOT_PASS}" "${DB_NAME}" < "${SQL_BOOTSTRAP}"

echo ">>> Importing fingerprint SQL script: ${SQL_FINGERPRINT}"
mysql -u root -p"${ROOT_PASS}" "${DB_NAME}" < "${SQL_FINGERPRINT}"

echo ">>> Initialization complete. You can connect using the following credentials:"
echo "    Database: ${DB_NAME}"
echo "    Username: ${DB_USER}"
echo "    Password: ${DB_PASS}"
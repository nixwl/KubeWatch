#!/usr/bin/env bash
set -euo pipefail

# ==============================================
# AlertSnitch MySQL export script
# - Export all base tables to TSV
# - Export lifecycle view to closed_loop_alerts.tsv
# ==============================================

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-3306}"
USER="${USER:-exporter}"
DB="${DB:-alertsnitch}"
OUTDIR_BASE="${OUTDIR_BASE:-.}"
ONLY_CLOSED="${ONLY_CLOSED:-false}"  # true -> keep only alerts with episode_endsAt

if ! command -v mysql >/dev/null 2>&1; then
  echo "[ERROR] mysql client not found in PATH." >&2
  exit 1
fi

OUTDIR="${OUTDIR_BASE%/}/export_${DB}_$(date +%F_%H%M%S)"
TSVDIR="${OUTDIR}/tsv"
mkdir -p "$TSVDIR"

# Keep password interactive: do not provide password in command line
MYSQL_BASE=(mysql -h "$HOST" -P "$PORT" -u "$USER" -p --default-character-set=utf8mb4)

echo "Exporting database: $DB"
echo "Output directory: $TSVDIR"
echo "Note: mysql will prompt for password."

# 1) Export all base tables
TABLES=$("${MYSQL_BASE[@]}" --batch --skip-column-names -e "
SELECT table_name
FROM information_schema.tables
WHERE table_schema='${DB}'
  AND table_type='BASE TABLE'
ORDER BY table_name;
")

while IFS= read -r tbl; do
  [[ -z "$tbl" ]] && continue
  qtbl=${tbl//\`/\`\`} # escape backticks in table name

  echo "  -> ${tbl}.tsv"
  "${MYSQL_BASE[@]}" \
    --database="$DB" \
    --batch --quick \
    --binary-as-hex \
    -e "SELECT * FROM \`${qtbl}\`;" \
    > "${TSVDIR}/${tbl}.tsv"
done <<< "$TABLES"

echo "Base table export completed."

# 2) Export closed-loop lifecycle data
CLOSED_LOOP_SQL=$(cat <<'SQL'
SET SESSION group_concat_max_len = 1000000;

SELECT
  a.fingerprint AS fingerprint,
  a.startsAt AS episode_startsAt,
  MAX(a.endsAt) AS episode_endsAt,

  SUBSTRING_INDEX(GROUP_CONCAT(a.status ORDER BY g.time, a.ID), ',', 1) AS start_status,
  SUBSTRING_INDEX(GROUP_CONCAT(a.status ORDER BY g.time DESC, a.ID DESC), ',', 1) AS end_status,

  MIN(g.time) AS first_received_at,
  MAX(g.time) AS last_received_at,

  (
    SELECT g3.groupKey
    FROM `Alert` a3
    JOIN `AlertGroup` g3 ON g3.ID = a3.alertGroupID
    WHERE a3.fingerprint = a.fingerprint
      AND a3.startsAt = a.startsAt
    ORDER BY g3.time, a3.ID
    LIMIT 1
  ) AS groupKey,

  GROUP_CONCAT(DISTINCT g.receiver ORDER BY g.receiver SEPARATOR ',') AS receivers,

  (
    SELECT GROUP_CONCAT(DISTINCT CONCAT(al.Label, '=', al.Value) ORDER BY al.Label SEPARATOR '|')
    FROM `Alert` a2
    JOIN `AlertLabel` al ON al.AlertID = a2.ID
    WHERE a2.fingerprint = a.fingerprint
      AND a2.startsAt = a.startsAt
  ) AS alert_labels,

  (
    SELECT GROUP_CONCAT(DISTINCT CONCAT(aa.Annotation, '=', aa.Value) ORDER BY aa.Annotation SEPARATOR '|')
    FROM `Alert` a2
    JOIN `AlertAnnotation` aa ON aa.AlertID = a2.ID
    WHERE a2.fingerprint = a.fingerprint
      AND a2.startsAt = a.startsAt
  ) AS alert_annotations,

  (
    SELECT GROUP_CONCAT(DISTINCT CONCAT(gl.GroupLabel, '=', gl.Value) ORDER BY gl.GroupLabel SEPARATOR '|')
    FROM `Alert` a2
    JOIN `AlertGroup` g2 ON g2.ID = a2.alertGroupID
    JOIN `GroupLabel` gl ON gl.AlertGroupID = g2.ID
    WHERE a2.fingerprint = a.fingerprint
      AND a2.startsAt = a.startsAt
  ) AS group_labels,

  (
    SELECT GROUP_CONCAT(DISTINCT CONCAT(cl.Label, '=', cl.Value) ORDER BY cl.Label SEPARATOR '|')
    FROM `Alert` a2
    JOIN `AlertGroup` g2 ON g2.ID = a2.alertGroupID
    JOIN `CommonLabel` cl ON cl.AlertGroupID = g2.ID
    WHERE a2.fingerprint = a.fingerprint
      AND a2.startsAt = a.startsAt
  ) AS common_labels,

  (
    SELECT GROUP_CONCAT(DISTINCT CONCAT(ca.Annotation, '=', ca.Value) ORDER BY ca.Annotation SEPARATOR '|')
    FROM `Alert` a2
    JOIN `AlertGroup` g2 ON g2.ID = a2.alertGroupID
    JOIN `CommonAnnotation` ca ON ca.AlertGroupID = g2.ID
    WHERE a2.fingerprint = a.fingerprint
      AND a2.startsAt = a.startsAt
  ) AS common_annotations

FROM `Alert` a
JOIN `AlertGroup` g ON g.ID = a.alertGroupID
WHERE a.fingerprint IS NOT NULL
GROUP BY a.fingerprint, a.startsAt
__HAVING_CLAUSE__
ORDER BY first_received_at;
SQL
)

if [[ "$ONLY_CLOSED" == "true" ]]; then
  CLOSED_LOOP_SQL="${CLOSED_LOOP_SQL/__HAVING_CLAUSE__/HAVING MAX(a.endsAt) IS NOT NULL}"
else
  CLOSED_LOOP_SQL="${CLOSED_LOOP_SQL/__HAVING_CLAUSE__/}"
fi

echo "  -> closed_loop_alerts.tsv"
"${MYSQL_BASE[@]}" \
  --database="$DB" \
  --batch --quick \
  --binary-as-hex \
  -e "$CLOSED_LOOP_SQL" \
  > "${TSVDIR}/closed_loop_alerts.tsv"

echo "Done. TSV output: ${TSVDIR}"

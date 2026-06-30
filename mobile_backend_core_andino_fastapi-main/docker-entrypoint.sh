#!/bin/sh
set -e

echo "Esperando PostgreSQL..."
until python -c "
import psycopg2, os, sys
try:
    psycopg2.connect(os.environ['DATABASE_URL'])
    sys.exit(0)
except Exception:
    sys.exit(1)
" 2>/dev/null; do
  sleep 2
done
echo "PostgreSQL listo."

echo "Aplicando esquema..."
python - <<'PY'
import psycopg2, os
sql = open("sql/01_schema_bd_core_mobile.sql", encoding="utf-8").read()
conn = psycopg2.connect(os.environ["DATABASE_URL"])
conn.autocommit = True
cur = conn.cursor()
cur.execute(sql)
cur.close()
conn.close()
print("Esquema OK.")
PY

echo "Ejecutando seed..."
python -m scripts.seed_bd_core_mobile || true

echo "Iniciando API en puerto 8003..."
exec uvicorn main:app --host 0.0.0.0 --port 8003

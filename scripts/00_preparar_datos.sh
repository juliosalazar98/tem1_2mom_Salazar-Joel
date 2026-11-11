#!/usr/bin/env bash
# =====================================================================
# 00_preparar_datos.sh
# Práctica individual Hive - Superstore | Joel Salazar
# Prepara el CSV de Kaggle y lo sube a HDFS dentro del clúster
# timveil/docker-hadoop (hadoop-hive-3.1.x-postgres).
#
# Ejecutar desde la raíz del repositorio, en Ubuntu (WSL 2):
#   bash scripts/00_preparar_datos.sh
# Requisito: "Sample - Superstore.csv" descargado en ./dataset/
# =====================================================================
set -euo pipefail

ORIGEN="dataset/Sample - Superstore.csv"
DESTINO="dataset/superstore_utf8.csv"
HDFS_DIR="/user/joelsalazar/superstore/raw"

# 1) Revisión rápida del archivo original
echo "== Archivo original"
file "$ORIGEN"
echo "Líneas (incluye encabezado): $(wc -l < "$ORIGEN")"
head -n 3 "$ORIGEN"

# 2) Normalización:
#    - El CSV de Kaggle viene en Windows-1252 (tiene espacios no separables
#      en algunos nombres de producto). Hive lee UTF-8, así que se convierte.
#    - Se quitan los finales de línea CRLF (\r) para que no queden pegados
#      al último campo (Profit).
iconv -f WINDOWS-1252 -t UTF-8 "$ORIGEN" | sed 's/\r$//' > "$DESTINO"
echo "== Archivo normalizado"
file "$DESTINO"

# 3) Copiar al NameNode y subir a HDFS
docker cp "$DESTINO" namenode:/tmp/superstore_utf8.csv
docker exec namenode hdfs dfs -mkdir -p "$HDFS_DIR"
docker exec namenode hdfs dfs -put -f /tmp/superstore_utf8.csv "$HDFS_DIR/"
docker exec namenode hdfs dfs -ls -h "$HDFS_DIR"

# 4) Copiar los scripts HiveQL al contenedor de HiveServer2
docker exec hs2 mkdir -p /tmp/scripts
docker cp scripts/. hs2:/tmp/scripts/
echo "== Listo. Scripts copiados en hs2:/tmp/scripts"

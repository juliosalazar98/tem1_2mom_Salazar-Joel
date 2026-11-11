#!/usr/bin/env bash
# =====================================================================
# run_all.sh - Ejecuta los scripts HiveQL en orden y guarda la salida
# Práctica individual Hive - Superstore | Joel Salazar
#
# Uso (desde la raíz del repo, en WSL):
#   bash scripts/run_all.sh            -> ejecuta todo
#   bash scripts/run_all.sh P03_region_anual   -> ejecuta solo ese script
#
# Salida:
#   resultados/<script>.txt  -> tablas de resultados (stdout de beeline)
#   resultados/<script>.log  -> mensajes y tiempos ("N rows selected (X seconds)")
# =====================================================================
set -uo pipefail

BEELINE="/opt/hive/bin/beeline -u jdbc:hive2://localhost:10000 -n root --outputformat=table --showHeader=true"
ORDEN=(01_ddl 02_carga P01_verificacion_carga P02_calidad P03_region_anual P04_rfm
       P05_ranking_productos P06_descuentos P07_tendencia_mensual P08_pareto 09_optimizacion)

if [ $# -gt 0 ]; then ORDEN=("$@"); fi

docker exec hs2 mkdir -p /tmp/scripts
docker cp scripts/. hs2:/tmp/scripts/
mkdir -p resultados

for s in "${ORDEN[@]}"; do
  echo "==> Ejecutando $s.hql"
  docker exec hs2 bash -c "$BEELINE -f /tmp/scripts/$s.hql" \
    > "resultados/$s.txt" 2> "resultados/$s.log"
  grep -E "rows selected|No rows|Error" "resultados/$s.log" | tail -n 5
done
echo "Listo. Revisa la carpeta resultados/"

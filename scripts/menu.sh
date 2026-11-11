#!/usr/bin/env bash
# =====================================================================
# menu.sh - Menú para ejecutar las consultas una por una (para capturas)
# Práctica individual Hive - Superstore | Joel Salazar
#
# Uso (desde la raíz del repo, en WSL):   bash scripts/menu.sh
#   1) Elige la pregunta (1-9)
#   2) Elige la consulta (1, 2, 3...) o "t" para el script completo
#   La pantalla se limpia y muestra solo esa consulta y su resultado.
# =====================================================================

DB="superstore_joelsalazar"
CONT="hs2"
BEELINE="/opt/hive/bin/beeline -u jdbc:hive2://localhost:10000 -n root --outputformat=table --showHeader=true"
DIR_SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ARCHIVOS=(
  "01_ddl.hql|DDL - crear base y tablas"
  "02_carga.hql|Carga de datos (INSERT + estadisticas)"
  "P01_verificacion_carga.hql|P1 - Verificacion de la carga"
  "P02_calidad.hql|P2 - Calidad de datos"
  "P03_region_anual.hql|P3 - Evolucion por region"
  "P04_rfm.hql|P4 - Segmentacion RFM"
  "P05_ranking_productos.hql|P5 - Ranking de productos"
  "P06_descuentos.hql|P6 - Impacto de descuentos"
  "P07_tendencia_mensual.hql|P7 - Tendencias mensuales"
  "P08_pareto.hql|P8 - Pareto 80/20"
  "09_optimizacion.hql|Optimizacion"
)
# Tecla del menú principal -> índice en ARCHIVOS
declare -A TECLA=( [d]=0 [c]=1 [1]=2 [2]=3 [3]=4 [4]=5 [5]=6 [6]=7 [7]=8 [8]=9 [9]=10 )

# Separa un .hql en sentencias. Cada sentencia toma como título el último
# comentario "-- X.Y ..." que tenga encima (o su primera línea de SQL).
# Las sentencias SET se guardan aparte y se anteponen a cada ejecución.
partir() {
  local f="$1"
  rm -f "$TMP"/stmt_* "$TMP"/titulos "$TMP"/sets
  touch "$TMP"/sets
  sed 's/\r$//' "$f" | awk -v out="$TMP" '
    function emitir(   up, f, t, sql1) {
      gsub(/^[ \n]+|[ \n]+$/, "", buf)
      if (buf == "") return
      up = toupper(buf)
      if (up ~ /^USE /) { buf=""; return }
      if (up ~ /^SET / && buf ~ /=/) { print buf >> (out "/sets"); buf=""; return }
      if (up ~ /^DROP /) { previo = previo buf "\n"; buf=""; return }   # se une a la siguiente
      n++
      f = out "/stmt_" n
      print previo buf > f; close(f)
      sql1 = buf; gsub(/[ \n]+/, " ", sql1)
      if (titulo != "")      t = titulo
      else if (grupo != "")  t = grupo " -> " substr(sql1, 1, 40)
      else                   t = substr(sql1, 1, 70)
      print t >> (out "/titulos")
      buf=""; previo=""; titulo=""
    }
    /^[ \t]*--/ {
      c = $0; sub(/^[ \t]*--[ \t]*/, "", c)
      if (c ~ /^([0-9]+\.[0-9]+[a-z]?|[a-c]\.[0-9]+|O\.[0-9]+[a-z]?|\([a-c]\)|[a-d]\) |Capa|Vista|Referencias|Estad)/) {
        titulo = c; grupo = substr(c, 1, 45)
      }
      next
    }
    {
      buf = buf $0 "\n"
      if ($0 ~ /;[ \t]*$/) emitir()
    }
    END { emitir() }
  '
}

ejecutar() {   # $1 = archivo .sql local a ejecutar
  docker cp "$1" "$CONT:/tmp/consulta_menu.sql" > /dev/null
  docker exec -it "$CONT" bash -c "$BEELINE -f /tmp/consulta_menu.sql"
}

armar_sql() {  # $1 = número de sentencia (o "t" = todas) -> $TMP/ejecutar.sql
  {
    echo "USE $DB;"
    cat "$TMP"/sets
    if [ "$1" = "t" ]; then
      for s in $(ls "$TMP"/stmt_* | sort -t_ -k2 -n); do cat "$s"; done
    else
      cat "$TMP/stmt_$1"
    fi
  } > "$TMP/ejecutar.sql"
}

submenu() {    # $1 = índice en ARCHIVOS
  local archivo="${ARCHIVOS[$1]%%|*}" nombre="${ARCHIVOS[$1]##*|}"
  if [ ! -f "$DIR_SCRIPTS/$archivo" ]; then echo "No existe $archivo"; sleep 2; return; fi
  partir "$DIR_SCRIPTS/$archivo"
  local total; total=$(wc -l < "$TMP/titulos")
  while true; do
    clear
    echo "=============================================================="
    echo " $nombre   ($archivo)"
    echo "=============================================================="
    local i=1
    while IFS= read -r t; do printf "  %2d) %s\n" "$i" "$t"; i=$((i+1)); done < "$TMP/titulos"
    echo "   t) Ejecutar el script completo"
    echo "   v) Volver"
    echo "--------------------------------------------------------------"
    read -rp " Opcion: " op
    case "$op" in
      v|V) return ;;
      t|T) armar_sql t ;;
      *) if [[ "$op" =~ ^[0-9]+$ ]] && [ "$op" -ge 1 ] && [ "$op" -le "$total" ]; then
           armar_sql "$op"
         else echo " Opcion no valida"; sleep 1; continue; fi ;;
    esac
    clear
    if [ "$op" = "t" ] || [ "$op" = "T" ]; then
      echo "### $nombre - script completo"
    else
      echo "### $nombre - $(sed -n "${op}p" "$TMP/titulos")"
    fi
    echo
    ejecutar "$TMP/ejecutar.sql"
    echo
    read -rp " [Enter] para volver al menu de $nombre... " _
  done
}

while true; do
  clear
  echo "=============================================================="
  echo "  PRACTICA HIVE - SUPERSTORE  |  Joel Salazar"
  echo "=============================================================="
  echo "   d) DDL - crear base y tablas"
  echo "   c) Carga de datos"
  echo "   1) P1 - Verificacion de la carga"
  echo "   2) P2 - Calidad de datos"
  echo "   3) P3 - Evolucion por region"
  echo "   4) P4 - Segmentacion RFM"
  echo "   5) P5 - Ranking de productos"
  echo "   6) P6 - Impacto de descuentos"
  echo "   7) P7 - Tendencias mensuales"
  echo "   8) P8 - Pareto 80/20"
  echo "   9) Optimizacion"
  echo "   0) Salir"
  echo "--------------------------------------------------------------"
  read -rp " Opcion: " op
  op="${op,,}"
  [ "$op" = "0" ] && { clear; exit 0; }
  if [ -n "${TECLA[$op]+x}" ]; then submenu "${TECLA[$op]}"; else echo " Opcion no valida"; sleep 1; fi
done

# Pregunta 1. Diseño e implementación del modelo de datos

## Enunciado
Construir el modelo de almacenamiento en Apache Hive para el dataset Superstore: identificar los campos, elaborar el diccionario de datos, crear una tabla analítica con tipos apropiados y documentar la carga.
**Entregables:** diccionario de datos, DDL, instrucciones de carga y evidencia de registros importados.

## Estrategia de solución
Se trabajó en dos capas:

1. **Staging (`superstore_raw`)**: tabla **externa** sobre el CSV en HDFS, con `OpenCSVSerde` y todas las columnas `STRING`. Se eligió esta SerDe porque hay nombres de producto con comas y comillas dentro (`"Hon Deluxe ... Chairs, Rounded Back"`) que un `FIELDS TERMINATED BY ','` simple partiría en dos columnas. Como es externa, borrar la tabla no borra el archivo.
2. **Analítica (`superstore`)**: tabla administrada en **ORC con compresión Snappy**, con tipos reales (`DATE`, `INT`, `DECIMAL`). La conversión se hace en un `INSERT OVERWRITE ... SELECT` que limpia espacios, convierte las fechas `M/d/yyyy`, repone el cero de los códigos postales y calcula la bandera `registro_valido`.

Antes de cargar, el CSV se pasó de Windows-1252 a UTF-8 y se le quitaron los `\r` (ver `scripts/00_preparar_datos.sh`).

El diccionario de datos completo está en [`diccionario_datos.md`](diccionario_datos.md).

## Consulta HiveQL desarrollada
- DDL: [`scripts/01_ddl.hql`](../scripts/01_ddl.hql)
- Carga (DML): [`scripts/02_carga.hql`](../scripts/02_carga.hql)
- Verificación: [`scripts/P01_verificacion_carga.hql`](../scripts/P01_verificacion_carga.hql)

Fragmento clave de la conversión de fechas (con control de fechas inexistentes):
```sql
CASE WHEN from_unixtime(ts_order, 'M/d/yyyy') = TRIM(order_date)
     THEN to_date(from_unixtime(ts_order)) END AS order_date
```
`unix_timestamp` en Hive es "tolerante": convierte `2/30/2016` en `3/1/2016` sin avisar. Por eso se vuelve a formatear la fecha y se compara con el texto original; si no coinciden, la fecha queda `NULL` y la fila se marca como no válida.

### Instrucciones de carga
```bash
# En WSL, desde la raíz del repositorio
bash scripts/00_preparar_datos.sh          # iconv + sed + hdfs dfs -put
bash scripts/run_all.sh 01_ddl 02_carga P01_verificacion_carga
```
O de forma manual dentro de `hs2`:
```bash
docker exec -it hs2 /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000 -n root
!run /tmp/scripts/01_ddl.hql
!run /tmp/scripts/02_carga.hql
```

## Evidencia de ejecución
| Archivo | Qué muestra |
|---|---|
| `evidencias/P01/p01_1_hdfs_put.png` | `hdfs dfs -ls` con el CSV en `/user/joelsalazar/superstore/raw` |
| `evidencias/P01/p01_2_ddl.png` | Ejecución de `01_ddl.hql` y `SHOW TABLES` |
| `evidencias/P01/p01_3_carga.png` | `INSERT OVERWRITE` terminado en Tez |
| `evidencias/P01/p01_4_describe.png` | `DESCRIBE FORMATTED superstore` (tipos, ORC, `numRows`) |
| `evidencias/P01/p01_5_conteos.png` | Conteo raw vs. tipada y muestra de registros |

![Conteos](../evidencias/P01/p01_5_conteos.png)

## Resultado obtenido
| tabla | registros |
|---|---|
| superstore_raw | 9994 |
| superstore | 9994 |

| fallo_row_id | fallo_order_date | fallo_ship_date | fallo_sales | fallo_quantity | fallo_discount | fallo_profit |
|---|---|---|---|---|---|---|
| 0 | 0 | 0 | 0 | 0 | 0 | 0 |

| primera_orden | ultima_orden | ventas_totales | ganancia_total |
|---|---|---|---|
| 2014-01-03 | 2017-12-30 | 2297200.86 | 286397.02 |

## Interpretación técnica
Las dos tablas tienen 9.994 filas, igual que el CSV sin encabezado: no se perdió ni se duplicó nada en la carga y el encabezado se omitió bien. Ningún valor que venía con dato quedó en `NULL` después del `CAST`, así que los tipos elegidos sirven para todo el archivo. Los totales de ventas (USD 2.297.200,86) y ganancia (USD 286.397,02) coinciden con la suma directa de las columnas del CSV, lo que confirma que `DECIMAL` no redondeó nada. El periodo cubierto va del 3 de enero de 2014 al 30 de diciembre de 2017, es decir, cuatro años completos.

## Conclusión
El modelo de dos capas (staging externo en texto + tabla analítica ORC tipada) cargó el 100 % de los registros sin errores de conversión y deja la tabla `superstore` lista para las consultas analíticas, con una bandera de calidad que permite filtrar filas problemáticas sin borrarlas.

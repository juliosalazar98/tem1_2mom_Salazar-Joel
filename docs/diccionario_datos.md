# Diccionario de datos – Superstore

**Fuente:** [Kaggle – Superstore Dataset (vivek468)](https://www.kaggle.com/datasets/vivek468/superstore-dataset-final)
**Archivo:** `Sample - Superstore.csv` · 9.994 filas + encabezado · 21 columnas · codificación Windows-1252 · separador coma · campos de texto entre comillas cuando contienen comas.
**Granularidad:** una fila = una línea de pedido (un producto dentro de una orden). Una orden puede tener varias filas.

## Revisión del archivo original

| Aspecto revisado | Hallazgo | Tratamiento |
|---|---|---|
| Codificación | Windows-1252; hay nombres de producto con espacio no separable (byte `0xA0`) | `iconv` a UTF-8 y `regexp_replace` del carácter U+00A0 por espacio normal |
| Fin de línea | CRLF (Windows) | Se quita el `\r` con `sed` para que no quede pegado a `Profit` |
| Comillas | 2.510 líneas tienen campos entre comillas (comas y `"` internas, ej. `39" x 49"`) | `OpenCSVSerde`, que respeta comillas y comillas dobles escapadas |
| Fechas | Texto en formato `M/d/yyyy` sin ceros (`11/8/2016`) | Conversión a `DATE` con `unix_timestamp(..., 'M/d/yyyy')` y control de ida y vuelta |
| Código postal | Numérico en el CSV; Excel elimina el cero inicial | Se guarda como `STRING` con `lpad(..., 5, '0')` |
| Encabezado | Primera línea con nombres de columna | `skip.header.line.count = 1` |

## Tabla `superstore_raw` (staging, externa)

Las 21 columnas como `STRING`, en el mismo orden del CSV. Ubicación HDFS: `/user/joelsalazar/superstore/raw`. Se usa solo como origen de la carga.

## Tabla `superstore` (analítica, ORC + Snappy)

| # | Campo Hive | Columna CSV | Tipo Hive | Descripción | Restricciones / reglas | Ejemplo |
|---|---|---|---|---|---|---|
| 1 | `row_id` | Row ID | `INT` | Identificador correlativo de la fila | Único, no nulo (PK lógica) | 1 |
| 2 | `order_id` | Order ID | `STRING` | Código de la orden: país-año-número | No nulo; el año del código debe coincidir con `order_date` | CA-2016-152156 |
| 3 | `order_date` | Order Date | `DATE` | Fecha en que se hizo el pedido | No nula; fecha real del calendario | 2016-11-08 |
| 4 | `ship_date` | Ship Date | `DATE` | Fecha de envío | No nula; `ship_date >= order_date` | 2016-11-11 |
| 5 | `ship_mode` | Ship Mode | `STRING` | Modalidad de envío | {Same Day, First Class, Second Class, Standard Class} | Second Class |
| 6 | `customer_id` | Customer ID | `STRING` | Código del cliente | No nulo; 1 nombre por código | CG-12520 |
| 7 | `customer_name` | Customer Name | `STRING` | Nombre del cliente | No nulo | Claire Gute |
| 8 | `segment` | Segment | `STRING` | Segmento del cliente | {Consumer, Corporate, Home Office} | Consumer |
| 9 | `country` | Country | `STRING` | País | Valor único: United States | United States |
| 10 | `city` | City | `STRING` | Ciudad | No nula | Henderson |
| 11 | `state` | State | `STRING` | Estado | No nulo | Kentucky |
| 12 | `postal_code` | Postal Code | `STRING` | Código postal | 5 dígitos; admite NULL si el origen viene vacío | 42420 |
| 13 | `region` | Region | `STRING` | Región comercial | {Central, East, South, West} | South |
| 14 | `product_id` | Product ID | `STRING` | Código del producto: CAT-SUB-número | No nulo; se usa como clave de producto | FUR-BO-10001798 |
| 15 | `category` | Category | `STRING` | Categoría | {Furniture, Office Supplies, Technology} | Furniture |
| 16 | `sub_category` | Sub-Category | `STRING` | Subcategoría (17 valores) | No nula | Bookcases |
| 17 | `product_name` | Product Name | `STRING` | Nombre del producto | No nulo; puede contener comas y comillas | Bush Somerset Collection Bookcase |
| 18 | `sales` | Sales | `DECIMAL(12,4)` | Importe de la venta en USD (ya con descuento) | `> 0` | 261.9600 |
| 19 | `quantity` | Quantity | `INT` | Unidades vendidas | `> 0` | 2 |
| 20 | `discount` | Discount | `DECIMAL(4,2)` | Descuento aplicado como fracción | `0 <= discount < 1` | 0.00 |
| 21 | `profit` | Profit | `DECIMAL(12,4)` | Ganancia de la línea en USD | Puede ser negativa (pérdida) | 41.9136 |
| 22 | `registro_valido` | — (derivado) | `BOOLEAN` | `TRUE` si cumple todas las reglas de calidad | Calculado en la carga | true |

**¿Por qué `DECIMAL` y no `DOUBLE` en los importes?** `DOUBLE` acumula error de redondeo al sumar miles de valores. Con `DECIMAL` los totales coinciden con el CSV hasta el centavo.

## Tablas derivadas creadas por las consultas

| Tabla / vista | Creada en | Contenido |
|---|---|---|
| `rfm_clientes` | P04 | Una fila por cliente con R, F, M, puntajes y segmento |
| `ranking_productos` | P05 | Una fila por producto con márgenes, rankings y acumulados |
| `v_descuentos` (vista) | P06 | `superstore` + rango de descuento |
| `tendencia_mensual` | P07 | Una fila por mes con variaciones y promedio móvil |
| `pareto_ventas`, `pareto_ganancias` | P08 | Productos ordenados con % individual, % acumulado y clase |
| `superstore_part` | Optimización | Copia de `superstore` particionada por `anio` |

# Pregunta 2. Auditoría de calidad e integridad de datos

## Enunciado
Determinar: total de registros, identificadores de fila duplicados, órdenes y clientes únicos, campos con NULL, fechas inválidas o inconsistentes, ventas ≤ 0, descuentos fuera del intervalo esperado y registros con envío anterior al pedido. Construir una consulta de resumen de calidad y proponer criterios de tratamiento.

## Estrategia de solución
- **Resumen en una sola fila (2.1):** un CTE agrega todos los indicadores con `SUM(CASE WHEN ...)` y `COUNT(DISTINCT ...)`. Los `row_id` duplicados se detectan con `COUNT(*) OVER (PARTITION BY row_id)`, sin necesidad de un `JOIN`.
- **NULL por campo (2.2):** se cuentan los nulos de las 21 columnas y se pasan de columnas a filas con `stack()`, para leerlos como lista.
- **Fecha inválida:** fecha que no se pudo convertir o que no existe en el calendario (control de ida y vuelta de la carga).
- **Fecha inconsistente:** el año dentro del `Order ID` (`CA-2016-...`) no coincide con el año de `order_date`.
- **Intervalo esperado de descuento:** `[0, 1)`; un descuento negativo o del 100 % o más no tiene sentido comercial.
- **Hallazgos extra (2.3):** líneas repetidas (misma orden + mismo producto), un `product_id` con varios nombres y códigos postales vacíos.

## Consulta HiveQL desarrollada
[`scripts/P02_calidad.hql`](../scripts/P02_calidad.hql)

```sql
WITH base AS (
  SELECT s.*, COUNT(*) OVER (PARTITION BY row_id) AS veces_row_id
  FROM superstore s
), met AS (
  SELECT COUNT(*) AS total_registros,
         COUNT(DISTINCT CASE WHEN veces_row_id > 1 THEN row_id END) AS row_id_repetidos,
         COUNT(DISTINCT order_id) AS ordenes_unicas,
         COUNT(DISTINCT customer_id) AS clientes_unicos,
         SUM(CASE WHEN order_date IS NULL OR ship_date IS NULL THEN 1 ELSE 0 END) AS fechas_invalidas,
         SUM(CASE WHEN CAST(substr(order_id,4,4) AS INT) <> year(order_date) THEN 1 ELSE 0 END) AS anio_orden_inconsistente,
         SUM(CASE WHEN sales <= 0 THEN 1 ELSE 0 END) AS ventas_cero_o_negativas,
         SUM(CASE WHEN discount < 0 OR discount >= 1 THEN 1 ELSE 0 END) AS descuento_fuera_rango,
         SUM(CASE WHEN ship_date < order_date THEN 1 ELSE 0 END) AS envio_antes_de_pedido
         -- ...
  FROM base)
SELECT ... FROM met m;
```

## Evidencia de ejecución
| Archivo | Qué muestra |
|---|---|
| `evidencias/P02/p02_1_resumen_calidad.png` | Resultado de la consulta 2.1 |
| `evidencias/P02/p02_2_nulos_por_campo.png` | Resultado de 2.2 (stack) |
| `evidencias/P02/p02_3_hallazgos.png` | Consultas 2.3 a–d |

![Resumen de calidad](../evidencias/P02/p02_1_resumen_calidad.png)

## Resultado obtenido

**2.1 Resumen de calidad**

| Indicador | Valor |
|---|---|
| Total de registros | 9.994 |
| `row_id` repetidos | 0 |
| Órdenes únicas | 5.009 |
| Clientes únicos | 793 |
| Productos únicos (`product_id`) | 1.862 |
| Fechas inválidas | 0 |
| Año de `Order ID` ≠ año de `order_date` | **7** |
| Ventas ≤ 0 | 0 |
| Descuento fuera de [0, 1) | 0 (mín. 0,00 · máx. 0,80) |
| Envío antes del pedido | 0 |
| Registros válidos | 9.994 |

**2.2 NULL por campo:** los 21 campos tienen **0** valores nulos.

**2.3 Hallazgos adicionales**

| Hallazgo | Cantidad | Detalle |
|---|---|---|
| Año del `Order ID` distinto al de la fecha | 7 filas | Pedidos del 31/12/2016 con código `-2017-` (filas 1153, 1154, 2822, 4613, 4614, 5739, 6342) |
| Código postal vacío | 0 | Burlington (VT) trae `05408`: el `lpad` repuso el cero inicial |
| Misma orden + mismo producto en 2 filas | 8 pares (16 filas) | p. ej. `CA-2016-129714` / `OFF-PA-10001970` (filas 351 y 353) |
| `product_id` con más de un nombre | 32 códigos | p. ej. `FUR-BO-10002213` = "Sauder Forest Hills Library…" y "DMI Eclipse Executive Suite Bookcases" |
| Registros con pérdida (`profit < 0`) | 1.871 | No es error: son ventas reales con pérdida |
| Registros con ganancia 0 | 65 | — |

## Criterios de tratamiento propuestos
| Problema | Criterio | Justificación |
|---|---|---|
| Fecha inválida, venta ≤ 0, cantidad ≤ 0, descuento fuera de [0,1), envío antes del pedido | Marcar `registro_valido = FALSE` y **excluir** de los análisis (no se borran) | Distorsionan sumas y márgenes; al conservarlas se pueden revisar con la fuente |
| `row_id` duplicado | Conservar la primera aparición (`ROW_NUMBER() OVER (PARTITION BY row_id ORDER BY ...) = 1`) | El `row_id` debe ser único |
| Año del `Order ID` ≠ año de la fecha | **Conservar** y usar `order_date` como fecha oficial; se reporta como inconsistencia de codificación | Son pedidos del último día del año que recibieron el código del año siguiente; la fecha es válida y el envío es posterior al pedido |
| `postal_code` vacío (si apareciera) | Mantener `NULL`; no se usa en los análisis | No afecta ventas ni ganancias |
| Misma orden + producto repetido | **Conservar**: las dos filas tienen cantidades/importes propios (dos líneas del mismo pedido) | Eliminarlas bajaría las ventas reales |
| `product_id` con varios nombres | Usar `product_id` como clave del producto y `MAX(product_name)` como etiqueta | El código es el identificador; el nombre es solo descriptivo |
| Ganancia negativa | Conservar | Es información de negocio, base de la P6 |

## Interpretación técnica
El dataset está muy limpio en lo que piden las reglas: no hay valores nulos, ni fechas imposibles, ni envíos antes del pedido, ni ventas en cero, ni descuentos absurdos, y el `row_id` es único. Eso explica que las 9.994 filas queden como válidas. La única inconsistencia de fechas son 7 filas del 31/12/2016 cuyo `Order ID` dice 2017: la fecha es correcta y el código se generó con el año siguiente, por eso se conservan usando `order_date`. Los otros problemas están en la **integridad descriptiva**: 32 códigos de producto apuntan a dos productos distintos (una silla y un reloj de pared con el mismo código, por ejemplo), lo que obliga a decidir si agrupar por código o por nombre. Hay 5.009 órdenes para 9.994 filas, unas 2 líneas por orden, por eso contar filas no es lo mismo que contar pedidos.

## Conclusión
La consulta de resumen permite auditar el dataset en una sola ejecución. Los datos cumplen todas las reglas numéricas y de fechas y no tienen nulos; los únicos defectos son 7 `Order ID` con el año desfasado y 32 `product_id` ambiguos. Ninguno cambia los totales, pero sí obliga a usar `product_id` como clave en las preguntas de productos.

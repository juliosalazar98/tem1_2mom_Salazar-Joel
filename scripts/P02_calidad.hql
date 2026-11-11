-- =====================================================================
-- P02_calidad.hql  |  Pregunta 2 - Auditoría de calidad e integridad
-- Práctica individual Hive - Superstore | Joel Salazar
-- =====================================================================
USE superstore_joelsalazar;

-- 2.1 Resumen de calidad (una sola fila con todos los indicadores)
WITH base AS (
  SELECT s.*,
         COUNT(*) OVER (PARTITION BY row_id) AS veces_row_id
  FROM superstore s
),
met AS (
  SELECT
    COUNT(*)                                     AS total_registros,
    COUNT(DISTINCT CASE WHEN veces_row_id > 1 THEN row_id END)          AS row_id_repetidos,
    SUM(CASE WHEN veces_row_id > 1 THEN 1 ELSE 0 END)                   AS filas_row_id_duplicado,
    COUNT(DISTINCT order_id)                     AS ordenes_unicas,
    COUNT(DISTINCT customer_id)                  AS clientes_unicos,
    COUNT(DISTINCT product_id)                   AS productos_unicos,
    SUM(CASE WHEN order_date IS NULL OR ship_date IS NULL THEN 1 ELSE 0 END)        AS fechas_invalidas,
    -- Inconsistencia: el año del Order ID (CA-2016-...) no coincide con order_date
    SUM(CASE WHEN order_date IS NOT NULL
              AND CAST(substr(order_id, 4, 4) AS INT) <> year(order_date)
             THEN 1 ELSE 0 END)                                                      AS anio_orden_inconsistente,
    SUM(CASE WHEN sales <= 0 THEN 1 ELSE 0 END)                                      AS ventas_cero_o_negativas,
    SUM(CASE WHEN discount < 0 OR discount >= 1 THEN 1 ELSE 0 END)                   AS descuento_fuera_rango,
    SUM(CASE WHEN ship_date < order_date THEN 1 ELSE 0 END)                          AS envio_antes_de_pedido,
    SUM(CASE WHEN registro_valido THEN 1 ELSE 0 END)                                 AS registros_validos,
    MIN(discount) AS descuento_min,
    MAX(discount) AS descuento_max
  FROM base
)
SELECT m.total_registros,
       m.row_id_repetidos,
       m.filas_row_id_duplicado,
       m.ordenes_unicas,
       m.clientes_unicos,
       m.productos_unicos,
       m.fechas_invalidas,
       m.anio_orden_inconsistente,
       m.ventas_cero_o_negativas,
       m.descuento_fuera_rango,
       m.descuento_min,
       m.descuento_max,
       m.envio_antes_de_pedido,
       m.registros_validos,
       m.total_registros - m.registros_validos AS registros_excluidos
FROM met m;

-- 2.2 Valores NULL por campo (convertido a filas con stack)
SELECT stack(21,
  'row_id',        n_row_id,        'order_id',      n_order_id,
  'order_date',    n_order_date,    'ship_date',     n_ship_date,
  'ship_mode',     n_ship_mode,     'customer_id',   n_customer_id,
  'customer_name', n_customer_name, 'segment',       n_segment,
  'country',       n_country,       'city',          n_city,
  'state',         n_state,         'postal_code',   n_postal_code,
  'region',        n_region,        'product_id',    n_product_id,
  'category',      n_category,      'sub_category',  n_sub_category,
  'product_name',  n_product_name,  'sales',         n_sales,
  'quantity',      n_quantity,      'discount',      n_discount,
  'profit',        n_profit
) AS (campo, cantidad_null)
FROM (
  SELECT
    SUM(IF(row_id        IS NULL, 1, 0)) AS n_row_id,
    SUM(IF(order_id      IS NULL, 1, 0)) AS n_order_id,
    SUM(IF(order_date    IS NULL, 1, 0)) AS n_order_date,
    SUM(IF(ship_date     IS NULL, 1, 0)) AS n_ship_date,
    SUM(IF(ship_mode     IS NULL, 1, 0)) AS n_ship_mode,
    SUM(IF(customer_id   IS NULL, 1, 0)) AS n_customer_id,
    SUM(IF(customer_name IS NULL, 1, 0)) AS n_customer_name,
    SUM(IF(segment       IS NULL, 1, 0)) AS n_segment,
    SUM(IF(country       IS NULL, 1, 0)) AS n_country,
    SUM(IF(city          IS NULL, 1, 0)) AS n_city,
    SUM(IF(state         IS NULL, 1, 0)) AS n_state,
    SUM(IF(postal_code   IS NULL, 1, 0)) AS n_postal_code,
    SUM(IF(region        IS NULL, 1, 0)) AS n_region,
    SUM(IF(product_id    IS NULL, 1, 0)) AS n_product_id,
    SUM(IF(category      IS NULL, 1, 0)) AS n_category,
    SUM(IF(sub_category  IS NULL, 1, 0)) AS n_sub_category,
    SUM(IF(product_name  IS NULL, 1, 0)) AS n_product_name,
    SUM(IF(sales         IS NULL, 1, 0)) AS n_sales,
    SUM(IF(quantity      IS NULL, 1, 0)) AS n_quantity,
    SUM(IF(discount      IS NULL, 1, 0)) AS n_discount,
    SUM(IF(profit        IS NULL, 1, 0)) AS n_profit
  FROM superstore
) n;

-- 2.3 Hallazgos adicionales de integridad
-- a) Líneas repetidas: misma orden y mismo producto en más de una fila
SELECT order_id, product_id, COUNT(*) AS filas,
       collect_list(row_id) AS row_ids
FROM superstore
GROUP BY order_id, product_id
HAVING COUNT(*) > 1
ORDER BY order_id;

-- b) Un mismo Product ID con más de un nombre de producto
SELECT product_id, COUNT(DISTINCT product_name) AS nombres_distintos,
       collect_set(product_name) AS nombres
FROM superstore
GROUP BY product_id
HAVING COUNT(DISTINCT product_name) > 1
ORDER BY product_id
LIMIT 10;

SELECT COUNT(*) AS product_id_con_varios_nombres
FROM (SELECT product_id FROM superstore
      GROUP BY product_id
      HAVING COUNT(DISTINCT product_name) > 1) x;

-- c) Registros con código postal vacío
SELECT city, state, COUNT(*) AS registros
FROM superstore
WHERE postal_code IS NULL
GROUP BY city, state;

-- d) Ganancia negativa (no es error, pero se reporta para el análisis)
SELECT SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) AS registros_con_perdida,
       SUM(CASE WHEN profit = 0 THEN 1 ELSE 0 END) AS registros_ganancia_cero
FROM superstore;

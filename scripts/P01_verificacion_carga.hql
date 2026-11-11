-- =====================================================================
-- P01_verificacion_carga.hql  |  Pregunta 1 - Evidencia de registros importados
-- Práctica individual Hive - Superstore | Joel Salazar
-- =====================================================================
USE superstore_joelsalazar;

-- 1.1 Estructura de la tabla analítica (tipos, formato ORC, ubicación HDFS)
DESCRIBE FORMATTED superstore;

-- 1.2 Registros en staging vs. tabla analítica (deben coincidir: 9994)
SELECT 'superstore_raw' AS tabla, COUNT(*) AS registros FROM superstore_raw
UNION ALL
SELECT 'superstore'     AS tabla, COUNT(*) AS registros FROM superstore;

-- 1.3 Valores que no pudieron convertirse de tipo (raw con dato y tipada NULL)
SELECT
  SUM(CASE WHEN TRIM(r.row_id)     <> '' AND s.row_id     IS NULL THEN 1 ELSE 0 END) AS fallo_row_id,
  SUM(CASE WHEN TRIM(r.order_date) <> '' AND s.order_date IS NULL THEN 1 ELSE 0 END) AS fallo_order_date,
  SUM(CASE WHEN TRIM(r.ship_date)  <> '' AND s.ship_date  IS NULL THEN 1 ELSE 0 END) AS fallo_ship_date,
  SUM(CASE WHEN TRIM(r.sales)      <> '' AND s.sales      IS NULL THEN 1 ELSE 0 END) AS fallo_sales,
  SUM(CASE WHEN TRIM(r.quantity)   <> '' AND s.quantity   IS NULL THEN 1 ELSE 0 END) AS fallo_quantity,
  SUM(CASE WHEN TRIM(r.discount)   <> '' AND s.discount   IS NULL THEN 1 ELSE 0 END) AS fallo_discount,
  SUM(CASE WHEN TRIM(r.profit)     <> '' AND s.profit     IS NULL THEN 1 ELSE 0 END) AS fallo_profit
FROM superstore_raw r
JOIN superstore s ON CAST(TRIM(r.row_id) AS INT) = s.row_id;

-- 1.4 Muestra de registros tipados
SELECT row_id, order_id, order_date, ship_date, customer_id, region,
       product_id, category, sales, quantity, discount, profit
FROM superstore
ORDER BY row_id
LIMIT 5;

-- 1.5 Rango de fechas y totales de control
SELECT MIN(order_date) AS primera_orden,
       MAX(order_date) AS ultima_orden,
       ROUND(SUM(sales), 2)  AS ventas_totales,
       ROUND(SUM(profit), 2) AS ganancia_total
FROM superstore;

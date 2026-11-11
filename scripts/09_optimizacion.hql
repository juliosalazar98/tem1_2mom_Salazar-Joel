-- =====================================================================
-- 09_optimizacion.hql  |  Análisis de optimización
-- Práctica individual Hive - Superstore | Joel Salazar
-- Compara: TEXTFILE (raw) vs ORC, tabla sin partición vs. particionada
-- por año, y el efecto de estadísticas + vectorización en los planes.
-- Anotar el tiempo que imprime beeline ("X rows selected (N seconds)").
-- =====================================================================
USE superstore_joelsalazar;

-- Configuración utilizada
-- O.0 Motor de ejecucion configurado
SET hive.execution.engine;
SET hive.vectorized.execution.enabled=true;
SET hive.vectorized.execution.reduce.enabled=true;
SET hive.cbo.enable=true;
SET hive.compute.query.using.stats=true;
SET hive.stats.fetch.column.stats=true;
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;

-- ---------------------------------------------------------------------
-- O.1 Tabla particionada por año del pedido (partición dinámica)
-- ---------------------------------------------------------------------
-- O.1 Crear tabla superstore_part particionada por anio (EJECUTAR PRIMERO)
DROP TABLE IF EXISTS superstore_part;

CREATE TABLE superstore_part (
  row_id INT, order_id STRING, order_date DATE, ship_date DATE, ship_mode STRING,
  customer_id STRING, customer_name STRING, segment STRING, country STRING,
  city STRING, state STRING, postal_code STRING, region STRING,
  product_id STRING, category STRING, sub_category STRING, product_name STRING,
  sales DECIMAL(12,4), quantity INT, discount DECIMAL(4,2), profit DECIMAL(12,4),
  registro_valido BOOLEAN
)
PARTITIONED BY (anio INT)
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- O.1b Cargar particiones (particion dinamica)
INSERT OVERWRITE TABLE superstore_part PARTITION (anio)
SELECT s.*, year(s.order_date) AS anio
FROM superstore s;

-- O.1c Ver particiones creadas
SHOW PARTITIONS superstore_part;
-- O.1d Estadisticas por particion
ANALYZE TABLE superstore_part PARTITION (anio) COMPUTE STATISTICS;

-- ---------------------------------------------------------------------
-- O.2 Misma consulta sobre 3 diseños (comparar tiempo y plan)
-- ---------------------------------------------------------------------
-- (a) Staging TEXTFILE + CSV: Hive debe convertir tipos en cada lectura
-- O.2a EXPLAIN - staging TEXTFILE (CSV)
EXPLAIN
SELECT region, SUM(CAST(sales AS DECIMAL(12,4))) AS ventas
FROM superstore_raw
WHERE order_date LIKE '%/2017'
GROUP BY region;

-- O.2a Consulta - staging TEXTFILE (anotar tiempo)
SELECT region, ROUND(SUM(CAST(sales AS DECIMAL(12,4))), 2) AS ventas
FROM superstore_raw
WHERE order_date LIKE '%/2017'
GROUP BY region;

-- (b) ORC sin partición: lee los 4 años y filtra
-- O.2b EXPLAIN - ORC sin particion
EXPLAIN
SELECT region, SUM(sales) AS ventas
FROM superstore
WHERE year(order_date) = 2017
GROUP BY region;

-- O.2b Consulta - ORC sin particion (anotar tiempo)
SELECT region, ROUND(SUM(sales), 2) AS ventas
FROM superstore
WHERE year(order_date) = 2017
GROUP BY region;

-- (c) ORC particionado: poda de particiones, solo lee anio=2017
-- O.2c EXPLAIN DEPENDENCY - particiones leidas
EXPLAIN DEPENDENCY
SELECT region, SUM(sales) AS ventas
FROM superstore_part
WHERE anio = 2017
GROUP BY region;

-- O.2c EXPLAIN - ORC particionado
EXPLAIN
SELECT region, SUM(sales) AS ventas
FROM superstore_part
WHERE anio = 2017
GROUP BY region;

-- O.2c Consulta - ORC particionado (anotar tiempo)
SELECT region, ROUND(SUM(sales), 2) AS ventas
FROM superstore_part
WHERE anio = 2017
GROUP BY region;

-- ---------------------------------------------------------------------
-- O.3 Consultas resueltas solo con estadísticas (sin lanzar trabajo Tez)
-- ---------------------------------------------------------------------
-- O.3a COUNT(*) desde estadisticas - superstore
SELECT COUNT(*) FROM superstore;
-- O.3b COUNT(*) desde estadisticas - superstore_part
SELECT COUNT(*) FROM superstore_part;
-- O.3c Detalle de la particion 2017
DESCRIBE FORMATTED superstore_part PARTITION (anio = 2017);

-- =====================================================================
-- P08_pareto.hql  |  Pregunta 8 - Análisis Pareto 80/20
-- Práctica individual Hive - Superstore | Joel Salazar
-- Un producto pertenece al grupo "A" si la acumulación ANTES de él
-- todavía no llegaba al 80% (así se incluye el producto que cruza el 80%).
-- =====================================================================
USE superstore_joelsalazar;

-- ---------------------------------------------------------------------
-- (a) Pareto de VENTAS
-- ---------------------------------------------------------------------
-- a.0 Crear tabla pareto_ventas (EJECUTAR PRIMERO)
DROP TABLE IF EXISTS pareto_ventas;

CREATE TABLE pareto_ventas STORED AS ORC AS
WITH prod AS (
  SELECT product_id,
         MAX(product_name) AS product_name,
         MAX(category)     AS category,
         SUM(sales)        AS ventas
  FROM superstore
  WHERE registro_valido
  GROUP BY product_id
),
acum AS (
  SELECT p.*,
         ROW_NUMBER() OVER (ORDER BY ventas DESC, product_id)          AS posicion,
         COUNT(*)     OVER ()                                          AS total_productos,
         ventas / SUM(ventas) OVER () * 100                            AS pct_individual,
         SUM(ventas) OVER (ORDER BY ventas DESC, product_id
                           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
           / SUM(ventas) OVER () * 100                                 AS pct_acumulado
  FROM prod p
)
SELECT posicion, product_id, product_name, category,
       ROUND(ventas, 2)          AS ventas,
       ROUND(pct_individual, 4)  AS pct_individual,
       ROUND(pct_acumulado, 4)   AS pct_acumulado,
       ROUND(posicion / total_productos * 100, 2) AS pct_productos_acum,
       CASE WHEN pct_acumulado - pct_individual < 80 THEN 'A' ELSE 'B' END AS clase_pareto
FROM acum;

-- a.1 Productos que más contribuyen (primeros 10)
SELECT * FROM pareto_ventas ORDER BY posicion LIMIT 10;

-- a.2 Producto donde se cruza el 80%
SELECT * FROM pareto_ventas
WHERE clase_pareto = 'A'
ORDER BY posicion DESC
LIMIT 1;

-- a.3 Resumen 80/20 de ventas
SELECT clase_pareto,
       COUNT(*)                                          AS productos,
       ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2)  AS pct_productos,
       ROUND(SUM(ventas), 2)                             AS ventas,
       ROUND(SUM(pct_individual), 2)                     AS pct_ventas
FROM pareto_ventas
GROUP BY clase_pareto
ORDER BY clase_pareto;

-- ---------------------------------------------------------------------
-- (b) Pareto de GANANCIAS
-- Base = ganancia neta total. Como hay productos con pérdida, el
-- acumulado supera el 100% y luego baja hasta cerrar en 100%.
-- ---------------------------------------------------------------------
-- b.0 Crear tabla pareto_ganancias (EJECUTAR ANTES DE b.x y c.x)
DROP TABLE IF EXISTS pareto_ganancias;

CREATE TABLE pareto_ganancias STORED AS ORC AS
WITH prod AS (
  SELECT product_id,
         MAX(product_name) AS product_name,
         MAX(category)     AS category,
         SUM(profit)       AS ganancia
  FROM superstore
  WHERE registro_valido
  GROUP BY product_id
),
acum AS (
  SELECT p.*,
         ROW_NUMBER() OVER (ORDER BY ganancia DESC, product_id)        AS posicion,
         COUNT(*)     OVER ()                                          AS total_productos,
         ganancia / SUM(ganancia) OVER () * 100                        AS pct_individual,
         SUM(ganancia) OVER (ORDER BY ganancia DESC, product_id
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
           / SUM(ganancia) OVER () * 100                               AS pct_acumulado
  FROM prod p
)
SELECT posicion, product_id, product_name, category,
       ROUND(ganancia, 2)        AS ganancia,
       ROUND(pct_individual, 4)  AS pct_individual,
       ROUND(pct_acumulado, 4)   AS pct_acumulado,
       ROUND(posicion / total_productos * 100, 2) AS pct_productos_acum,
       CASE WHEN pct_acumulado - pct_individual < 80 THEN 'A'
            WHEN ganancia > 0 THEN 'B'
            ELSE 'C (sin ganancia)' END AS clase_pareto
FROM acum;

-- b.1 Productos que más contribuyen (primeros 10)
SELECT * FROM pareto_ganancias ORDER BY posicion LIMIT 10;

-- b.2 Producto donde se cruza el 80%
SELECT * FROM pareto_ganancias
WHERE clase_pareto = 'A'
ORDER BY posicion DESC
LIMIT 1;

-- b.3 Resumen 80/20 de ganancias
SELECT clase_pareto,
       COUNT(*)                                          AS productos,
       ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2)  AS pct_productos,
       ROUND(SUM(ganancia), 2)                           AS ganancia,
       ROUND(SUM(pct_individual), 2)                     AS pct_ganancia_neta
FROM pareto_ganancias
GROUP BY clase_pareto
ORDER BY clase_pareto;

-- b.4 Punto máximo del acumulado (cuánto se "pierde" después)
SELECT posicion, product_id, ROUND(pct_acumulado, 2) AS pct_acumulado_max
FROM pareto_ganancias
ORDER BY pct_acumulado DESC
LIMIT 1;

-- ---------------------------------------------------------------------
-- (c) Comparación de ambos análisis
-- ---------------------------------------------------------------------
-- c.1 Cruce de clases
SELECT v.clase_pareto AS clase_ventas,
       g.clase_pareto AS clase_ganancias,
       COUNT(*)       AS productos,
       ROUND(SUM(v.ventas), 2)   AS ventas,
       ROUND(SUM(g.ganancia), 2) AS ganancia
FROM pareto_ventas v
JOIN pareto_ganancias g ON v.product_id = g.product_id
GROUP BY v.clase_pareto, g.clase_pareto
ORDER BY clase_ventas, clase_ganancias;

-- c.2 Productos "A" en ventas que pierden dinero (los 10 de mayor venta)
SELECT v.posicion AS puesto_ventas, v.product_id, v.product_name, v.category,
       v.ventas, g.ganancia, g.posicion AS puesto_ganancia
FROM pareto_ventas v
JOIN pareto_ganancias g ON v.product_id = g.product_id
WHERE v.clase_pareto = 'A' AND g.ganancia < 0
ORDER BY v.posicion
LIMIT 10;

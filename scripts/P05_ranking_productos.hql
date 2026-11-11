-- =====================================================================
-- P05_ranking_productos.hql  |  Pregunta 5 - Ranking de productos
-- Práctica individual Hive - Superstore | Joel Salazar
-- Técnicas: RANK(), DENSE_RANK(), SUM() OVER (... ROWS ...) acumulado
-- Clave de producto: product_id (32 IDs tienen más de un nombre, ver P2).
-- =====================================================================
USE superstore_joelsalazar;

-- 5.0 Crear tabla ranking_productos (EJECUTAR PRIMERO)
DROP TABLE IF EXISTS ranking_productos;

CREATE TABLE ranking_productos STORED AS ORC AS
WITH prod AS (
  SELECT category,
         product_id,
         MAX(product_name) AS product_name,
         SUM(sales)        AS ventas,
         SUM(quantity)     AS unidades,
         SUM(profit)       AS ganancia
  FROM superstore
  WHERE registro_valido
  GROUP BY category, product_id
)
SELECT category, product_id, product_name,
       ROUND(ventas, 2)                    AS ventas,
       unidades,
       ROUND(ganancia, 2)                  AS ganancia,
       ROUND(ganancia / ventas * 100, 2)   AS margen_pct,
       RANK()       OVER (PARTITION BY category ORDER BY ganancia DESC) AS rank_ganancia_cat,
       DENSE_RANK() OVER (PARTITION BY category ORDER BY ganancia DESC) AS dense_rank_ganancia_cat,
       ROUND(SUM(ganancia) OVER (PARTITION BY category ORDER BY ganancia DESC, product_id
                                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS ganancia_acum_cat,
       ROUND(SUM(ganancia) OVER (PARTITION BY category ORDER BY ganancia DESC, product_id
                                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
             / SUM(ganancia) OVER (PARTITION BY category) * 100, 2)            AS pct_acum_ganancia_cat,
       COUNT(*) OVER (PARTITION BY category)                                    AS productos_en_cat,
       RANK()       OVER (ORDER BY ventas DESC)   AS rank_ventas_global,
       DENSE_RANK() OVER (ORDER BY unidades DESC) AS dense_rank_unidades_global,
       RANK()       OVER (ORDER BY ganancia ASC)  AS rank_menor_ganancia,
       RANK()       OVER (ORDER BY ganancia / ventas ASC) AS rank_menor_margen
FROM prod;

-- 5.1 Top 5 productos con mayor ganancia acumulada por categoría
SELECT category, rank_ganancia_cat, dense_rank_ganancia_cat, product_id, product_name,
       ventas, ganancia, margen_pct, ganancia_acum_cat, pct_acum_ganancia_cat
FROM ranking_productos
WHERE rank_ganancia_cat <= 5
ORDER BY category, rank_ganancia_cat;

-- 5.2 Top 5 productos con mayor volumen de ventas (importe en USD)
SELECT rank_ventas_global, product_id, product_name, category,
       ventas, unidades, ganancia, margen_pct
FROM ranking_productos
WHERE rank_ventas_global <= 5
ORDER BY rank_ventas_global;

-- 5.2b Complemento: top 5 por unidades vendidas (DENSE_RANK por empates)
SELECT dense_rank_unidades_global, product_id, product_name, category, unidades, ventas
FROM ranking_productos
WHERE dense_rank_unidades_global <= 5
ORDER BY dense_rank_unidades_global, product_id;

-- 5.3 Los 5 productos con menor rentabilidad (mayor pérdida acumulada)
SELECT rank_menor_ganancia, product_id, product_name, category,
       ventas, ganancia, margen_pct
FROM ranking_productos
WHERE rank_menor_ganancia <= 5
ORDER BY rank_menor_ganancia;

-- 5.3b Complemento: los 5 con peor margen porcentual
SELECT rank_menor_margen, product_id, product_name, category, ventas, ganancia, margen_pct
FROM ranking_productos
WHERE rank_menor_margen <= 5
ORDER BY rank_menor_margen;

-- 5.4 Margen individual y posición de cada producto dentro de su categoría
--     (la tabla completa tiene un producto por fila; aquí se muestran 15)
SELECT category, rank_ganancia_cat, dense_rank_ganancia_cat, productos_en_cat,
       product_id, product_name, ventas, ganancia, margen_pct, pct_acum_ganancia_cat
FROM ranking_productos
ORDER BY category, rank_ganancia_cat
LIMIT 15;

-- 5.5 Resumen por categoría
SELECT category,
       COUNT(*)                                          AS productos,
       SUM(CASE WHEN ganancia < 0 THEN 1 ELSE 0 END)     AS productos_con_perdida,
       ROUND(SUM(ventas), 2)                             AS ventas,
       ROUND(SUM(ganancia), 2)                           AS ganancia,
       ROUND(SUM(ganancia) / SUM(ventas) * 100, 2)       AS margen_pct
FROM ranking_productos
GROUP BY category
ORDER BY ganancia DESC;

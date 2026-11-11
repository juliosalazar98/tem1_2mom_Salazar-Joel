-- =====================================================================
-- P06_descuentos.hql  |  Pregunta 6 - Impacto de los descuentos
-- Práctica individual Hive - Superstore | Joel Salazar
-- "Con pérdida" = profit < 0  |  "No rentable" = profit <= 0
-- =====================================================================
USE superstore_joelsalazar;

-- 6.0 Crear vista v_descuentos con el rango de descuento (EJECUTAR PRIMERO)
DROP VIEW IF EXISTS v_descuentos;

CREATE VIEW v_descuentos AS
SELECT s.*,
       CASE
         WHEN discount = 0     THEN '1. Sin descuento (0%)'
         WHEN discount <= 0.20 THEN '2. Bajo (>0% a 20%)'
         WHEN discount <= 0.50 THEN '3. Medio (>20% a 50%)'
         ELSE                       '4. Alto (>50%)'
       END AS rango_descuento
FROM superstore s
WHERE registro_valido;

-- 6.1 Indicadores por rango de descuento
SELECT rango_descuento,
       COUNT(*)                                                   AS registros,
       ROUND(SUM(sales), 2)                                       AS ventas,
       ROUND(SUM(profit), 2)                                      AS ganancia,
       ROUND(SUM(profit) / SUM(sales) * 100, 2)                   AS margen_pct,
       SUM(CASE WHEN profit < 0  THEN 1 ELSE 0 END)               AS registros_con_perdida,
       ROUND(SUM(CASE WHEN profit <= 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS pct_no_rentables,
       ROUND(AVG(discount) * 100, 2)                              AS descuento_prom_pct
FROM v_descuentos
GROUP BY rango_descuento
ORDER BY rango_descuento;

-- 6.2 Detalle por nivel exacto de descuento (para ver dónde cambia el signo)
SELECT CAST(discount * 100 AS INT)                                AS descuento_pct,
       COUNT(*)                                                   AS registros,
       ROUND(SUM(profit), 2)                                      AS ganancia,
       ROUND(SUM(profit) / SUM(sales) * 100, 2)                   AS margen_pct,
       ROUND(SUM(CASE WHEN profit <= 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS pct_no_rentables
FROM v_descuentos
GROUP BY CAST(discount * 100 AS INT)
ORDER BY descuento_pct;

-- 6.3 Categorías afectadas: matriz categoría x rango
SELECT category, rango_descuento,
       COUNT(*)                                                   AS registros,
       ROUND(SUM(profit), 2)                                      AS ganancia,
       ROUND(SUM(profit) / SUM(sales) * 100, 2)                   AS margen_pct,
       ROUND(SUM(CASE WHEN profit <= 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS pct_no_rentables
FROM v_descuentos
GROUP BY category, rango_descuento
ORDER BY category, rango_descuento;

-- 6.4 Subcategorías más afectadas por los descuentos (solo registros con descuento)
WITH sub AS (
  SELECT category, sub_category,
         COUNT(*)                                                 AS registros_con_desc,
         ROUND(AVG(discount) * 100, 2)                            AS descuento_prom_pct,
         SUM(sales)                                               AS ventas,
         SUM(profit)                                              AS ganancia,
         SUM(CASE WHEN profit < 0 THEN profit ELSE 0 END)         AS perdida_total,
         SUM(CASE WHEN profit <= 0 THEN 1 ELSE 0 END)             AS no_rentables
  FROM v_descuentos
  WHERE discount > 0
  GROUP BY category, sub_category
)
SELECT RANK() OVER (ORDER BY ganancia ASC)                        AS ranking_afectacion,
       category, sub_category, registros_con_desc, descuento_prom_pct,
       ROUND(ventas, 2)                                           AS ventas,
       ROUND(ganancia, 2)                                         AS ganancia,
       ROUND(perdida_total, 2)                                    AS perdida_total,
       ROUND(ganancia / ventas * 100, 2)                          AS margen_pct,
       ROUND(no_rentables / registros_con_desc * 100, 2)          AS pct_no_rentables
FROM sub
ORDER BY ranking_afectacion
LIMIT 10;

-- 6.5 Asociación descuento - rentabilidad (coeficiente de correlación de Pearson)
SELECT ROUND(corr(CAST(discount AS DOUBLE), CAST(profit AS DOUBLE)), 4)               AS corr_desc_ganancia,
       ROUND(corr(CAST(discount AS DOUBLE), CAST(profit / sales AS DOUBLE)), 4)       AS corr_desc_margen,
       ROUND(corr(CAST(discount AS DOUBLE),
                  CAST(CASE WHEN profit <= 0 THEN 1 ELSE 0 END AS DOUBLE)), 4)        AS corr_desc_no_rentable
FROM v_descuentos;

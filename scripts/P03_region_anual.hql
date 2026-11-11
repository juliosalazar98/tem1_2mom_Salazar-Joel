-- =====================================================================
-- P03_region_anual.hql  |  Pregunta 3 - Evolución comercial por región
-- Práctica individual Hive - Superstore | Joel Salazar
-- Técnicas: CTE, LAG(), RANK(), FIRST_VALUE()
-- =====================================================================
USE superstore_joelsalazar;

-- 3.1 Ventas, ganancia, margen y variación interanual por región y año
WITH base AS (
  SELECT region,
         year(order_date) AS anio,
         SUM(sales)       AS ventas,
         SUM(profit)      AS ganancia
  FROM superstore
  WHERE registro_valido
  GROUP BY region, year(order_date)
),
evo AS (
  SELECT region, anio, ventas, ganancia,
         LAG(ventas)   OVER (PARTITION BY region ORDER BY anio) AS ventas_anio_ant,
         LAG(ganancia) OVER (PARTITION BY region ORDER BY anio) AS ganancia_anio_ant
  FROM base
)
SELECT region,
       anio,
       ROUND(ventas, 2)                                         AS ventas,
       ROUND(ganancia, 2)                                       AS ganancia,
       ROUND(ganancia / ventas * 100, 2)                        AS margen_pct,
       ROUND((ventas - ventas_anio_ant) / ventas_anio_ant * 100, 2)              AS var_ventas_pct,
       ROUND((ganancia - ganancia_anio_ant) / ABS(ganancia_anio_ant) * 100, 2)   AS var_ganancia_pct,
       RANK() OVER (PARTITION BY anio ORDER BY ganancia DESC)  AS puesto_ganancia_en_anio
FROM evo
ORDER BY region, anio;

-- 3.2 Desempeño acumulado del periodo: mejor y peor región
--     Criterio principal: ganancia total. Se muestran también margen y
--     crecimiento de ventas entre el primer y el último año.
WITH base AS (
  SELECT region,
         year(order_date) AS anio,
         SUM(sales)       AS ventas,
         SUM(profit)      AS ganancia
  FROM superstore
  WHERE registro_valido
  GROUP BY region, year(order_date)
),
reg AS (
  SELECT region, anio, ventas, ganancia,
         FIRST_VALUE(ventas) OVER (PARTITION BY region ORDER BY anio
                                   ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS ventas_primer_anio,
         LAST_VALUE(ventas)  OVER (PARTITION BY region ORDER BY anio
                                   ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS ventas_ultimo_anio
  FROM base
),
tot AS (
  SELECT region,
         SUM(ventas)   AS ventas_total,
         SUM(ganancia) AS ganancia_total,
         MAX(ventas_primer_anio) AS ventas_primer_anio,
         MAX(ventas_ultimo_anio) AS ventas_ultimo_anio
  FROM reg
  GROUP BY region
),
rk AS (
  SELECT t.*,
         RANK() OVER (ORDER BY ganancia_total DESC) AS rk_desc,
         RANK() OVER (ORDER BY ganancia_total ASC)  AS rk_asc
  FROM tot t
)
SELECT region,
       ROUND(ventas_total, 2)                                    AS ventas_total,
       ROUND(ganancia_total, 2)                                  AS ganancia_total,
       ROUND(ganancia_total / ventas_total * 100, 2)             AS margen_pct,
       ROUND((ventas_ultimo_anio - ventas_primer_anio) / ventas_primer_anio * 100, 2) AS crecimiento_ventas_periodo_pct,
       rk_desc                                                   AS ranking,
       CASE WHEN rk_desc = 1 THEN 'MEJOR DESEMPENO'
            WHEN rk_asc  = 1 THEN 'PEOR DESEMPENO'
            ELSE '-' END                                         AS evaluacion
FROM rk
ORDER BY ranking;

-- 3.3 Apoyo a la interpretación: nivel de descuento por región
SELECT region,
       ROUND(AVG(discount) * 100, 2)                                         AS descuento_prom_pct,
       ROUND(SUM(CASE WHEN discount > 0.20 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS pct_registros_desc_mayor_20
FROM superstore
WHERE registro_valido
GROUP BY region
ORDER BY descuento_prom_pct DESC;

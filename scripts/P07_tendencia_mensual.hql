-- =====================================================================
-- P07_tendencia_mensual.hql  |  Pregunta 7 - Tendencias temporales
-- Práctica individual Hive - Superstore | Joel Salazar
-- Técnicas: LAG(), AVG() OVER (ROWS BETWEEN 2 PRECEDING ...), RANK()
-- =====================================================================
USE superstore_joelsalazar;

-- 7.0 Crear tabla tendencia_mensual (EJECUTAR PRIMERO)
DROP TABLE IF EXISTS tendencia_mensual;

CREATE TABLE tendencia_mensual STORED AS ORC AS
WITH m AS (
  SELECT year(order_date)  AS anio,
         month(order_date) AS mes,
         SUM(sales)        AS ventas,
         SUM(profit)       AS ganancia
  FROM superstore
  WHERE registro_valido
  GROUP BY year(order_date), month(order_date)
),
w AS (
  SELECT anio, mes, ventas, ganancia,
         ROW_NUMBER() OVER (ORDER BY anio, mes)   AS n_mes,
         LAG(ventas, 1)    OVER (ORDER BY anio, mes) AS ventas_mes_ant,
         LAG(ganancia, 1)  OVER (ORDER BY anio, mes) AS ganancia_mes_ant,
         -- mismo mes del año anterior: los 48 meses están completos,
         -- por eso retroceder 12 posiciones equivale a retroceder un año
         LAG(ventas, 12)   OVER (ORDER BY anio, mes) AS ventas_mismo_mes_ant,
         LAG(ganancia, 12) OVER (ORDER BY anio, mes) AS ganancia_mismo_mes_ant,
         AVG(ventas)   OVER (ORDER BY anio, mes ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS pm3_ventas,
         AVG(ganancia) OVER (ORDER BY anio, mes ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS pm3_ganancia
  FROM m
)
SELECT concat(CAST(anio AS STRING), '-', lpad(CAST(mes AS STRING), 2, '0')) AS periodo,
       anio, mes,
       ROUND(ventas, 2)                                                    AS ventas,
       ROUND(ganancia, 2)                                                  AS ganancia,
       ROUND((ventas - ventas_mes_ant) / ventas_mes_ant * 100, 2)          AS var_ventas_mom_pct,
       ROUND((ganancia - ganancia_mes_ant) / ABS(ganancia_mes_ant) * 100, 2) AS var_ganancia_mom_pct,
       ROUND(ventas_mismo_mes_ant, 2)                                      AS ventas_mismo_mes_anio_ant,
       ROUND((ventas - ventas_mismo_mes_ant) / ventas_mismo_mes_ant * 100, 2)  AS var_ventas_yoy_pct,
       ROUND((ganancia - ganancia_mismo_mes_ant) / ABS(ganancia_mismo_mes_ant) * 100, 2) AS var_ganancia_yoy_pct,
       -- el promedio móvil se informa desde el 3er mes (ventana completa)
       CASE WHEN n_mes >= 3 THEN ROUND(pm3_ventas, 2) END                 AS prom_movil_3m_ventas,
       CASE WHEN n_mes >= 3 THEN ROUND(pm3_ganancia, 2) END               AS prom_movil_3m_ganancia
FROM w;

-- 7.1 Serie mensual completa
SELECT * FROM tendencia_mensual ORDER BY anio, mes;

-- 7.2 Los 3 meses con mayor y menor volumen de ventas
SELECT tipo, puesto, periodo, ventas, ganancia
FROM (
  SELECT 'MAYOR' AS tipo,
         RANK() OVER (ORDER BY ventas DESC) AS puesto,
         periodo, ventas, ganancia
  FROM tendencia_mensual
  UNION ALL
  SELECT 'MENOR' AS tipo,
         RANK() OVER (ORDER BY ventas ASC) AS puesto,
         periodo, ventas, ganancia
  FROM tendencia_mensual
) x
WHERE puesto <= 3
ORDER BY tipo, puesto;

-- 7.3 Estacionalidad: promedio por mes calendario (todos los años)
SELECT mes,
       ROUND(AVG(ventas), 2)   AS ventas_prom,
       ROUND(AVG(ganancia), 2) AS ganancia_prom,
       RANK() OVER (ORDER BY AVG(ventas) DESC) AS puesto_ventas
FROM tendencia_mensual
GROUP BY mes
ORDER BY mes;

-- 7.4 Totales anuales para contexto
SELECT anio,
       ROUND(SUM(ventas), 2)   AS ventas,
       ROUND(SUM(ganancia), 2) AS ganancia,
       ROUND(SUM(ganancia) / SUM(ventas) * 100, 2) AS margen_pct
FROM tendencia_mensual
GROUP BY anio
ORDER BY anio;

-- 7.5 Apoyo a la interpretación: peso de las ventas con descuento > 20 %
--     en los dos meses de mayor venta
SELECT concat(CAST(year(order_date) AS STRING), '-', lpad(CAST(month(order_date) AS STRING), 2, '0')) AS periodo,
       ROUND(AVG(discount) * 100, 2) AS descuento_prom_pct,
       ROUND(SUM(CASE WHEN discount > 0.20 THEN sales ELSE 0 END) / SUM(sales) * 100, 2) AS pct_ventas_desc_mayor_20,
       ROUND(SUM(profit) / SUM(sales) * 100, 2) AS margen_pct
FROM superstore
WHERE registro_valido
  AND ( (year(order_date) = 2017 AND month(order_date) = 11)
     OR (year(order_date) = 2016 AND month(order_date) = 12) )
GROUP BY year(order_date), month(order_date)
ORDER BY periodo;

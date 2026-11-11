-- =====================================================================
-- P04_rfm.hql  |  Pregunta 4 - Segmentación de clientes RFM
-- Práctica individual Hive - Superstore | Joel Salazar
-- Técnicas: CTE, DATEDIFF, MAX() OVER (), CUME_DIST()
--
-- Puntuación 1-5 por quintiles con CUME_DIST(). A diferencia de NTILE,
-- CUME_DIST da el mismo puntaje a clientes con el mismo valor, así el
-- resultado no depende del orden en que Hive lea las filas.
--   R: menos días desde la última compra  -> puntaje más alto
--   F: más órdenes únicas                  -> puntaje más alto
--   M: más ventas acumuladas               -> puntaje más alto
-- =====================================================================
USE superstore_joelsalazar;

-- 4.0 Crear tabla rfm_clientes (EJECUTAR PRIMERO)
DROP TABLE IF EXISTS rfm_clientes;

CREATE TABLE rfm_clientes STORED AS ORC AS
WITH cli AS (
  SELECT customer_id,
         MAX(customer_name)        AS customer_name,
         MAX(segment)              AS segment,
         MAX(order_date)           AS ultima_compra,
         COUNT(DISTINCT order_id)  AS frequency,
         SUM(sales)                AS monetary
  FROM superstore
  WHERE registro_valido
  GROUP BY customer_id
),
rfm AS (
  SELECT c.*,
         MAX(ultima_compra) OVER ()                             AS fecha_referencia,
         DATEDIFF(MAX(ultima_compra) OVER (), ultima_compra)    AS recency
  FROM cli c
),
puntaje AS (
  SELECT r.*,
         6 - CAST(CEIL(CUME_DIST() OVER (ORDER BY recency)   * 5) AS INT) AS r_score,
         CAST(CEIL(CUME_DIST() OVER (ORDER BY frequency) * 5) AS INT)     AS f_score,
         CAST(CEIL(CUME_DIST() OVER (ORDER BY monetary)  * 5) AS INT)     AS m_score
  FROM rfm r
)
SELECT customer_id, customer_name, segment, ultima_compra, fecha_referencia,
       recency, frequency, ROUND(monetary, 2) AS monetary,
       r_score, f_score, m_score,
       concat(CAST(r_score AS STRING), CAST(f_score AS STRING), CAST(m_score AS STRING)) AS rfm_codigo,
       r_score + f_score + m_score AS rfm_total,
       CASE
         WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN '1. Alto valor'
         WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3   THEN '2. En riesgo de abandono'
         WHEN f_score >= 4 AND r_score >= 3                    THEN '3. Recurrentes'
         WHEN r_score >= 4 AND f_score <= 2                    THEN '4. Recientes poco frecuentes'
         WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2   THEN '5. Inactivos de bajo valor'
         ELSE '6. Regulares'
       END AS segmento_rfm
FROM puntaje;

-- 4.1 Rangos de cada métrica y cortes de puntaje (justificación de criterios)
SELECT metrica, puntaje, minimo, maximo, clientes
FROM (
  SELECT '1. recency (dias)' AS metrica, r_score AS puntaje,
         CAST(MIN(recency) AS BIGINT) AS minimo, CAST(MAX(recency) AS BIGINT) AS maximo,
         COUNT(*) AS clientes
  FROM rfm_clientes GROUP BY r_score
  UNION ALL
  SELECT '2. frequency (ordenes)', f_score,
         CAST(MIN(frequency) AS BIGINT), CAST(MAX(frequency) AS BIGINT), COUNT(*)
  FROM rfm_clientes GROUP BY f_score
  UNION ALL
  SELECT '3. monetary (USD)', m_score,
         CAST(MIN(monetary) AS BIGINT), CAST(MAX(monetary) AS BIGINT), COUNT(*)
  FROM rfm_clientes GROUP BY m_score
) x
ORDER BY metrica, puntaje;

-- Referencias para justificar los cortes
SELECT MAX(fecha_referencia)                  AS fecha_referencia,
       ROUND(AVG(recency), 1)                 AS recency_promedio,
       percentile(CAST(recency AS BIGINT), 0.5) AS recency_mediana,
       ROUND(AVG(frequency), 2)               AS frequency_promedio,
       ROUND(AVG(monetary), 2)                AS monetary_promedio
FROM rfm_clientes;

-- 4.2 Resumen por segmento
SELECT segmento_rfm,
       COUNT(*)                                                    AS clientes,
       ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2)            AS pct_clientes,
       ROUND(AVG(recency), 1)                                      AS recency_prom_dias,
       ROUND(AVG(frequency), 2)                                    AS frequency_prom,
       ROUND(AVG(monetary), 2)                                     AS monetary_prom,
       ROUND(SUM(monetary), 2)                                     AS ventas_segmento,
       ROUND(SUM(monetary) / SUM(SUM(monetary)) OVER () * 100, 2)  AS pct_ventas
FROM rfm_clientes
GROUP BY segmento_rfm
ORDER BY segmento_rfm;

-- 4.3 Top 10 clientes de alto valor
SELECT customer_id, customer_name, recency, frequency, monetary, rfm_codigo, rfm_total
FROM rfm_clientes
WHERE segmento_rfm = '1. Alto valor'
ORDER BY rfm_total DESC, monetary DESC
LIMIT 10;

-- 4.4 Top 10 clientes en riesgo de abandono (más valiosos primero)
SELECT customer_id, customer_name, ultima_compra, recency, frequency, monetary, rfm_codigo
FROM rfm_clientes
WHERE segmento_rfm = '2. En riesgo de abandono'
ORDER BY monetary DESC
LIMIT 10;

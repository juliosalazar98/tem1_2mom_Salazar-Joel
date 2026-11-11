-- =====================================================================
-- 02_carga.hql  |  Pregunta 1 - Carga y transformación (DML)
-- Práctica individual Hive - Superstore | Joel Salazar
-- Pasa los datos de superstore_raw (STRING) a superstore (tipada, ORC)
-- =====================================================================
USE superstore_joelsalazar;

INSERT OVERWRITE TABLE superstore
SELECT
  row_id, order_id, order_date, ship_date, ship_mode,
  customer_id, customer_name, segment, country, city, state, postal_code,
  region, product_id, category, sub_category, product_name,
  sales, quantity, discount, profit,
  -- Reglas de calidad (ver Pregunta 2)
  ( row_id     IS NOT NULL
    AND order_date IS NOT NULL
    AND ship_date  IS NOT NULL
    AND ship_date >= order_date
    AND sales    IS NOT NULL AND sales > 0
    AND quantity IS NOT NULL AND quantity > 0
    AND discount IS NOT NULL AND discount >= 0 AND discount < 1
    AND profit   IS NOT NULL ) AS registro_valido
FROM (
  SELECT
    CAST(NULLIF(TRIM(row_id), '') AS INT)                         AS row_id,
    NULLIF(TRIM(order_id), '')                                    AS order_id,
    -- Fecha M/d/yyyy -> DATE. Si la fecha no existe (p. ej. 2/30/2016),
    -- la comparación de ida y vuelta falla y queda NULL.
    CASE WHEN from_unixtime(ts_order, 'M/d/yyyy') = TRIM(order_date)
         THEN to_date(from_unixtime(ts_order)) END                AS order_date,
    CASE WHEN from_unixtime(ts_ship, 'M/d/yyyy') = TRIM(ship_date)
         THEN to_date(from_unixtime(ts_ship)) END                 AS ship_date,
    NULLIF(TRIM(ship_mode), '')                                   AS ship_mode,
    NULLIF(TRIM(customer_id), '')                                 AS customer_id,
    NULLIF(TRIM(customer_name), '')                               AS customer_name,
    NULLIF(TRIM(segment), '')                                     AS segment,
    NULLIF(TRIM(country), '')                                     AS country,
    NULLIF(TRIM(city), '')                                        AS city,
    NULLIF(TRIM(state), '')                                       AS state,
    -- Excel quita el cero inicial (05401 -> 5401); se repone a 5 dígitos
    CASE WHEN TRIM(postal_code) = '' THEN NULL
         ELSE lpad(TRIM(postal_code), 5, '0') END                 AS postal_code,
    NULLIF(TRIM(region), '')                                      AS region,
    NULLIF(TRIM(product_id), '')                                  AS product_id,
    NULLIF(TRIM(category), '')                                    AS category,
    NULLIF(TRIM(sub_category), '')                                AS sub_category,
    -- Algunos nombres traen espacios no separables (U+00A0)
    NULLIF(TRIM(regexp_replace(product_name, '\\x{A0}', ' ')), '') AS product_name,
    CAST(NULLIF(TRIM(sales), '')    AS DECIMAL(12,4))             AS sales,
    CAST(NULLIF(TRIM(quantity), '') AS INT)                       AS quantity,
    CAST(NULLIF(TRIM(discount), '') AS DECIMAL(4,2))              AS discount,
    CAST(NULLIF(TRIM(profit), '')   AS DECIMAL(12,4))             AS profit
  FROM (
    SELECT r.*,
           unix_timestamp(TRIM(order_date), 'M/d/yyyy') AS ts_order,
           unix_timestamp(TRIM(ship_date),  'M/d/yyyy') AS ts_ship
    FROM superstore_raw r
    -- Protección por si el encabezado no fue omitido por la SerDe
    WHERE TRIM(r.row_id) <> 'Row ID'
  ) b
) t;

-- Estadísticas para el optimizador (CBO)
ANALYZE TABLE superstore COMPUTE STATISTICS;
ANALYZE TABLE superstore COMPUTE STATISTICS FOR COLUMNS;

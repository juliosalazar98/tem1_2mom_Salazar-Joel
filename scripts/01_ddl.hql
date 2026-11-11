-- =====================================================================
-- 01_ddl.hql  |  Pregunta 1 - Modelo de datos (DDL)
-- Práctica individual Hive - Superstore | Joel Salazar
-- Ejecutar:  beeline -u jdbc:hive2://localhost:10000 -f /tmp/scripts/01_ddl.hql
-- =====================================================================

CREATE DATABASE IF NOT EXISTS superstore_joelsalazar
COMMENT 'Practica individual Hive - Superstore - Joel Salazar';

USE superstore_joelsalazar;

-- ---------------------------------------------------------------------
-- Capa 1: tabla externa de staging (todo STRING).
-- OpenCSVSerde respeta las comillas del CSV: hay nombres de producto
-- con comas dentro, por ejemplo "Hon Deluxe Fabric ... Chairs, Rounded Back".
-- Esta SerDe solo entrega STRING, por eso el tipado se hace en la capa 2.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS superstore_raw;

CREATE EXTERNAL TABLE superstore_raw (
  row_id         STRING,
  order_id       STRING,
  order_date     STRING,
  ship_date      STRING,
  ship_mode      STRING,
  customer_id    STRING,
  customer_name  STRING,
  segment        STRING,
  country        STRING,
  city           STRING,
  state          STRING,
  postal_code    STRING,
  region         STRING,
  product_id     STRING,
  category       STRING,
  sub_category   STRING,
  product_name   STRING,
  sales          STRING,
  quantity       STRING,
  discount       STRING,
  profit         STRING
)
COMMENT 'Staging: CSV original de Kaggle sin transformar'
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
  'separatorChar' = ',',
  'quoteChar'     = '"',
  'escapeChar'    = '\\'
)
STORED AS TEXTFILE
LOCATION '/user/joelsalazar/superstore/raw'
TBLPROPERTIES ('skip.header.line.count' = '1');

-- ---------------------------------------------------------------------
-- Capa 2: tabla analítica tipada en ORC.
-- registro_valido marca las filas que pasan las reglas de calidad
-- definidas en la Pregunta 2. Las consultas analíticas filtran por él.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS superstore;

CREATE TABLE superstore (
  row_id          INT            COMMENT 'Identificador de fila (PK lógica)',
  order_id        STRING         COMMENT 'Identificador de la orden: XX-AAAA-NNNNNN',
  order_date      DATE           COMMENT 'Fecha del pedido',
  ship_date       DATE           COMMENT 'Fecha de envío',
  ship_mode       STRING         COMMENT 'Modalidad de envío',
  customer_id     STRING         COMMENT 'Identificador del cliente',
  customer_name   STRING         COMMENT 'Nombre del cliente',
  segment         STRING         COMMENT 'Consumer / Corporate / Home Office',
  country         STRING         COMMENT 'País',
  city            STRING         COMMENT 'Ciudad',
  state           STRING         COMMENT 'Estado',
  postal_code     STRING         COMMENT 'Código postal de 5 dígitos (texto)',
  region          STRING         COMMENT 'Central / East / South / West',
  product_id      STRING         COMMENT 'Identificador del producto',
  category        STRING         COMMENT 'Categoría',
  sub_category    STRING         COMMENT 'Subcategoría',
  product_name    STRING         COMMENT 'Nombre del producto',
  sales           DECIMAL(12,4)  COMMENT 'Importe de venta (USD)',
  quantity        INT            COMMENT 'Unidades vendidas',
  discount        DECIMAL(4,2)   COMMENT 'Descuento aplicado (0 a 1)',
  profit          DECIMAL(12,4)  COMMENT 'Ganancia o pérdida (USD)',
  registro_valido BOOLEAN        COMMENT 'TRUE si cumple las reglas de calidad'
)
COMMENT 'Tabla analitica Superstore tipada'
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

SHOW TABLES;

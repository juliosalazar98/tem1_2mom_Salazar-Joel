# tem1_2mom_salazar-joel · Procesamiento y análisis del dataset Superstore con Apache Hive

**Práctica individual – Tecnologías Emergentes I · Universidad Privada del Valle (Cochabamba)**
**Estudiante:** Joel Julio Salazar Ferrufino

## Descripción
Proyecto de ingesta, modelado, auditoría de calidad y análisis del dataset **Superstore** (ventas minoristas de EE. UU., 2014–2017) con **Apache Hive 3.1** sobre un clúster Hadoop en Docker. Se resuelven 8 preguntas analíticas con HiveQL (CTE, funciones de ventana, rankings, RFM, Pareto) y se analiza la optimización de las consultas.

## Objetivos
- Modelar e implementar el almacenamiento del dataset en Hive con tipos adecuados.
- Auditar la calidad e integridad de los datos y definir criterios de tratamiento.
- Resolver consultas analíticas avanzadas: evolución regional, RFM, rankings de productos, impacto de descuentos, tendencias mensuales y Pareto.
- Aplicar y medir técnicas de optimización (ORC, estadísticas, particionamiento, vectorización).
- Interpretar los resultados para la toma de decisiones.

## Requisitos
| Componente | Versión / detalle |
|---|---|
| Sistema | Windows 10/11 + **WSL 2 (Ubuntu)** |
| Docker | Docker Desktop con integración WSL 2, mínimo 8 GB de RAM asignados |
| Clúster | [`timveil/docker-hadoop`](https://github.com/timveil/docker-hadoop), configuración `hadoop-hive-3.1.x-postgres` (Hadoop 3.2, Hive 3.1, motor Tez, metastore en PostgreSQL) |
| Utilidades en WSL | `git`, `iconv`, `sed`, `file` |
| Dataset | [Kaggle – Superstore Dataset](https://www.kaggle.com/datasets/vivek468/superstore-dataset-final) → `Sample - Superstore.csv` |

Contenedores usados: `namenode`, `datanode`, `resourcemanager`, `nodemanager`, `historyserver`, `hs2` (HiveServer2), `metastore`, `metastore-db`.

## Estructura del repositorio
```
tem1_2mom_salazar-joel/
├── README.md
├── dataset/                      # aquí va "Sample - Superstore.csv" (no se versiona)
├── scripts/
│   ├── 00_preparar_datos.sh      # iconv + sed + subida a HDFS
│   ├── run_all.sh                # ejecuta los .hql con beeline y guarda resultados
│   ├── 01_ddl.hql                # DDL: base de datos, staging y tabla analítica
│   ├── 02_carga.hql              # DML: carga tipada + estadísticas
│   ├── P01_verificacion_carga.hql
│   ├── P02_calidad.hql
│   ├── P03_region_anual.hql
│   ├── P04_rfm.hql
│   ├── P05_ranking_productos.hql
│   ├── P06_descuentos.hql
│   ├── P07_tendencia_mensual.hql
│   ├── P08_pareto.hql
│   └── 09_optimizacion.hql
├── docs/
│   ├── diccionario_datos.md
│   ├── P01_modelo_datos.md … P08_pareto.md   # una por pregunta
│   ├── optimizacion.md
│   └── conclusiones.md
├── resultados/                   # salidas de beeline (.txt) y tiempos (.log)
└── evidencias/                   # capturas por pregunta (P01 … P08, optimizacion)
```

## Procedimiento de ejecución

### 1. Levantar el clúster
```bash
git clone https://github.com/timveil/docker-hadoop.git
cd docker-hadoop/hadoop-hive-3.1.x-postgres
docker compose up -d
docker ps        # verificar que los 8 contenedores estén "Up"
```
Interfaces: NameNode http://localhost:9870 · YARN http://localhost:8088 · HiveServer2 http://localhost:10002

### 2. Preparar y subir el dataset
```bash
cd ~/tem1_2mom_salazar-joel
cp "/mnt/c/Users/<usuario>/Downloads/Sample - Superstore.csv" dataset/
bash scripts/00_preparar_datos.sh
```
El script convierte el archivo de Windows-1252 a UTF-8, quita los `\r`, lo sube a `hdfs:///user/joelsalazar/superstore/raw/` y copia los scripts al contenedor `hs2`.

### 3. Ejecutar los scripts
Todo de una vez (guarda las salidas en `resultados/`):
```bash
bash scripts/run_all.sh
```
O uno por uno, en orden:
```bash
bash scripts/run_all.sh 01_ddl 02_carga P01_verificacion_carga
bash scripts/run_all.sh P02_calidad
# ... P03 a P08
bash scripts/run_all.sh 09_optimizacion
```
De forma interactiva:
```bash
docker exec -it hs2 /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000 -n root
0: jdbc:hive2://localhost:10000> !run /tmp/scripts/P03_region_anual.hql
```

## Preguntas resueltas
| # | Pregunta | Script | Documentación |
|---|---|---|---|
| 1 | Diseño e implementación del modelo de datos | `01_ddl.hql`, `02_carga.hql`, `P01_verificacion_carga.hql` | [P01](docs/P01_modelo_datos.md) |
| 2 | Auditoría de calidad e integridad | `P02_calidad.hql` | [P02](docs/P02_calidad_datos.md) |
| 3 | Evolución comercial por región | `P03_region_anual.hql` | [P03](docs/P03_evolucion_region.md) |
| 4 | Segmentación RFM de clientes | `P04_rfm.hql` | [P04](docs/P04_rfm.md) |
| 5 | Ranking de productos por rentabilidad | `P05_ranking_productos.hql` | [P05](docs/P05_ranking_productos.md) |
| 6 | Impacto de los descuentos | `P06_descuentos.hql` | [P06](docs/P06_descuentos.md) |
| 7 | Tendencias temporales | `P07_tendencia_mensual.hql` | [P07](docs/P07_tendencias_temporales.md) |
| 8 | Análisis Pareto 80/20 | `P08_pareto.hql` | [P08](docs/P08_pareto.md) |
| — | Análisis de optimización | `09_optimizacion.hql` | [Optimización](docs/optimizacion.md) |
| — | Diccionario de datos | — | [Diccionario](docs/diccionario_datos.md) |
| — | Conclusiones generales | — | [Conclusiones](docs/conclusiones.md) |

Cada documento de pregunta sigue el formato pedido: enunciado, estrategia, consulta HiveQL, evidencia, resultado, interpretación y conclusión.

## Modelo de datos (resumen)
```
CSV (Windows-1252)
   │  iconv + sed
   ▼
HDFS /user/joelsalazar/superstore/raw/superstore_utf8.csv
   │
   ▼
superstore_raw   (EXTERNAL · TEXTFILE · OpenCSVSerde · 21 STRING)
   │  INSERT OVERWRITE + CAST + reglas de calidad
   ▼
superstore       (ORC + Snappy · tipos DATE/INT/DECIMAL · registro_valido)
   ├── rfm_clientes · ranking_productos · v_descuentos · tendencia_mensual
   ├── pareto_ventas · pareto_ganancias
   └── superstore_part (particionada por anio)
```

## Hallazgos principales
- Datos: 9.994 líneas válidas, 5.009 órdenes, 793 clientes, 1.862 productos; ventas USD 2.297.200,86 y ganancia USD 286.397,02.
- West es la región con mejor desempeño y Central la de peor margen (7,9 %), asociado a su descuento promedio del 24 %.
- Desde el 30 % de descuento casi todas las ventas pierden dinero; con más del 50 %, el 100 %.
- El 8,8 % de los productos genera el 80 % de la ganancia neta (en ventas, el 22 %).
- 133 clientes valiosos están en riesgo de abandono y representan el 25 % de las ventas históricas.

Detalle en [docs/conclusiones.md](docs/conclusiones.md).

# Pregunta 6. Análisis del impacto de los descuentos

## Enunciado
Analizar la relación entre descuentos y rentabilidad clasificando los registros en: sin descuento (0), bajo (> 0 y hasta 20 %), medio (> 20 % y hasta 50 %) y alto (> 50 %). Calcular ventas y ganancias por rango, margen, registros con pérdidas, porcentaje de registros no rentables, descuento promedio y categorías/subcategorías más afectadas. Determinar si los descuentos altos se asocian con más operaciones no rentables.

## Estrategia de solución
- Vista `v_descuentos` con un `CASE` que asigna el rango. Los límites siguen el enunciado (`<= 0.20`, `<= 0.50`).
- Definiciones: **con pérdida** = `profit < 0`; **no rentable** = `profit <= 0` (incluye las ventas con ganancia cero).
- 6.1: indicadores por rango. 6.2: detalle por cada nivel exacto de descuento, para ver en qué punto la ganancia cambia de signo. 6.3: matriz categoría × rango. 6.4: ranking de subcategorías por ganancia de sus ventas **con** descuento. 6.5: correlación de Pearson con `corr()` para medir la asociación.

## Consulta HiveQL desarrollada
[`scripts/P06_descuentos.hql`](../scripts/P06_descuentos.hql)

```sql
CREATE VIEW v_descuentos AS
SELECT s.*,
       CASE WHEN discount = 0     THEN '1. Sin descuento (0%)'
            WHEN discount <= 0.20 THEN '2. Bajo (>0% a 20%)'
            WHEN discount <= 0.50 THEN '3. Medio (>20% a 50%)'
            ELSE                       '4. Alto (>50%)' END AS rango_descuento
FROM superstore s WHERE registro_valido;

SELECT rango_descuento, COUNT(*) AS registros,
       ROUND(SUM(sales),2) AS ventas, ROUND(SUM(profit),2) AS ganancia,
       ROUND(SUM(profit)/SUM(sales)*100,2) AS margen_pct,
       SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) AS registros_con_perdida,
       ROUND(SUM(CASE WHEN profit <= 0 THEN 1 ELSE 0 END)/COUNT(*)*100,2) AS pct_no_rentables,
       ROUND(AVG(discount)*100,2) AS descuento_prom_pct
FROM v_descuentos GROUP BY rango_descuento ORDER BY rango_descuento;
```

## Evidencia de ejecución
| Archivo | Qué muestra |
|---|---|
| `evidencias/P06/p06_1_por_rango.png` | Consulta 6.1 |
| `evidencias/P06/p06_2_por_nivel.png` | Consulta 6.2 |
| `evidencias/P06/p06_3_categoria_rango.png` | Consulta 6.3 |
| `evidencias/P06/p06_4_subcategorias.png` | Consulta 6.4 |
| `evidencias/P06/p06_5_correlacion.png` | Consulta 6.5 |

![Indicadores por rango](../evidencias/P06/p06_1_por_rango.png)

## Resultado obtenido

**6.1 Indicadores por rango**

| rango | registros | ventas | ganancia | margen % | con pérdida | % no rentables | desc. prom. % |
|---|---|---|---|---|---|---|---|
| Sin descuento (0 %) | 4.798 | 1.087.908,47 | 320.987,60 | 29,51 | 0 | 0,63 | 0,00 |
| Bajo (> 0 % a 20 %) | 3.803 | 846.522,24 | 100.785,47 | 11,91 | 523 | 14,33 | 19,68 |
| Medio (> 20 % a 50 %) | 537 | 298.541,41 | -58.817,00 | -19,70 | 492 | 94,04 | 36,70 |
| Alto (> 50 %) | 856 | 64.228,74 | -76.559,05 | -119,20 | 856 | 100,00 | 71,89 |

**6.2 Por nivel exacto de descuento**

| desc. % | registros | ganancia | margen % | % no rentables |
|---|---|---|---|---|
| 0 | 4.798 | 320.987,60 | 29,51 | 0,63 |
| 10 | 94 | 9.029,18 | 16,61 | 4,26 |
| 15 | 52 | 1.418,99 | 5,15 | 32,69 |
| 20 | 3.657 | 90.337,31 | 11,82 | 14,33 |
| 30 | 227 | -10.369,28 | -10,05 | 97,36 |
| 32 | 27 | -2.391,14 | -16,50 | 100,00 |
| 40 | 206 | -23.057,05 | -19,81 | 87,38 |
| 45 | 11 | -2.493,11 | -45,45 | 100,00 |
| 50 | 66 | -20.506,43 | -34,80 | 100,00 |
| 60 | 138 | -5.944,66 | -89,46 | 100,00 |
| 70 | 418 | -40.075,36 | -98,66 | 100,00 |
| 80 | 300 | -30.539,04 | -180,03 | 100,00 |

**6.3 Categoría × rango** (margen % / % no rentables)

| categoría | sin desc. | bajo | medio | alto |
|---|---|---|---|---|
| Furniture | 22,71 / 0,00 | 5,09 / 27,86 | -23,99 / 99,49 | -108,08 / 100 |
| Office Supplies | 29,52 / 0,89 | 16,48 / 9,34 | *(sin registros)* | -119,27 / 100 |
| Technology | 33,96 / 0,24 | 14,72 / 15,54 | -12,60 / 79,73 | -125,50 / 100 |

**6.4 Subcategorías más afectadas** (solo ventas con descuento)

| # | categoría | subcategoría | registros | desc. prom. % | ganancia | pérdida total | margen % | % no rentables |
|---|---|---|---|---|---|---|---|---|
| 1 | Furniture | Tables | 247 | 33,74 | -31.001,78 | -32.412,15 | -22,90 | 83,00 |
| 2 | Technology | Machines | 86 | 40,93 | -23.753,07 | -30.118,67 | -20,09 | 51,16 |
| 3 | Furniture | Bookcases | 168 | 28,65 | -9.548,27 | -12.152,21 | -11,51 | 66,07 |
| 4 | Office Supplies | Binders | 1.186 | 47,81 | -9.092,69 | -38.510,50 | -7,48 | 51,69 |
| 5 | Office Supplies | Appliances | 195 | 39,79 | -5.045,73 | -8.629,64 | -17,12 | 34,36 |

**6.5 Correlación de Pearson**

| corr(descuento, ganancia) | corr(descuento, margen) | corr(descuento, no rentable) |
|---|---|---|
| -0,2195 | -0,8645 | 0,7428 |

## Interpretación técnica
La relación es clara y escalonada. Sin descuento, el margen es de 29,5 % y casi ninguna venta pierde dinero (0,6 %). Con descuento bajo el margen baja a 11,9 %, pero todavía es positivo. **A partir del 30 % de descuento el negocio pierde en casi todas las ventas**: en el rango medio el 94 % no es rentable y en el alto el 100 %, con un margen de -119 % (por cada dólar vendido se pierde más de un dólar).

El nivel exacto (6.2) muestra que el punto de quiebre está entre el 20 % (margen +11,8 %) y el 30 % (margen -10 %). Es decir, el 20 % es el descuento máximo que el negocio aguanta.

Las correlaciones confirman la asociación: el descuento casi no se relaciona con la ganancia en dólares (-0,22, porque los montos dependen mucho del precio del producto), pero sí, y con fuerza, con el **margen** (-0,86) y con que la venta sea **no rentable** (+0,74).

Por subcategoría, **Tables** es la más golpeada (pierde USD 31 mil con descuento y el 83 % de esas ventas no es rentable), seguida de **Machines** y **Bookcases**. **Binders** es un caso especial: tiene la mayor pérdida bruta (USD 38.510) porque recibe descuentos de hasta 80 % (promedio 47,8 %), aunque lo compensa en parte con ventas rentables al 20 %. Office Supplies no tiene registros en el rango medio: sus descuentos saltan del 20 % al 70–80 %.

## Conclusión
Sí: los descuentos altos están asociados a una proporción mucho mayor de operaciones no rentables. Pasar de 0 % a más del 50 % de descuento lleva las ventas no rentables del 0,6 % al 100 %. Los descuentos de 30 % o más destruyen valor en las tres categorías, así que conviene ponerles un tope del 20 %, sobre todo en Tables, Machines, Bookcases y Binders.

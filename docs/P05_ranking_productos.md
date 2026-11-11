# Pregunta 5. Ranking de productos según rentabilidad

## Enunciado
Identificar los productos de mayor y menor desempeño: los 5 con mayor ganancia acumulada por categoría, los 5 con mayor volumen de ventas, los 5 con menor rentabilidad, el margen individual de cada producto y su posición dentro de la categoría. Usar `RANK()`, `DENSE_RANK()` y agregaciones acumulativas.

## Estrategia de solución
- Clave de producto: **`product_id`** (por los 32 códigos con dos nombres, ver P2).
- Se crea la tabla `ranking_productos` (1.862 filas, una por producto) con todas las métricas en una sola pasada:
  - `RANK()` y `DENSE_RANK()` por ganancia **dentro de la categoría** (`PARTITION BY category`).
  - `SUM(ganancia) OVER (PARTITION BY category ORDER BY ganancia DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`: ganancia acumulada y su % sobre el total de la categoría.
  - Rankings globales por ventas (`RANK`), unidades (`DENSE_RANK`), menor ganancia y menor margen.
- Después cada inciso es un `SELECT ... WHERE rank <= 5` sobre esa tabla.
- "Volumen de ventas" se tomó como **importe en USD**; como complemento se muestra el top por **unidades**, donde hay empates y se nota la diferencia entre `RANK` y `DENSE_RANK`.
- "Menor rentabilidad" se tomó como **menor ganancia absoluta** (mayor pérdida en dólares); como complemento se muestra el peor **margen %**.

## Consulta HiveQL desarrollada
[`scripts/P05_ranking_productos.hql`](../scripts/P05_ranking_productos.hql)

```sql
CREATE TABLE ranking_productos STORED AS ORC AS
WITH prod AS (
  SELECT category, product_id, MAX(product_name) AS product_name,
         SUM(sales) AS ventas, SUM(quantity) AS unidades, SUM(profit) AS ganancia
  FROM superstore WHERE registro_valido GROUP BY category, product_id)
SELECT category, product_id, product_name, ROUND(ventas,2) AS ventas, unidades,
       ROUND(ganancia,2) AS ganancia, ROUND(ganancia/ventas*100,2) AS margen_pct,
       RANK()       OVER (PARTITION BY category ORDER BY ganancia DESC) AS rank_ganancia_cat,
       DENSE_RANK() OVER (PARTITION BY category ORDER BY ganancia DESC) AS dense_rank_ganancia_cat,
       ROUND(SUM(ganancia) OVER (PARTITION BY category ORDER BY ganancia DESC, product_id
             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS ganancia_acum_cat,
       ...
       RANK() OVER (ORDER BY ventas DESC)  AS rank_ventas_global,
       RANK() OVER (ORDER BY ganancia ASC) AS rank_menor_ganancia
FROM prod;
```

## Evidencia de ejecución
| Archivo | Qué muestra |
|---|---|
| `evidencias/P05/p05_1_top5_categoria.png` | Consulta 5.1 |
| `evidencias/P05/p05_2_top5_ventas.png` | Consultas 5.2 y 5.2b |
| `evidencias/P05/p05_3_menor_rentabilidad.png` | Consultas 5.3 y 5.3b |
| `evidencias/P05/p05_4_posicion_categoria.png` | Consultas 5.4 y 5.5 |

![Top 5 por categoría](../evidencias/P05/p05_1_top5_categoria.png)

## Resultado obtenido

**5.1 Top 5 por ganancia en cada categoría**

| categoría | # | producto | ventas | ganancia | margen % | % acum. cat. |
|---|---|---|---|---|---|---|
| Furniture | 1 | Hon Deluxe Fabric Upholstered Stacking Chairs, Rounded Back | 10.637,53 | 1.927,44 | 18,12 | 10,45 |
| Furniture | 2 | Global Deluxe High-Back Manager's Chair | 8.665,19 | 1.558,59 | 17,99 | 18,89 |
| Furniture | 3 | Hon Pagoda Stacking Chairs | 6.483,80 | 1.540,70 | 23,76 | 27,24 |
| Furniture | 4 | Hon 4070 Series Pagoda Armless Upholstered Stacking Chairs | 8.431,00 | 1.388,63 | 16,47 | 34,77 |
| Furniture | 5 | Office Star - Professional Matrix Back Chair … | 8.774,50 | 1.305,65 | 14,88 | 41,85 |
| Office Supplies | 1 | Fellowes PB500 Electric Punch Plastic Comb Binding Machine … | 27.453,38 | 7.753,04 | 28,24 | 6,33 |
| Office Supplies | 2 | Ibico EPK-21 Electric Binding System | 15.875,92 | 3.345,28 | 21,07 | 9,06 |
| Office Supplies | 3 | Honeywell Enviracaire Portable HEPA Air Cleaner … | 11.304,44 | 3.247,02 | 28,72 | 11,71 |
| Office Supplies | 4 | Fellowes PB300 Plastic Comb Binding Machine | 8.070,19 | 2.518,06 | 31,20 | 13,77 |
| Office Supplies | 5 | Ibico Ibimaster 300 Manual Binding System | 7.985,38 | 2.318,34 | 29,03 | 15,66 |
| Technology | 1 | Canon imageCLASS 2200 Advanced Copier | 61.599,82 | 25.199,93 | 40,91 | 17,32 |
| Technology | 2 | Hewlett Packard LaserJet 3310 Copier | 18.839,69 | 6.983,88 | 37,07 | 22,13 |
| Technology | 3 | Canon PC1060 Personal Laser Copier | 11.619,83 | 4.570,93 | 39,34 | 25,27 |
| Technology | 4 | Plantronics Savi W720 Multi-Device Wireless Headset System | 13.756,54 | 4.425,34 | 32,17 | 28,31 |
| Technology | 5 | HP Designjet T520 Inkjet Large Format Printer - 24" Color | 18.374,90 | 4.094,98 | 22,29 | 31,13 |

**5.2 Top 5 por importe vendido**

| # | producto | categoría | ventas | unidades | ganancia | margen % |
|---|---|---|---|---|---|---|
| 1 | Canon imageCLASS 2200 Advanced Copier | Technology | 61.599,82 | 20 | 25.199,93 | 40,91 |
| 2 | Fellowes PB500 Electric Punch … Binding Machine | Office Supplies | 27.453,38 | 31 | 7.753,04 | 28,24 |
| 3 | Cisco TelePresence System EX90 Videoconferencing Unit | Technology | 22.638,48 | 6 | -1.811,08 | -8,00 |
| 4 | HON 5400 Series Task Chairs for Big and Tall | Furniture | 21.870,58 | 39 | 0,00 | 0,00 |
| 5 | GBC DocuBind TL300 Electric Binding System | Office Supplies | 19.823,48 | 37 | 2.233,51 | 11,27 |

**5.2b Top por unidades** (`DENSE_RANK`): 1° Logitech P710e Mobile Speakerphone (75 u.), 2° Xerox 1908 (70), 3° GBC Premium Transparent Covers (67), **4° empate** Situations Contoured Folding Chairs y Ibico Recycled Linen-Style Covers (64), 5° Chromcraft Round Conference Tables (61). Con `RANK()` el siguiente puesto después del empate sería 6; con `DENSE_RANK()` es 5.

**5.3 Los 5 productos con menor rentabilidad (mayor pérdida)**

| # | producto | categoría | ventas | ganancia | margen % |
|---|---|---|---|---|---|
| 1 | Cubify CubeX 3D Printer Double Head Print | Technology | 11.099,96 | -8.879,97 | -80,00 |
| 2 | Lexmark MX611dhe Monochrome Laser Printer | Technology | 16.829,90 | -4.589,97 | -27,27 |
| 3 | Cubify CubeX 3D Printer Triple Head Print | Technology | 7.999,98 | -3.839,99 | -48,00 |
| 4 | Chromcraft Bull-Nose Wood Oval Conference Tables & Bases | Furniture | 9.917,64 | -2.876,12 | -29,00 |
| 5 | Bush Advantage Collection Racetrack Conference Table | Furniture | 9.544,73 | -1.934,40 | -20,27 |

**5.3b Peor margen %:** Eureka Disposable Bags (-275 %), Bush Westfield Bookcases (-210 %), Euro Pro Shark Stick Mini Vacuum (-190,7 %), Okidata B401 Printer (-140 %), Zebra GK420t Printer (-133,3 %). Son productos de venta pequeña (USD 1,62 a 703), por eso un margen tan negativo pesa poco en dólares.

**5.5 Resumen por categoría**

| categoría | productos | con pérdida | ventas | ganancia | margen % |
|---|---|---|---|---|---|
| Technology | 404 | 54 | 836.154,06 | 145.455,09 | 17,40 |
| Office Supplies | 1.083 | 124 | 719.047,05 | 122.490,88 | 17,04 |
| Furniture | 375 | 121 | 741.999,86 | 18.451,26 | 2,49 |

La consulta 5.4 lista el margen y la posición (`rank`, `dense_rank`, % acumulado) de cada producto dentro de su categoría; la tabla completa queda en `ranking_productos`.

## Interpretación técnica
En **Technology** la ganancia está muy concentrada: solo la copiadora Canon imageCLASS 2200 aporta el 17 % de la ganancia de toda la categoría, con un margen del 41 %. En **Office Supplies** pasa lo contrario: el top 5 apenas suma el 15,7 %, porque son 1.083 productos baratos con ganancia repartida.

**Furniture** es el caso crítico: vende casi lo mismo que Technology pero gana 8 veces menos (margen 2,5 %), y 121 de sus 375 productos (32 %) pierden dinero. Por eso sus 15 productos más rentables ya suman el 99 % de la ganancia neta de la categoría (consulta 5.4): lo que ganan las sillas se lo comen las mesas y libreros.

Vender mucho no asegura ganar: el Cisco TelePresence es el 3° producto más vendido y pierde USD 1.811, y la silla HON 5400 (4° en ventas) termina con ganancia exactamente cero. Las pérdidas más grandes se concentran en impresoras 3D y en mesas de conferencia.

## Conclusión
Los productos más rentables son copiadoras y máquinas encuadernadoras con márgenes de 28 % a 41 %. Las pérdidas se concentran en impresoras 3D (Cubify) y mesas de conferencia, y la categoría Furniture necesita revisar precios o descuentos porque casi un tercio de su catálogo no es rentable.

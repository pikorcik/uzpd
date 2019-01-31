-- SEMESTRÁLNÍ PROJEKT UZPD18_d
---------------------------------------------------------------------
-- ZIMNÍ SEMESTR 2018/2019
---------------------------------------------------------------------
-- TEREZA KULOVANÁ, MARKÉTA PECENOVÁ
---------------------------------------------------------------------
---------------------------------------------------------------------

-- VRSTVY
---------------------------------------------------------------------

-- 1) adresni_mista

CREATE TABLE adresni_mista AS
	SELECT kod, cislodomovni, cisloorientacni, geom
	FROM ruian_praha.adresnimista

ALTER TABLE adresni_mista ADD PRIMARY KEY(kod)

CREATE index adresy_index ON adresni_mista(geom)

SELECT kod FROM adresni_mista WHERE NOT st_isvalid(geom)

DELETE FROM adresni_mista WHERE geom IS NULL

---------------------------------------------------------------------

-- 2) obvody

CREATE TABLE obvody AS
    SELECT ogc_fid, nazev, geom
    FROM ruian_praha.spravniobvody

ALTER TABLE obvody ADD PRIMARY KEY(ogc_fid)

SELECT nazev FROM obvody WHERE NOT st_isvalid(geom)

---------------------------------------------------------------------

-- 3) detska_hriste

ogr2ogr -f "PostgreSQL" PG:"dbname=pgis_uzpd user=uzpd18_d password=d_uzpd18 host=geo102.fsv.cvut.cz" -t_srs 'EPSG:5514' "detska_hriste.json" -nln uzpd18_d.detska_hriste

ALTER TABLE detska_hriste
    DROP COLUMN url,
    DROP COLUMN name,
    DROP COLUMN perex,
    DROP COLUMN content,
    DROP COLUMN address,
    DROP COLUMN properties,
    DROP COLUMN image

ALTER TABLE detska_hriste
    RENAME wkb_geometry TO geom
	
SELECT id FROM detska_hriste WHERE NOT st_isvalid(geom)

---------------------------------------------------------------------

-- 4) zdrav_zarizeni

ogr2ogr -f "PostgreSQL" PG:"dbname=pgis_uzpd user=uzpd18_d password=d_uzpd18 host=geo102.fsv.cvut.cz" -t_srs 'EPSG:5514' "zdrav_zarizeni.json" -nln uzpd18_d.zdrav_zarizeni

ALTER TABLE zdrav_zarizeni
    DROP COLUMN id,
    DROP COLUMN address,
    DROP COLUMN email,
    DROP COLUMN web,
    DROP COLUMN telephone,
    DROP COLUMN opening_hours

ALTER TABLE zdrav_zarizeni
    RENAME wkb_geometry TO geom
	
SELECT ogc_fid FROM zdrav_zarizeni WHERE NOT st_isvalid(geom)

---------------------------------------------------------------------

-- 5) metro

ogr2ogr -f "PostgreSQL" PG:"dbname=pgis_uzpd user=uzpd18_d password=d_uzpd18 host=geo102.fsv.cvut.cz" -a_srs 'EPSG:5514' "metro.json" -nln uzpd18_d.metro

ALTER TABLE metro
    DROP COLUMN objectid,
    DROP COLUMN vstupy_kod,
    DROP COLUMN vstupy_vest_kod,
    DROP COLUMN vstupy_vest_nazev,
    DROP COLUMN vstupy_vazba_bus,
    DROP COLUMN vstupy_vazba_csad,
    DROP COLUMN vstupy_vazba_kr,
    DROP COLUMN vstupy_vazba_pr,
    DROP COLUMN vstupy_vazba_privoz,
    DROP COLUMN vstupy_vazba_taxi,
    DROP COLUMN vstupy_vazba_tram,
    DROP COLUMN vstupy_vazba_vlak,
    DROP COLUMN zast_uzel_cislo,
    DROP COLUMN vstupy_popis,
    DROP COLUMN poskyt,
    DROP COLUMN vstupy_mimo_provoz

ALTER TABLE metro
    RENAME wkb_geometry TO geom,
    RENAME vstupy_uzel_nazev TO nazev,
    RENAME vstupy_linka TO linka

SELECT ogc_fid FROM metro WHERE NOT st_isvalid(geom)

---------------------------------------------------------------------

-- 6) odpad

ogr2ogr -f "PostgreSQL" PG:"dbname=pgis_uzpd user=uzpd18_d password=d_uzpd18 host=geo102.fsv.cvut.cz" -a_srs 'EPSG:5514' "odpad.json" -nln uzpd18_d.odpad

ALTER TABLE odpad
    DROP COLUMN objectid,
    DROP COLUMN id,
    DROP COLUMN stationnumber,
    DROP COLUMN stationname,
    DROP COLUMN citydistrictruiancode

ALTER TABLE odpad
    RENAME wkb_geometry TO geom
	
SELECT ogc_fid FROM odpad WHERE NOT st_isvalid(geom)

---------------------------------------------------------------------

-- 7) zaplava2013

ogr2ogr -f "PostgreSQL" PG:"dbname=pgis_uzpd user=uzpd18_d password=d_uzpd18 host=geo102.fsv.cvut.cz" -a_srs 'EPSG:5514' "zaplava2013.json" -nln uzpd18_d.zaplava2013

ALTER TABLE zaplava2013
    DROP COLUMN objectid,
    DROP COLUMN nazev,
    DROP COLUMN typ

ALTER TABLE zaplava2013
    RENAME wkb_geometry TO geom

SELECT id, geom, st_isvalidreason(geom) FROM uzpd18_d.zaplava2013 WHERE NOT st_isvalid(geom)

UPDATE uzpd18_d.zaplava2013 SET geom = st_buffer(geom, 0.0) WHERE NOT st_isvalid(geom)

---------------------------------------------------------------------
---------------------------------------------------------------------

-- SQL DOTAZY

---------------------------------------------------------------------

-- 1) Kolik adresních míst bylo zatopeno během povodní v roce 2013?
-- 1042

SELECT COUNT(a.kod) 
FROM uzpd18_d.adresni_mista AS a
JOIN (SELECT * FROM uzpd18_d.zaplava2013) AS z
ON st_intersects(z.geom, a.geom);



---------------------------------------------------------------------

-- 2) Jaká zdravotnická zařízení byla zasažena povodněmi v roce 2013? Vypište jejich název a správní obvod, ve kterém se nacházejí.
-- Dr.Max LÉKÁRNA, praha-8

SELECT zz.name, zz.district 
FROM uzpd18_d.zdrav_zarizeni AS zz
JOIN uzpd18_d.zaplava2013 AS za 
ON st_intersects(zz.geom,za.geom);


---------------------------------------------------------------------

-- 3) Jaké procento území Prahy zaujímá záplavové území z roku 2013?
-- 5%

SELECT ROUND(
(
SELECT sum(st_area(geom)) FROM uzpd18_d.zaplava2013
)::numeric / (
SELECT sum(st_area(geom)) FROM uzpd18_d.obvody
)::numeric, 2)*100 AS procento_zaplava;



---------------------------------------------------------------------

-- 4) Kolik košů na tříděný odpad se nachází na území Prahy 1?
-- 821

SELECT COUNT(o.ogc_fid) 
FROM uzpd18_d.odpad AS o
JOIN (SELECT * FROM uzpd18_d.obvody WHERE nazev = 'Praha 1') AS p
ON st_intersects(p.geom, o.geom);



---------------------------------------------------------------------

-- 5) Kolik adresních míst leží ve vzdálenosti do 500 m od výlezu ze stanice metra Depo Hostivař?
-- 48

SELECT count(distinct a.kod) 
FROM uzpd18_d.adresni_mista AS a
JOIN uzpd18_d.metro AS m
ON st_dwithin(a.geom, m.geom, 500)
WHERE m.nazev = 'Depo Hostivař';



---------------------------------------------------------------------

-- 6) Jaká stanice metra na Praze 4 má nejvíce vstupů?
-- Budějovická

SELECT m.nazev FROM uzpd18_d.metro AS m
JOIN (SELECT * FROM uzpd18_d.obvody 
WHERE nazev = 'Praha 4') AS p
ON st_intersects(p.geom, m.geom)
GROUP BY m.nazev
ORDER BY COUNT(m.ogc_fid) DESC
LIMIT 1;



---------------------------------------------------------------------

-- 7) Která zdravotnická zařízení leží do 10 m od stanic metra A? V které městské části se tato zařízení nacházejí?
-- Dr.Max LÉKÁRNA, praha-1
-- BENU Lékárna OC Atrium Flora, praha-3

SELECT z.name, z.district 
FROM uzpd18_d.zdrav_zarizeni AS z
JOIN uzpd18_d.metro AS m
ON st_dwithin(z.geom, m.geom, 10)
WHERE m.linka LIKE '%A%';



---------------------------------------------------------------------

-- 8) Kolik dětských hřišť se nachází ve vzdálenosti do 2 kilometrů od nejbližší nemocnice?
-- 61

WITH 
    n AS (
        SELECT * FROM uzpd18_d.zdrav_zarizeni AS z WHERE type LIKE '%nemocnice%')
SELECT COUNT(DISTINCT(h.ogc_fid)) 
FROM uzpd18_d.detska_hriste AS h, n
WHERE n.geom && st_expand(h.geom, 2000);



---------------------------------------------------------------------

-- 9) Kolik adresních míst má lékárnu a dětské hřiště do vzdálenosti 500 m?
-- 25130

WITH
    buff_h AS (
        SELECT st_buffer(geom, 500) AS geom 
        FROM uzpd18_d.detska_hriste AS h),
    buff_z AS (
        SELECT st_buffer(geom, 500) AS geom 
        FROM uzpd18_d.zdrav_zarizeni AS z
        WHERE type = 'Lékárna') 
SELECT COUNT(DISTINCT(kod)) FROM uzpd18_d.adresni_mista AS a
INNER JOIN buff_h ON st_intersects(a.geom, buff_h.geom)
INNER JOIN buff_z ON st_intersects(a.geom, buff_z.geom);


---------------------------------------------------------------------

-- 10) Který pražský správní obvod má nejlepší poměr počtu košů na tříděný odpad vzhledem ke své rozloze? Uveďte název obvodu, jeho rozlohu, počet košů a poměr těchto dvou hodnot.
-- Praha 22,	33660132 m2, 70	košů, 480859

WITH 
    oo AS (
        SELECT ob.nazev, count(od.ogc_fid), ob.geom FROM obvody AS ob
        JOIN uzpd18_d.odpad AS od 
        ON st_intersects(ob.geom, od.geom)
        GROUP BY ob.nazev, ob.geom
        ORDER BY COUNT(od.ogc_fid) DESC),
    area AS (
        SELECT obvody.nazev, st_area(obvody.geom), geom from obvody)
SELECT oo.nazev, ROUND(area.st_area), count, ROUND(area.st_area/count) AS ratio 
FROM oo
JOIN area ON oo.nazev = area.nazev
GROUP BY oo.nazev, area.st_area, count, area.st_area/count
ORDER BY area.st_area/count DESC
LIMIT 1;



---------------------------------------------------------------------

-- 11) Na území kterého pražského správního obvodu se nachází největší množství dětských hřišť a kolik to je?
-- Praha 3, 14
-- Praha 4, 14

SELECT o.nazev, COUNT(distinct dh.ogc_fid) 
FROM uzpd18_d.obvody AS o 
JOIN uzpd18_d.detska_hriste AS dh 
ON st_intersects(dh.geom, o.geom) 
GROUP BY o.nazev
HAVING COUNT(distinct dh.ogc_fid) = (
    SELECT COUNT(distinct dh.ogc_fid) FROM uzpd18_d.obvody AS o 
    JOIN uzpd18_d.detska_hriste AS dh 
    ON st_intersects(dh.geom, o.geom) 
    GROUP BY o.nazev 
    ORDER BY COUNT(distinct dh.ogc_fid) 
    DESC LIMIT 1);


---------------------------------------------------------------------

-- 12) Jaké je id nejbližšího dětského hřiště pro adresní místo s kódem 22560840? V jaké leží vzdálenosti?
-- 102, 506 m

SELECT dh.id, ROUND(st_distance(a.geom, dh.geom)) AS distance 
FROM uzpd18_d.detska_hriste AS dh, uzpd18_d.adresni_mista AS a
WHERE a.kod = '22560840' AND st_distance(a.geom, dh.geom) = (
    SELECT st_distance(a.geom, dh. geom) 
    FROM detska_hriste AS dh, uzpd18_d.adresni_mista AS a
    WHERE a.kod = '22560840' 
    ORDER BY st_distance(a.geom, dh.geom)
    LIMIT 1);
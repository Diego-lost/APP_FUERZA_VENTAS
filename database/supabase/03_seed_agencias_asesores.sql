-- ============================================================
-- SEED: 30 AGENCIAS + 360 ASESORES DE NEGOCIOS
-- Piloto Creditos Preaprobados — App Fuerza de Ventas
-- Ejecutar DESPUES de scoring_preaprobados.sql
-- ============================================================
-- NIVELES Y CARTERAS PROMEDIO:
--   Senior II  → 400 clientes  (3 por agencia)
--   Senior I   → 300 clientes  (3 por agencia)
--   Junior II  → 180 clientes  (3 por agencia)
--   Junior I   →  90 clientes  (3 por agencia)
-- Total por agencia: 12 asesores
-- Total general   : 360 asesores · 30 agencias
-- ============================================================


-- ============================================================
-- PASO 1: TABLAS DE AGENCIAS Y ASESORES
-- (si no existen aun en tu schema)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.agencias (
  id              SERIAL PRIMARY KEY,
  codigo          TEXT NOT NULL UNIQUE,        -- 'AG-001' ... 'AG-030'
  nombre          TEXT NOT NULL,
  region          TEXT NOT NULL,
  departamento    TEXT NOT NULL,
  provincia       TEXT NOT NULL,
  distrito        TEXT NOT NULL,
  direccion       TEXT,
  jefe_agencia    TEXT,
  activa          BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.asesores_negocio (
  id              SERIAL PRIMARY KEY,
  codigo          TEXT NOT NULL UNIQUE,        -- 'AS-001-01' (agencia-numero)
  id_agencia      INT  NOT NULL REFERENCES public.agencias(id),
  nombres         TEXT NOT NULL,
  apellidos       TEXT NOT NULL,
  dni             TEXT,
  email           TEXT,
  telefono        TEXT,
  nivel           TEXT NOT NULL
                    CHECK (nivel IN ('Junior I','Junior II','Senior I','Senior II')),
  cartera_clientes_promedio INT NOT NULL,      -- segun nivel
  meta_creditos_mes         INT NOT NULL,      -- meta mensual de colocaciones
  meta_monto_mes            NUMERIC(14,2) NOT NULL,
  zona_asignada             TEXT,
  activo          BOOLEAN DEFAULT TRUE,
  fecha_ingreso   DATE DEFAULT CURRENT_DATE,
  created_at      TIMESTAMPTZ DEFAULT now()
);


-- ============================================================
-- PASO 2: INSERT — 30 AGENCIAS
-- Distribuidas en regiones del Peru (enfoque microfinanzas)
-- ============================================================

INSERT INTO public.agencias
  (codigo, nombre, region, departamento, provincia, distrito, direccion, jefe_agencia)
VALUES
-- REGION CENTRO
  ('AG-001','Agencia Huancayo Centro',    'Centro','Junin',   'Huancayo',  'Huancayo',      'Jr. Real 423',             'Lic. Rosa Meza Quispe'),
  ('AG-002','Agencia El Tambo',           'Centro','Junin',   'Huancayo',  'El Tambo',      'Av. Leoncio Prado 892',    'Lic. Marco Sulca Vera'),
  ('AG-003','Agencia Chilca',             'Centro','Junin',   'Huancayo',  'Chilca',        'Jr. Loreto 215',           'Lic. Ana Flores Poma'),
  ('AG-004','Agencia Huancavelica',       'Centro','Huancavelica','Huancavelica','Huancavelica','Jr. Virrey Toledo 301', 'Lic. Pedro Asto Leon'),
  ('AG-005','Agencia Tarma',              'Centro','Junin',   'Tarma',     'Tarma',         'Jr. Lima 145',             'Lic. Milagros Ore Cruz'),
  ('AG-006','Agencia La Merced',          'Centro','Junin',   'Chanchamayo','La Merced',    'Jr. Tarma 78',             'Lic. Juan Palian Rojas'),
  ('AG-007','Agencia Cerro de Pasco',     'Centro','Pasco',   'Pasco',     'Chaupimarca',   'Jr. Bolivar 512',          'Lic. Silvia Huaman Tello'),

-- REGION SUR
  ('AG-008','Agencia Cusco Centro',       'Sur',   'Cusco',   'Cusco',     'Cusco',         'Av. El Sol 301',           'Lic. Jorge Quispe Mamani'),
  ('AG-009','Agencia San Sebastian',      'Sur',   'Cusco',   'Cusco',     'San Sebastian', 'Av. De La Cultura 1200',   'Lic. Carmen Huallpa Ttito'),
  ('AG-010','Agencia Sicuani',            'Sur',   'Cusco',   'Canchis',   'Sicuani',       'Jr. 2 de Mayo 89',         'Lic. Roberto Ccallo Quispe'),
  ('AG-011','Agencia Puno',               'Sur',   'Puno',    'Puno',      'Puno',          'Jr. Deustua 456',          'Lic. Yola Mamani Apaza'),
  ('AG-012','Agencia Juliaca',            'Sur',   'Puno',    'San Roman',  'Juliaca',      'Jr. Benigno Ballón 234',   'Lic. Fredy Coaquira Ticona'),
  ('AG-013','Agencia Arequipa Centro',    'Sur',   'Arequipa','Arequipa',  'Arequipa',      'Calle Mercaderes 212',     'Lic. Paola Zegarra Ramos'),
  ('AG-014','Agencia Majes',              'Sur',   'Arequipa','Castilla',  'Aplao',         'Urb. La Colina Mz. C Lt 4','Lic. Luis Salas Quispe'),

-- REGION NORTE
  ('AG-015','Agencia Trujillo Centro',    'Norte', 'La Libertad','Trujillo','Trujillo',     'Jr. Pizarro 534',          'Lic. Maria Lozano Vega'),
  ('AG-016','Agencia Esperanza',          'Norte', 'La Libertad','Trujillo','La Esperanza', 'Av. Condorcanqui 890',     'Lic. Carlos Quiroz Benites'),
  ('AG-017','Agencia Chimbote',           'Norte', 'Ancash',   'Santa',    'Chimbote',      'Jr. Manuel Ruiz 342',      'Lic. Rosa Mejia Torres'),
  ('AG-018','Agencia Huaraz',             'Norte', 'Ancash',   'Huaraz',   'Huaraz',        'Jr. Luzuriaga 678',        'Lic. Abel Cochachin Vega'),
  ('AG-019','Agencia Cajamarca',          'Norte', 'Cajamarca','Cajamarca', 'Cajamarca',    'Jr. Del Comercio 123',     'Lic. Sandra Vasquez Diaz'),
  ('AG-020','Agencia Piura',              'Norte', 'Piura',    'Piura',    'Piura',          'Av. Grau 567',             'Lic. Manuel Chunga Ramos'),
  ('AG-021','Agencia Sullana',            'Norte', 'Piura',    'Sullana',  'Sullana',        'Jr. Jose de Lama 234',     'Lic. Patricia Juarez More'),

-- REGION LIMA / COSTA CENTRO
  ('AG-022','Agencia Lima Centro',        'Lima',  'Lima',     'Lima',     'Lima',           'Jr. de la Union 890',      'Lic. Eduardo Rios Palomino'),
  ('AG-023','Agencia San Juan de Lurigancho','Lima','Lima',    'Lima',     'SJL',            'Av. Próceres 1450',        'Lic. Gisela Condori Huanca'),
  ('AG-024','Agencia Villa El Salvador',  'Lima',  'Lima',     'Lima',     'VES',            'Av. Revolucion 567',       'Lic. Hector Llanos Cuba'),
  ('AG-025','Agencia Comas',              'Lima',  'Lima',     'Lima',     'Comas',          'Av. Tupac Amaru 3210',     'Lic. Sonia Quispe Ramirez'),
  ('AG-026','Agencia Ate Vitarte',        'Lima',  'Lima',     'Lima',     'Ate',            'Carretera Central Km 8',   'Lic. Ricardo Asto Flores'),
  ('AG-027','Agencia Huacho',             'Lima',  'Lima',     'Huaura',   'Huacho',         'Jr. Grau 123',             'Lic. Diana Cisneros Perez'),

-- REGION ORIENTE
  ('AG-028','Agencia Iquitos',            'Oriente','Loreto',  'Maynas',   'Iquitos',        'Jr. Prospero 456',         'Lic. Alfredo Valles Rengifo'),
  ('AG-029','Agencia Pucallpa',           'Oriente','Ucayali', 'Coronel Portillo','Calleria','Jr. Raymondi 789',         'Lic. Noemí Davila Rojas'),
  ('AG-030','Agencia Tarapoto',           'Oriente','San Martin','San Martin','Tarapoto',    'Jr. Jimenez Pimentel 345', 'Lic. Victor Fasabi Grandez')
ON CONFLICT (codigo) DO NOTHING;


-- ============================================================
-- PASO 3: INSERT — 360 ASESORES (12 por agencia x 30 agencias)
-- Distribucion por agencia:
--   Posiciones 1-3  : Senior II  (cartera=400, meta=16 creditos, S/28,800)
--   Posiciones 4-6  : Senior I   (cartera=300, meta=12 creditos, S/21,600)
--   Posiciones 7-9  : Junior II  (cartera=180, meta= 7 creditos, S/12,600)
--   Posiciones 10-12: Junior I   (cartera= 90, meta= 4 creditos, S/ 7,200)
--
-- Metas calculadas con ticket promedio S/1,800 y tasa conversion 4%
-- Senior II : 400 * 0.04 = 16  → S/1800*16 = S/28,800
-- Senior I  : 300 * 0.04 = 12  → S/1800*12 = S/21,600
-- Junior II : 180 * 0.04 =  7  → S/1800*7  = S/12,600
-- Junior I  :  90 * 0.04 =  4  → S/1800*4  = S/ 7,200
-- ============================================================

DO $$
DECLARE

  -- Nombres masculinos y femeninos para variedad
  nombres_m TEXT[] := ARRAY[
    'Carlos','Juan','Luis','Pedro','Jorge','Marco','Roberto',
    'Diego','Andres','Miguel','Fernando','Raul','Cesar','Ivan',
    'Hector','Edwin','Walter','Jhon','Alex','Henry',
    'Kevin','Bryan','Christian','Daniel','David','Oscar',
    'Eduardo','Rodrigo','Victor','Manuel'
  ];
  nombres_f TEXT[] := ARRAY[
    'Maria','Ana','Rosa','Carmen','Silvia','Patricia','Yola',
    'Sandra','Monica','Diana','Milagros','Luz','Lidia','Noemí',
    'Giovanna','Wendy','Cinthia','Paola','Gisela','Sonia',
    'Elena','Flor','Judith','Kelly','Leslie','Vanessa',
    'Roxana','Fiorella','Evelyn','Nataly'
  ];

  -- Apellidos andinos y costenos variados
  apellidos_1 TEXT[] := ARRAY[
    'Quispe','Mamani','Huaman','Flores','Garcia','Lopez','Torres',
    'Ramirez','Sulca','Palian','Ore','Coaquira','Ccallo','Mamani',
    'Ttito','Apaza','Ticona','Zegarra','Salas','Lozano',
    'Quiroz','Mejia','Cochachin','Vasquez','Chunga','Juarez',
    'Rios','Condori','Llanos','Asto'
  ];
  apellidos_2 TEXT[] := ARRAY[
    'Cruz','Vera','Leon','Rojas','Poma','Tello','Vega','Benites',
    'Torres','Diaz','Ramos','More','Palomino','Huanca','Cuba',
    'Ramirez','Flores','Perez','Rengifo','Rojas','Grandez',
    'Quispe','Ccallo','Mamani','Apaza','Pimentel','Castro',
    'Reyes','Silva','Morales'
  ];

  -- Zonas por region
  zonas_centro  TEXT[] := ARRAY['Zona Centro','Zona Norte','Zona Sur','Zona Este','Zona Oeste','Zona Rural'];
  zonas_sur     TEXT[] := ARRAY['Zona Altiplano','Zona Valle','Zona Urbana','Zona Periurbana','Zona Rural','Zona Comercial'];
  zonas_norte   TEXT[] := ARRAY['Zona Comercial','Zona Industrial','Zona Residencial','Zona Mercados','Zona Rural','Zona Agropecuaria'];
  zonas_lima    TEXT[] := ARRAY['Zona Mercados','Zona Comercio','Zona Manufactura','Zona Servicios','Zona Residencial','Zona Periferia'];
  zonas_oriente TEXT[] := ARRAY['Zona Fluvial','Zona Comercial','Zona Agropecuaria','Zona Urbana','Zona Rural','Zona Industrial'];

  -- Variables de iteracion
  ag_id     INT;
  ag_codigo TEXT;
  ag_region TEXT;
  pos       INT;       -- posicion del asesor dentro de la agencia (1-12)
  nivel     TEXT;
  cartera   INT;
  meta_cred INT;
  meta_mnt  NUMERIC;
  nombre    TEXT;
  apellido1 TEXT;
  apellido2 TEXT;
  dni_val   TEXT;
  email_val TEXT;
  tel_val   TEXT;
  zona_val  TEXT;
  zonas_arr TEXT[];
  codigo_as TEXT;
  sufijo    INT;       -- para hacer DNIs unicos

BEGIN
  sufijo := 10000000;

  FOR ag_id IN 1..30 LOOP

    -- Obtener codigo y region de la agencia
    SELECT codigo, region INTO ag_codigo, ag_region
    FROM public.agencias WHERE id = ag_id;

    -- Seleccionar pool de zonas segun region
    zonas_arr := CASE ag_region
      WHEN 'Centro'  THEN zonas_centro
      WHEN 'Sur'     THEN zonas_sur
      WHEN 'Norte'   THEN zonas_norte
      WHEN 'Lima'    THEN zonas_lima
      WHEN 'Oriente' THEN zonas_oriente
      ELSE zonas_centro
    END;

    FOR pos IN 1..12 LOOP

      -- Nivel y parametros segun posicion
      CASE
        WHEN pos BETWEEN 1  AND 3  THEN
          nivel     := 'Senior II';
          cartera   := 400;
          meta_cred := 16;
          meta_mnt  := 28800.00;
        WHEN pos BETWEEN 4  AND 6  THEN
          nivel     := 'Senior I';
          cartera   := 300;
          meta_cred := 12;
          meta_mnt  := 21600.00;
        WHEN pos BETWEEN 7  AND 9  THEN
          nivel     := 'Junior II';
          cartera   := 180;
          meta_cred := 7;
          meta_mnt  := 12600.00;
        ELSE
          nivel     := 'Junior I';
          cartera   := 90;
          meta_cred := 4;
          meta_mnt  := 7200.00;
      END CASE;

      -- Alternar genero: posiciones impares masculino, pares femenino
      IF pos % 2 = 1 THEN
        nombre := nombres_m[((ag_id + pos) % array_length(nombres_m,1)) + 1];
      ELSE
        nombre := nombres_f[((ag_id + pos) % array_length(nombres_f,1)) + 1];
      END IF;

      apellido1 := apellidos_1[((ag_id * 2 + pos)    % array_length(apellidos_1,1)) + 1];
      apellido2 := apellidos_2[((ag_id * 3 + pos + 7) % array_length(apellidos_2,1)) + 1];

      -- Codigo del asesor: AG-XXX-PP
      codigo_as := ag_codigo || '-' || LPAD(pos::TEXT, 2, '0');

      -- DNI unico de 8 digitos
      sufijo    := sufijo + 1;
      dni_val   := sufijo::TEXT;

      -- Email y telefono generados
      email_val := LOWER(LEFT(nombre,3)) || '.' || LOWER(apellido1)
                   || ag_id::TEXT || '@asesores.pe';
      tel_val   := '9' || LPAD(((ag_id * 100 + pos * 7 + 1000000) % 10000000)::TEXT, 8, '0');
      tel_val   := LEFT(tel_val, 9);

      -- Zona ciclica segun posicion
      zona_val  := zonas_arr[((pos - 1) % array_length(zonas_arr,1)) + 1];

      INSERT INTO public.asesores_negocio (
        codigo, id_agencia, nombres, apellidos, dni, email, telefono,
        nivel, cartera_clientes_promedio,
        meta_creditos_mes, meta_monto_mes,
        zona_asignada, activo, fecha_ingreso
      ) VALUES (
        codigo_as,
        ag_id,
        nombre,
        apellido1 || ' ' || apellido2,
        dni_val,
        email_val,
        tel_val,
        nivel,
        cartera,
        meta_cred,
        meta_mnt,
        zona_val,
        TRUE,
        -- Fecha de ingreso proporcional al nivel: seniors mas antiguos
        CURRENT_DATE - (
          CASE nivel
            WHEN 'Senior II' THEN (730 + (pos * 30))
            WHEN 'Senior I'  THEN (365 + (pos * 20))
            WHEN 'Junior II' THEN (180 + (pos * 15))
            ELSE                  ( 60 + (pos * 10))
          END
        )
      )
      ON CONFLICT (codigo) DO NOTHING;

    END LOOP; -- fin loop asesores
  END LOOP;   -- fin loop agencias

END $$;


-- ============================================================
-- PASO 4: VISTA RESUMEN PARA POWER BI
-- ============================================================

CREATE OR REPLACE VIEW public.vw_pbi_asesores AS
SELECT
  an.id,
  an.codigo,
  an.nombres,
  an.apellidos,
  an.nombres || ' ' || an.apellidos  AS nombre_completo,
  an.nivel,
  an.cartera_clientes_promedio,
  an.meta_creditos_mes,
  an.meta_monto_mes,
  an.zona_asignada,
  an.fecha_ingreso,
  -- Antiguedad en meses
  EXTRACT(YEAR FROM AGE(an.fecha_ingreso))::INT * 12 +
  EXTRACT(MONTH FROM AGE(an.fecha_ingreso))::INT     AS antiguedad_meses,
  -- Datos de agencia
  ag.codigo                          AS codigo_agencia,
  ag.nombre                          AS agencia,
  ag.region,
  ag.departamento,
  ag.provincia,
  ag.distrito                        AS distrito_agencia,
  ag.jefe_agencia,
  -- KPIs derivados (se enriquecen con fichas_campo)
  an.meta_creditos_mes               AS creditos_meta,
  an.meta_monto_mes                  AS monto_meta,
  -- Cartera total de la agencia (suma de todos los asesores)
  SUM(an.cartera_clientes_promedio)
    OVER (PARTITION BY an.id_agencia) AS cartera_total_agencia
FROM public.asesores_negocio an
JOIN public.agencias          ag ON an.id_agencia = ag.id
WHERE an.activo = TRUE;


-- ============================================================
-- PASO 5: VISTA RESUMEN GERENCIAL — AGENCIAS
-- ============================================================

CREATE OR REPLACE VIEW public.vw_pbi_agencias AS
SELECT
  ag.id,
  ag.codigo,
  ag.nombre,
  ag.region,
  ag.departamento,
  ag.provincia,
  ag.distrito,
  ag.jefe_agencia,
  COUNT(an.id)                                         AS total_asesores,
  COUNT(an.id) FILTER (WHERE an.nivel = 'Senior II')  AS senior_ii,
  COUNT(an.id) FILTER (WHERE an.nivel = 'Senior I')   AS senior_i,
  COUNT(an.id) FILTER (WHERE an.nivel = 'Junior II')  AS junior_ii,
  COUNT(an.id) FILTER (WHERE an.nivel = 'Junior I')   AS junior_i,
  SUM(an.cartera_clientes_promedio)                    AS cartera_total,
  SUM(an.meta_creditos_mes)                            AS meta_creditos_agencia,
  SUM(an.meta_monto_mes)                               AS meta_monto_agencia,
  -- Promedio de cartera por nivel
  AVG(an.cartera_clientes_promedio)
    FILTER (WHERE an.nivel = 'Senior II')              AS cartera_prom_senior_ii,
  AVG(an.cartera_clientes_promedio)
    FILTER (WHERE an.nivel = 'Senior I')               AS cartera_prom_senior_i,
  AVG(an.cartera_clientes_promedio)
    FILTER (WHERE an.nivel = 'Junior II')              AS cartera_prom_junior_ii,
  AVG(an.cartera_clientes_promedio)
    FILTER (WHERE an.nivel = 'Junior I')               AS cartera_prom_junior_i
FROM public.agencias          ag
LEFT JOIN public.asesores_negocio an ON ag.id = an.id_agencia AND an.activo = TRUE
GROUP BY ag.id, ag.codigo, ag.nombre, ag.region,
         ag.departamento, ag.provincia, ag.distrito, ag.jefe_agencia;


-- ============================================================
-- VERIFICACION RAPIDA (ejecutar despues del seed)
-- ============================================================

-- Total de registros generados:
-- SELECT COUNT(*) FROM public.agencias;          -- debe dar 30
-- SELECT COUNT(*) FROM public.asesores_negocio;  -- debe dar 360

-- Distribucion por nivel:
-- SELECT nivel, COUNT(*), AVG(cartera_clientes_promedio) AS cartera_prom,
--        SUM(meta_monto_mes) AS meta_monto_total
-- FROM public.asesores_negocio
-- GROUP BY nivel ORDER BY cartera_clientes_promedio DESC;

-- Resumen por agencia:
-- SELECT * FROM public.vw_pbi_agencias ORDER BY region, nombre;

-- ============================================================
-- FIN DEL SCRIPT
-- seed_agencias_asesores.sql — v1.0 — 2026
-- ============================================================

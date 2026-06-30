-- ============================================================
-- SEED CORREGIDO: 1,800 CLIENTES — 5 POR ASESOR
-- 30 agencias x 12 asesores x 5 clientes = 1,800
-- Compatible con scoring_preaprobados.sql
--                 seed_agencias_asesores.sql
-- ============================================================
-- Cada cliente queda vinculado al asesor y agencia que lo
-- atiende. Los features, scores y fichas de campo se calculan
-- de forma coherente con el nivel del asesor.
--
-- Logica de scoring por nivel de asesor:
--   Senior II  → cartera de mayor score (clientes mas maduros)
--   Senior I   → score medio-alto
--   Junior II  → score medio
--   Junior I   → score mas bajo, clientes nuevos
-- ============================================================
-- Orden previo obligatorio:
--   00_extensions.sql, 01_supabase_setup.sql,
--   02_scoring_preaprobados.sql, 03_seed_agencias_asesores.sql
-- Este archivo incluye seed_auth_user (no hace falta 02b por separado).
-- Contraseña de prueba de clientes: Cliente2026!
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.auth_mock (
  id         UUID PRIMARY KEY,
  email      TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.seed_auth_user(p_id UUID, p_email TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_instance_id UUID;
BEGIN
  SELECT id INTO v_instance_id FROM auth.instances LIMIT 1;
  IF v_instance_id IS NULL THEN
    v_instance_id := '00000000-0000-0000-0000-000000000000'::UUID;
  END IF;

  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    is_super_admin,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change
  ) VALUES (
    v_instance_id,
    p_id,
    'authenticated',
    'authenticated',
    p_email,
    extensions.crypt('Cliente2026!', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"seed":true}'::jsonb,
    now(),
    now(),
    false,
    '',
    '',
    '',
    ''
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    encrypted_password = EXCLUDED.encrypted_password,
    email_confirmed_at = COALESCE(auth.users.email_confirmed_at, EXCLUDED.email_confirmed_at),
    updated_at = now();

  -- GoTrue exige identity con provider_id = UUID del usuario (no el email)
  DELETE FROM auth.identities
  WHERE user_id = p_id AND provider = 'email';

  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    p_id,
    p_id,
    jsonb_build_object(
      'sub', p_id::text,
      'email', p_email,
      'email_verified', true,
      'phone_verified', false
    ),
    'email',
    p_id::text,
    now(),
    now(),
    now()
  );
END;
$$;

-- Alinear cuentas/transacciones si el schema vino de otro script (sin numero_cuenta)
ALTER TABLE public.cuentas ADD COLUMN IF NOT EXISTS numero_cuenta TEXT;
ALTER TABLE public.cuentas ADD COLUMN IF NOT EXISTS moneda TEXT DEFAULT 'PEN';

UPDATE public.cuentas
SET numero_cuenta = '019-' || LPAD(
      RIGHT(regexp_replace(id::text, '[^0-9]', '', 'g'), 7),
      7, '0'
    )
WHERE numero_cuenta IS NULL OR numero_cuenta = '';

UPDATE public.cuentas SET moneda = 'PEN' WHERE moneda IS NULL;

ALTER TABLE public.cuentas DROP CONSTRAINT IF EXISTS cuentas_tipo_check;
ALTER TABLE public.cuentas
  ADD CONSTRAINT cuentas_tipo_check
  CHECK (tipo IN ('corriente', 'ahorro', 'ahorros'));

ALTER TABLE public.transacciones ADD COLUMN IF NOT EXISTS descripcion TEXT;

BEGIN;

DO $$
DECLARE

  -- -------------------------------------------------------
  -- CATALOGOS
  -- -------------------------------------------------------
  nombres_m   TEXT[] := ARRAY[
    'Carlos','Juan','Luis','Pedro','Jorge','Marco','Roberto',
    'Diego','Andres','Miguel','Fernando','Raul','Cesar','Ivan',
    'Hector','Edwin','Walter','Alex','Henry','Kevin',
    'Bryan','Daniel','David','Oscar','Eduardo','Rodrigo',
    'Victor','Manuel','Richard','Jhon'
  ];
  nombres_f   TEXT[] := ARRAY[
    'Maria','Ana','Rosa','Carmen','Silvia','Patricia','Yola',
    'Sandra','Monica','Diana','Milagros','Luz','Lidia','Noemi',
    'Giovanna','Wendy','Cinthia','Paola','Gisela','Sonia',
    'Elena','Flor','Judith','Kelly','Leslie','Vanessa',
    'Roxana','Fiorella','Evelyn','Nataly'
  ];
  apellidos_1 TEXT[] := ARRAY[
    'Quispe','Mamani','Huaman','Flores','Garcia','Lopez','Torres',
    'Ramirez','Sulca','Palian','Ore','Coaquira','Ccallo','Apaza',
    'Ttito','Ticona','Zegarra','Salas','Lozano','Quiroz',
    'Mejia','Cochachin','Vasquez','Chunga','Juarez','Rios',
    'Condori','Llanos','Asto','Poma'
  ];
  apellidos_2 TEXT[] := ARRAY[
    'Cruz','Vera','Leon','Rojas','Tello','Vega','Benites',
    'Torres','Diaz','Ramos','More','Palomino','Huanca','Cuba',
    'Ramirez','Flores','Perez','Rengifo','Grandez','Castro',
    'Reyes','Silva','Morales','Quispe','Mamani','Apaza',
    'Pimentel','Ccallo','Ttito','Coaquira'
  ];
  tipos_neg   TEXT[] := ARRAY[
    'Bodega','Restaurante','Ferreteria','Tienda de ropa','Farmacia',
    'Panaderia','Carpinteria','Zapateria','Merceria','Libreria',
    'Salon de belleza','Taller mecanico','Fruteria','Carniceria',
    'Polleria','Internet cafe','Papeleria','Joyeria','Floristeria',
    'Heladeria','Bazar','Lubricentro','Agroveterinaria','Confecciones',
    'Pasteleria'
  ];

  -- Opciones de campo
  tenencias       TEXT[] := ARRAY['alquilado_sin_contrato','alquilado_con_contrato','propio'];
  tenencia_pts    INT[]  := ARRAY[0, 10, 20];
  antigned_opts   TEXT[] := ARRAY['menos_1_anio','1_a_3_anios','mas_3_anios'];
  antigned_pts    INT[]  := ARRAY[0, 20, 40];
  ventas_rangos   TEXT[] := ARRAY['menos_50','50_a_150','151_a_300','mas_300'];
  ventas_pts      INT[]  := ARRAY[0, 15, 30, 45];
  ventas_montos   NUMERIC[] := ARRAY[30, 100, 220, 400];
  gastos_rangos   TEXT[] := ARRAY['mas_80pct','50_a_80pct','menos_50pct'];
  gastos_pts      INT[]  := ARRAY[0, 5, 15];
  deuda_opts      TEXT[] := ARRAY['si_significativa','si_menor','no'];
  deuda_pts       INT[]  := ARRAY[-50, -20, 20];
  pandero_opts    TEXT[] := ARRAY['si_mayor_cuota','si_menor_cuota','no'];
  pandero_pts     INT[]  := ARRAY[-20, 0, 20];
  stock_opts      TEXT[] := ARRAY['escaso','moderado','abundante'];
  stock_pts       INT[]  := ARRAY[0, 10, 20];
  activos_opts    TEXT[] := ARRAY['ninguno','al_menos_uno'];
  activos_pts     INT[]  := ARRAY[0, 20];

  -- -------------------------------------------------------
  -- VARIABLES DE ITERACION
  -- -------------------------------------------------------
  -- Asesor actual
  asesor_rec      RECORD;
  agencia_rec     RECORD;

  -- Contador global de clientes (para DNI unico)
  cli_global      INT := 0;

  -- Por cliente
  c               INT;   -- 1..5 dentro del asesor
  uid             UUID;
  cuenta_id       UUID;
  score_id        UUID;
  ficha_id        UUID;

  nombre          TEXT;
  apellido1       TEXT;
  apellido2       TEXT;
  dni_val         TEXT;
  email_val       TEXT;
  tel_val         TEXT;
  nacimiento      DATE;
  tipo_neg        TEXT;
  dir_negocio     TEXT;

  -- Parametros financieros — dependen del nivel del asesor
  -- Senior II: clientes maduros, saldos altos
  -- Junior I : clientes nuevos, saldos bajos
  saldo_base      NUMERIC;
  saldo_prom      NUMERIC;
  ingreso_prom    NUMERIC;
  ratio_ahorro    NUMERIC;
  antiguedad_c    INT;
  meses_abono     SMALLINT;
  num_entidades   SMALLINT;

  -- Scores
  p_saldo         SMALLINT;
  p_regular       SMALLINT;
  p_disciplina    SMALLINT;
  p_vinculo       SMALLINT;
  p_riesgo        SMALLINT;
  score_trans     SMALLINT;
  segmento_pre    TEXT;
  monto_hip       NUMERIC;

  -- Campo
  idx_ant         INT; idx_ten  INT; idx_ven  INT;
  idx_gas         INT; idx_deu  INT; idx_pan  INT;
  idx_stk         INT; idx_act  INT;
  p_ant           SMALLINT; p_ten SMALLINT; p_ven SMALLINT;
  p_gas           SMALLINT; p_deu SMALLINT; p_pan SMALLINT;
  p_stk           SMALLINT; p_act SMALLINT;
  score_campo     SMALLINT;
  score_final     SMALLINT;
  seg_final       TEXT;

  -- Monto y plazos
  techo_seg       NUMERIC;
  plazo_max       SMALLINT;
  monto_campo     NUMERIC;
  cuota_est       NUMERIC;
  tem             NUMERIC;
  factor_cuota    NUMERIC;
  recomend        TEXT;
  comite_res      TEXT;
  monto_final     NUMERIC;

  -- Fechas y mora
  fecha_preap     DATE;
  fecha_visita    DATE;
  fecha_aprob     DATE;
  fecha_desemb    DATE;
  dias_mora_val   SMALLINT;
  estado_pago_v   TEXT;

  -- Semilla para variedad por asesor+cliente (BIGINT evita overflow)
  semilla         BIGINT;

  -- Loop de transacciones mensuales
  mes_offset      INT;

BEGIN

  -- -------------------------------------------------------
  -- LOOP PRINCIPAL: cada asesor de negocios
  -- -------------------------------------------------------
  FOR asesor_rec IN
    SELECT an.id          AS asesor_id,
           an.codigo      AS asesor_codigo,
           an.nombres || ' ' || an.apellidos AS asesor_nombre,
           an.nivel,
           an.zona_asignada,
           an.id_agencia
    FROM public.asesores_negocio an
    WHERE an.activo = TRUE
    ORDER BY an.id
  LOOP

    -- Datos de la agencia del asesor
    SELECT ag.nombre, ag.jefe_agencia, ag.departamento, ag.distrito
    INTO agencia_rec
    FROM public.agencias ag
    WHERE ag.id = asesor_rec.id_agencia;

    -- ---- 5 CLIENTES POR ASESOR -------------------------
    FOR c IN 1..5 LOOP

      cli_global := cli_global + 1;
      semilla    := asesor_rec.asesor_id::bigint * 17 + c * 31;
      uid        := gen_random_uuid();

      -- Datos personales
      IF semilla % 2 = 0 THEN
        nombre := nombres_m[(semilla % array_length(nombres_m,1)) + 1];
      ELSE
        nombre := nombres_f[(semilla % array_length(nombres_f,1)) + 1];
      END IF;
      apellido1   := apellidos_1[((semilla * 3) % array_length(apellidos_1,1)) + 1];
      apellido2   := apellidos_2[((semilla * 7) % array_length(apellidos_2,1)) + 1];
      dni_val     := LPAD((20000000 + cli_global)::TEXT, 8, '0');
      email_val   := LOWER(LEFT(nombre,3)) || '.' || LOWER(apellido1)
                     || cli_global::TEXT || '@cliente.pe';
      tel_val     := '9' || LPAD(
                     (((cli_global::bigint * 9876543) % 100000000)::text),
                     8, '0'
                   );
      nacimiento  := CURRENT_DATE - (
                     (22 * 365) + ((semilla * 173) % (43 * 365))
                   )::integer;
      tipo_neg    := tipos_neg[(semilla % array_length(tipos_neg,1)) + 1];
      dir_negocio := 'Jr. ' || apellido1 || ' ' || (100 + semilla % 900)::TEXT
                     || ', ' || agencia_rec.distrito;

      -- ---- PARAMETROS FINANCIEROS SEGUN NIVEL ----------
      -- Senior II: saldos S/2,000-7,000  ratio_ahorro 25-40%  antiguedad 24-60m
      -- Senior I : saldos S/1,000-3,500  ratio_ahorro 18-30%  antiguedad 18-48m
      -- Junior II: saldos S/  400-1,500  ratio_ahorro 10-20%  antiguedad 10-30m
      -- Junior I : saldos S/  150-  600  ratio_ahorro  3-12%  antiguedad  6-18m

      CASE asesor_rec.nivel
        WHEN 'Senior II' THEN
          saldo_base   := 2000 + (semilla % 5001);           -- 2000-7000
          ratio_ahorro := 0.25 + (semilla % 16) * 0.01;      -- 25-40%
          antiguedad_c := 24   + (semilla % 37);             -- 24-60 meses
          meses_abono  := 9    + (semilla % 4)::SMALLINT;    -- 9-12
          num_entidades:= (semilla % 3)::SMALLINT;           -- 0-2

        WHEN 'Senior I' THEN
          saldo_base   := 1000 + (semilla % 2501);
          ratio_ahorro := 0.18 + (semilla % 13) * 0.01;
          antiguedad_c := 18   + (semilla % 31);
          meses_abono  := 8    + (semilla % 4)::SMALLINT;
          num_entidades:= (semilla % 3)::SMALLINT;

        WHEN 'Junior II' THEN
          saldo_base   := 400  + (semilla % 1101);
          ratio_ahorro := 0.10 + (semilla % 11) * 0.01;
          antiguedad_c := 10   + (semilla % 21);
          meses_abono  := 6    + (semilla % 4)::SMALLINT;
          num_entidades:= (semilla % 4)::SMALLINT;

        ELSE -- Junior I
          saldo_base   := 150  + (semilla % 451);
          ratio_ahorro := 0.03 + (semilla % 10) * 0.01;
          antiguedad_c := 6    + (semilla % 13);
          meses_abono  := 4    + (semilla % 4)::SMALLINT;
          num_entidades:= (semilla % 5)::SMALLINT;
      END CASE;

      saldo_prom   := saldo_base;
      ingreso_prom := saldo_prom * (1.8 + (semilla % 5) * 0.15);
      meses_abono  := LEAST(meses_abono, 12::SMALLINT);
      num_entidades:= LEAST(num_entidades, 4::SMALLINT);

      -- Usuario en auth.users (requerido por FK) + registro mock
      PERFORM public.seed_auth_user(uid, email_val);
      INSERT INTO public.auth_mock (id, email)
      VALUES (uid, email_val)
      ON CONFLICT (id) DO NOTHING;

      -- perfiles_clientes
      INSERT INTO public.perfiles_clientes (
        user_id, dni, nombres, apellidos,
        fecha_nacimiento, telefono,
        distrito, provincia, departamento,
        nombre_negocio, tipo_negocio, direccion_negocio,
        lat_negocio, lng_negocio,
        antiguedad_negocio_meses, tenencia_local,
        num_entidades_sbs, calificacion_sbs, deuda_total_sbs,
        estado_cliente
      ) VALUES (
        uid, dni_val, nombre, apellido1 || ' ' || apellido2,
        nacimiento, tel_val,
        agencia_rec.distrito,
        agencia_rec.departamento,
        agencia_rec.departamento,
        tipo_neg || ' ' || apellido1, tipo_neg, dir_negocio,
        -- Coordenadas ficticias con offset por agencia
        -12.0640 + (asesor_rec.id_agencia * 0.15) + (c * 0.003),
        -75.2050 + (asesor_rec.id_agencia * 0.12) + (c * 0.002),
        12 + (semilla % 85),
        tenencias[(semilla % 3) + 1],
        num_entidades, 'Normal',
        CASE num_entidades
          WHEN 0 THEN 0
          WHEN 1 THEN 1500 + (semilla % 3000)
          WHEN 2 THEN 4000 + (semilla % 5000)
          WHEN 3 THEN 7000 + (semilla % 6000)
          ELSE       11000 + (semilla % 7000)
        END,
        'activo'
      );

      -- cuentas
      cuenta_id := gen_random_uuid();
      INSERT INTO public.cuentas (
        id, user_id, tipo, numero_cuenta, saldo, moneda, created_at
      ) VALUES (
        cuenta_id, uid,
        CASE WHEN semilla % 3 = 0 THEN 'ahorro' ELSE 'corriente' END,
        '019-' || LPAD(cli_global::TEXT, 7, '0'),
        ROUND(saldo_prom * (0.88 + (semilla % 5) * 0.06), 2),
        'PEN',
        now() - (antiguedad_c || ' months')::INTERVAL
      );

      -- transacciones: 2-3 por mes activo
      FOR mes_offset IN 1..12 LOOP
        IF mes_offset <= meses_abono THEN
          -- Abono principal
          INSERT INTO public.transacciones (
            user_id, cuenta_id, tipo, descripcion, monto, fecha
          ) VALUES (
            uid, cuenta_id, 'credito',
            'Deposito ventas ' || tipo_neg,
            ROUND(ingreso_prom * (0.85 + ((semilla + mes_offset) % 5) * 0.07), 2),
            now() - ((mes_offset * 30 + semilla % 15) || ' days')::INTERVAL
          );
          -- Cargo principal
          INSERT INTO public.transacciones (
            user_id, cuenta_id, tipo, descripcion, monto, fecha
          ) VALUES (
            uid, cuenta_id, 'debito', 'Pago proveedor',
            ROUND(ingreso_prom * (1 - ratio_ahorro) * 0.65, 2),
            now() - ((mes_offset * 30 - 5 + semilla % 10) || ' days')::INTERVAL
          );
          -- Cargo servicios (meses pares)
          IF mes_offset % 2 = 0 THEN
            INSERT INTO public.transacciones (
              user_id, cuenta_id, tipo, descripcion, monto, fecha
            ) VALUES (
              uid, cuenta_id, 'debito', 'Pago servicios',
              ROUND(ingreso_prom * (1 - ratio_ahorro) * 0.20, 2),
              now() - ((mes_offset * 30 - 10 + semilla % 8) || ' days')::INTERVAL
            );
          END IF;
        END IF;
      END LOOP;

      -- movimientos_mensuales (ultimo mes)
      INSERT INTO public.movimientos_mensuales (
        user_id, cuenta_id, periodo,
        abonos_mes, cargos_mes, saldo_fin_mes, num_transacciones
      ) VALUES (
        uid, cuenta_id,
        TO_CHAR(now() - '1 month'::INTERVAL, 'YYYY-MM'),
        ROUND(ingreso_prom, 2),
        ROUND(ingreso_prom * (1 - ratio_ahorro), 2),
        ROUND(saldo_prom, 2),
        3 + semilla % 4
      );

      -- features_scoring
      INSERT INTO public.features_scoring (
        user_id,
        saldo_promedio, saldo_minimo, meses_saldo_positivo,
        ingreso_promedio, meses_con_abono, volatilidad_ingresos,
        ratio_ahorro_neto, depositos_recurrentes,
        antiguedad_cuenta_meses, meses_activos,
        edad, num_entidades_sbs,
        cuota_max_estimada, monto_max_por_ingreso,
        periodos_analizados
      ) VALUES (
        uid,
        ROUND(saldo_prom, 2),
        ROUND(saldo_prom * 0.40, 2),
        LEAST(meses_abono + 1, 12)::SMALLINT,
        ROUND(ingreso_prom, 2),
        meses_abono,
        ROUND(ingreso_prom * 0.12, 4),
        ROUND(ratio_ahorro, 4),
        CASE WHEN ratio_ahorro >= 0.10 THEN 7 ELSE 3 END,
        antiguedad_c,
        meses_abono,
        EXTRACT(YEAR FROM AGE(nacimiento))::SMALLINT,
        num_entidades,
        ROUND(ingreso_prom * 0.30, 2),
        ROUND(ingreso_prom * 2.00, 2),
        LEAST(antiguedad_c, 12)::SMALLINT
      );

      -- ---- SCORE TRANSACCIONAL --------------------------
      p_saldo := CASE
        WHEN saldo_prom >= 5000 THEN 200
        WHEN saldo_prom >= 2000 THEN 160
        WHEN saldo_prom >= 1000 THEN 120
        WHEN saldo_prom >= 500  THEN 80
        WHEN saldo_prom >= 200  THEN 40
        ELSE 0
      END;
      p_regular := CASE
        WHEN meses_abono >= 11 THEN 160
        WHEN meses_abono >= 9  THEN 128
        WHEN meses_abono >= 7  THEN 96
        WHEN meses_abono >= 5  THEN 64
        ELSE 24
      END;
      p_disciplina := CASE
        WHEN ratio_ahorro >= 0.30 THEN 160
        WHEN ratio_ahorro >= 0.20 THEN 120
        WHEN ratio_ahorro >= 0.10 THEN 80
        WHEN ratio_ahorro >= 0.01 THEN 40
        ELSE 0
      END;
      p_vinculo := CASE
        WHEN antiguedad_c >= 36 THEN 160
        WHEN antiguedad_c >= 24 THEN 120
        WHEN antiguedad_c >= 12 THEN 80
        ELSE 40
      END;
      p_riesgo := CASE
        WHEN num_entidades = 0  THEN 120
        WHEN num_entidades = 1  THEN 90
        WHEN num_entidades <= 3 THEN 48
        ELSE 12
      END;

      score_trans  := p_saldo + p_regular + p_disciplina + p_vinculo + p_riesgo;
      segmento_pre := CASE
        WHEN score_trans >= 600 THEN 'PREMIER'
        WHEN score_trans >= 440 THEN 'ESTANDAR'
        WHEN score_trans >= 280 THEN 'BASICO'
        ELSE 'NO_APLICA'
      END;
      monto_hip := CASE
        WHEN segmento_pre = 'PREMIER'  THEN LEAST(ingreso_prom * 2, 5000)
        WHEN segmento_pre = 'ESTANDAR' THEN LEAST(ingreso_prom * 2, 2500)
        WHEN segmento_pre = 'BASICO'   THEN LEAST(ingreso_prom * 2, 1000)
        ELSE 0
      END;

      score_id := gen_random_uuid();
      INSERT INTO public.scores_transaccionales (
        id, user_id,
        pts_saldo, pts_regularidad, pts_disciplina, pts_vinculo, pts_riesgo,
        monto_hipotesis, ingreso_promedio_ref, cuota_max_ref,
        es_valido, fecha_calculo
      ) VALUES (
        score_id, uid,
        p_saldo, p_regular, p_disciplina, p_vinculo, p_riesgo,
        ROUND(monto_hip, 2),
        ROUND(ingreso_prom, 2),
        ROUND(ingreso_prom * 0.30, 2),
        segmento_pre <> 'NO_APLICA',
        now() - ((semilla % 7) || ' days')::INTERVAL
      );

      -- ---- FICHA DE CAMPO (si es elegible) --------------
      IF segmento_pre <> 'NO_APLICA' THEN

        -- Indices de campo: sesgados por nivel del asesor
        -- Senior II visita clientes mas establecidos
        idx_ant := CASE asesor_rec.nivel
          WHEN 'Senior II' THEN 2 + (semilla % 2)   -- 1_a_3 o mas_3
          WHEN 'Senior I'  THEN 1 + (semilla % 3)
          WHEN 'Junior II' THEN 1 + (semilla % 3)
          ELSE                  1 + (semilla % 2)   -- menos_1 o 1_a_3
        END;
        idx_ant := LEAST(idx_ant, 3);

        idx_ten := CASE asesor_rec.nivel
          WHEN 'Senior II' THEN 2 + (semilla % 2)
          WHEN 'Senior I'  THEN 1 + (semilla % 3)
          ELSE                  1 + (semilla % 2)
        END;
        idx_ten := LEAST(idx_ten, 3);

        idx_ven := CASE asesor_rec.nivel
          WHEN 'Senior II' THEN 3 + (semilla % 2)
          WHEN 'Senior I'  THEN 2 + (semilla % 3)
          WHEN 'Junior II' THEN 2 + (semilla % 2)
          ELSE                  1 + (semilla % 2)
        END;
        idx_ven := LEAST(idx_ven, 4);

        idx_gas := CASE asesor_rec.nivel
          WHEN 'Senior II' THEN 3
          WHEN 'Senior I'  THEN 2 + (semilla % 2)
          ELSE                  1 + (semilla % 3)
        END;
        idx_gas := LEAST(idx_gas, 3);

        -- Deuda informal: Junior I tiene mas incidencia
        idx_deu := CASE
          WHEN asesor_rec.nivel = 'Junior I'  AND semilla % 4 = 0 THEN 1  -- si_significativa
          WHEN asesor_rec.nivel = 'Junior I'  AND semilla % 3 = 0 THEN 2  -- si_menor
          WHEN asesor_rec.nivel = 'Junior II' AND semilla % 5 = 0 THEN 2
          WHEN semilla % 8 = 0                                    THEN 2
          ELSE 3  -- no
        END;

        idx_pan := CASE
          WHEN semilla % 7 = 0 THEN 2  -- si_menor_cuota
          WHEN semilla % 15 = 0 THEN 1 -- si_mayor_cuota
          ELSE 3  -- no
        END;

        idx_stk := CASE asesor_rec.nivel
          WHEN 'Senior II' THEN 3
          WHEN 'Senior I'  THEN 2 + (semilla % 2)
          WHEN 'Junior II' THEN 1 + (semilla % 3)
          ELSE                  1 + (semilla % 2)
        END;
        idx_stk := LEAST(idx_stk, 3);

        idx_act := CASE WHEN saldo_prom >= 1500 THEN 2 ELSE 1 + (semilla % 2) END;
        idx_act := LEAST(idx_act, 2);

        p_ant := antigned_pts[idx_ant];
        p_ten := tenencia_pts[idx_ten];
        p_ven := ventas_pts[idx_ven];
        p_gas := gastos_pts[idx_gas];
        p_deu := deuda_pts[idx_deu];
        p_pan := pandero_pts[idx_pan];
        p_stk := stock_pts[idx_stk];
        p_act := activos_pts[idx_act];

        score_campo := p_ant+p_ten+p_ven+p_gas+p_deu+p_pan+p_stk+p_act;
        score_final := score_trans + score_campo;

        seg_final := CASE
          WHEN score_final >= 750 THEN 'PREMIER'
          WHEN score_final >= 550 THEN 'ESTANDAR'
          WHEN score_final >= 350 THEN 'BASICO'
          ELSE 'NO_APLICA'
        END;

        techo_seg := CASE seg_final
          WHEN 'PREMIER'  THEN 5000
          WHEN 'ESTANDAR' THEN 2500
          WHEN 'BASICO'   THEN 1000
          ELSE 0
        END;
        plazo_max := CASE seg_final
          WHEN 'PREMIER'  THEN 12
          WHEN 'ESTANDAR' THEN 6
          ELSE                 3
        END::SMALLINT;

        tem := POWER(1.60, 1.0/12) - 1;
        IF plazo_max > 0 AND ABS(POWER(1 + tem, plazo_max) - 1) > 0.000001 THEN
          factor_cuota := tem * POWER(1 + tem, plazo_max) / (POWER(1 + tem, plazo_max) - 1);
        ELSE
          factor_cuota := 0;
        END IF;
        monto_campo := CASE
          WHEN factor_cuota > 0 THEN
            LEAST(techo_seg, ingreso_prom * 2, (ingreso_prom * 0.30) / factor_cuota)
          ELSE techo_seg
        END;
        monto_campo  := ROUND(GREATEST(monto_campo, 0), 2);
        cuota_est    := ROUND(monto_campo * factor_cuota, 2);

        recomend := CASE
          WHEN seg_final = 'NO_APLICA'  THEN 'rechazar'
          WHEN score_final >= 750       THEN
            CASE semilla % 5 WHEN 0 THEN 'aprobar_monto_reducido' ELSE 'aprobar' END
          WHEN score_final >= 550       THEN
            CASE semilla % 6 WHEN 0 THEN 'elevar_comite'
                             WHEN 1 THEN 'aprobar_monto_reducido'
                             ELSE        'aprobar' END
          ELSE
            CASE semilla % 4 WHEN 0 THEN 'rechazar'
                             WHEN 1 THEN 'elevar_comite'
                             ELSE        'aprobar_monto_reducido' END
        END;

        comite_res := CASE
          WHEN recomend = 'rechazar'                         THEN 'rechazado'
          WHEN recomend = 'elevar_comite' AND semilla%3 = 0  THEN 'rechazado'
          WHEN recomend = 'aprobar_monto_reducido'           THEN 'aprobado_ajuste'
          ELSE                                                    'aprobado'
        END;

        monto_final := CASE comite_res
          WHEN 'aprobado_ajuste' THEN ROUND(monto_campo * 0.85, 2)
          WHEN 'aprobado'        THEN monto_campo
          ELSE 0
        END;

        fecha_preap  := CURRENT_DATE - (5 + (semilla % 50))::INT;
        fecha_visita := fecha_preap  + 3 + (semilla % 5)::INT;
        fecha_aprob  := CASE WHEN comite_res IN ('aprobado','aprobado_ajuste')
                          THEN fecha_visita + 1 ELSE NULL END;
        fecha_desemb := CASE WHEN comite_res IN ('aprobado','aprobado_ajuste')
                          THEN fecha_aprob + 1 ELSE NULL END;

        -- Mora: ~5% leve, ~2% atraso 30d — Junior I tiene mayor incidencia
        dias_mora_val := CASE
          WHEN comite_res NOT IN ('aprobado','aprobado_ajuste') THEN 0
          WHEN asesor_rec.nivel = 'Junior I'  AND semilla % 8  = 0 THEN 35
          WHEN asesor_rec.nivel = 'Junior I'  AND semilla % 5  = 0 THEN 12
          WHEN asesor_rec.nivel = 'Junior II' AND semilla % 12 = 0 THEN 35
          WHEN asesor_rec.nivel = 'Junior II' AND semilla % 7  = 0 THEN 8
          WHEN semilla % 20 = 0 THEN 35
          WHEN semilla % 10 = 0 THEN 10
          ELSE 0
        END::SMALLINT;

        estado_pago_v := CASE
          WHEN dias_mora_val >= 30 THEN 'atraso_30'
          WHEN dias_mora_val >  0  THEN 'atraso_leve'
          ELSE 'al_dia'
        END;

        -- ficha_campo
        ficha_id := gen_random_uuid();
        INSERT INTO public.fichas_campo (
          id, user_id, score_id,
          asesor_nombre, agencia, fecha_visita,
          hora_inicio, hora_fin,
          negocio_verificado,
          antiguedad_negocio, pts_antiguedad,
          tenencia_local,     pts_tenencia,
          direccion_verificada,
          ventas_diarias_rango, pts_ventas,
          ventas_mensuales_est, gastos_fijos_mes,
          ratio_gastos,         pts_gastos,
          ingreso_consistente,
          tiene_deuda_informal, pts_deuda_informal,
          monto_deuda_informal,
          participa_pandero,    pts_pandero,
          stock_visible,  pts_stock,
          activos_hogar,  pts_activos,
          caracter_resultado,
          score_transaccional_ref,
          monto_aprobado_propuesto, plazo_propuesto_meses, cuota_estimada,
          recomendacion_asesor,
          comite_resolucion,
          comite_monto_final, comite_plazo_final,
          jefe_agencia, fecha_comite,
          estado_ficha
        ) VALUES (
          ficha_id, uid, score_id,
          asesor_rec.asesor_nombre,
          agencia_rec.nombre,
          fecha_visita,
          ('08:00'::TIME + ((semilla % 4) || ' hours')::INTERVAL),
          ('08:50'::TIME + ((semilla % 4) || ' hours')::INTERVAL),
          TRUE,
          antigned_opts[idx_ant], p_ant,
          tenencias[idx_ten],     p_ten,
          dir_negocio,
          ventas_rangos[idx_ven], p_ven,
          ROUND(ventas_montos[idx_ven] * 26, 2),
          ROUND(ventas_montos[idx_ven] * 26 *
            CASE idx_gas WHEN 1 THEN 0.85 WHEN 2 THEN 0.65 ELSE 0.38 END, 2),
          gastos_rangos[idx_gas], p_gas,
          semilla % 9 <> 0,
          deuda_opts[idx_deu],  p_deu,
          CASE idx_deu WHEN 1 THEN ROUND(monto_hip*0.6,2)
                       WHEN 2 THEN ROUND(monto_hip*0.25,2)
                       ELSE 0 END,
          pandero_opts[idx_pan], p_pan,
          stock_opts[idx_stk],   p_stk,
          activos_opts[idx_act], p_act,
          CASE WHEN semilla % 30 = 0 THEN 'alerta' ELSE 'sin_penalidad' END,
          score_trans,
          ROUND(monto_campo,2), plazo_max, cuota_est,
          recomend,
          comite_res,
          CASE WHEN comite_res IN ('aprobado','aprobado_ajuste')
               THEN ROUND(monto_final,2) ELSE NULL END,
          CASE WHEN comite_res IN ('aprobado','aprobado_ajuste')
               THEN plazo_max ELSE NULL END,
          agencia_rec.jefe_agencia,
          CASE WHEN comite_res IN ('aprobado','aprobado_ajuste')
               THEN fecha_aprob ELSE fecha_visita + 1 END,
          'completada'
        );

        -- creditos_preaprobados (solo aprobados)
        IF comite_res IN ('aprobado','aprobado_ajuste') THEN
          INSERT INTO public.creditos_preaprobados (
            user_id, ficha_id, score_id,
            segmento, tipo_producto,
            score_transaccional, score_campo, score_final,
            monto_hipotesis, monto_aprobado, plazo_meses,
            tasa_tea, cuota_mensual,
            estado,
            fecha_preaprobacion, fecha_contacto,
            fecha_visita, fecha_aprobacion, fecha_desembolso,
            dias_mora, estado_pago
          ) VALUES (
            uid, ficha_id, score_id,
            seg_final,
            CASE WHEN semilla % 2 = 0 THEN 'prospera' ELSE 'mujeres_unidas' END,
            score_trans, score_campo, score_final,
            ROUND(monto_hip,2), ROUND(monto_final,2), plazo_max,
            0.60, cuota_est,
            'desembolsado',
            fecha_preap,
            fecha_preap + 2,
            fecha_visita, fecha_aprob, fecha_desemb,
            dias_mora_val, estado_pago_v
          );
        END IF;

      END IF; -- fin elegible

    END LOOP; -- fin 5 clientes por asesor
  END LOOP;   -- fin asesores

  RAISE NOTICE 'Seed completado: % clientes insertados', cli_global;

END $$;

COMMIT;

-- ============================================================
-- VERIFICACION RAPIDA
-- ============================================================

-- Conteo por tabla:
-- SELECT 'perfiles_clientes'      AS tabla, COUNT(*) FROM public.perfiles_clientes
-- UNION ALL
-- SELECT 'cuentas',                 COUNT(*) FROM public.cuentas
-- UNION ALL
-- SELECT 'transacciones',           COUNT(*) FROM public.transacciones
-- UNION ALL
-- SELECT 'features_scoring',        COUNT(*) FROM public.features_scoring
-- UNION ALL
-- SELECT 'scores_transaccionales',  COUNT(*) FROM public.scores_transaccionales
-- UNION ALL
-- SELECT 'fichas_campo',            COUNT(*) FROM public.fichas_campo
-- UNION ALL
-- SELECT 'creditos_preaprobados',   COUNT(*) FROM public.creditos_preaprobados
-- ORDER BY tabla;

-- Distribucion de clientes por nivel de asesor y segmento:
-- SELECT an.nivel, st.segmento_preliminar,
--        COUNT(*) AS clientes,
--        ROUND(AVG(st.score_transaccional),0) AS score_prom
-- FROM public.scores_transaccionales st
-- JOIN public.perfiles_clientes pc ON st.user_id = pc.user_id
-- JOIN public.fichas_campo fc ON fc.user_id = st.user_id
-- JOIN public.asesores_negocio an ON an.nombres || ' ' || an.apellidos = fc.asesor_nombre
-- GROUP BY an.nivel, st.segmento_preliminar
-- ORDER BY an.nivel, score_prom DESC;

-- KPIs del piloto por agencia:
-- SELECT * FROM public.vw_pbi_kpis_piloto ORDER BY agencia;

-- ============================================================
-- FIN — seed_scoring_1800.sql · v2.0 · 2026
-- ============================================================

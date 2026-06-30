-- ============================================================
-- SCORING DE CRÉDITOS PREAPROBADOS — Metodología Híbrida
-- Extiende supabase_setup.sql · App Clientes · v1.0
-- Basado en: metodologia_scoring_con_campo_v2.pdf
-- Compatible con: Supabase (PostgreSQL) + Power BI
-- ============================================================
-- INSTRUCCIONES:
-- Ejecutar DESPUÉS de supabase_setup.sql
-- SQL Editor de Supabase → pegar y ejecutar con "Run"
-- ============================================================


-- ============================================================
-- BLOQUE 1: TABLAS DE SOPORTE (catálogos)
-- ============================================================

-- Tabla de perfiles de clientes (datos demográficos y negocio)
-- Extiende auth.users sin modificarla
CREATE TABLE IF NOT EXISTS public.perfiles_clientes (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  dni                 TEXT,
  nombres             TEXT,
  apellidos           TEXT,
  fecha_nacimiento    DATE,
  edad                INT DEFAULT 0,
  telefono            TEXT,
  distrito            TEXT,
  provincia           TEXT,
  departamento        TEXT,
  -- Datos del negocio
  nombre_negocio      TEXT,
  tipo_negocio        TEXT,
  direccion_negocio   TEXT,
  lat_negocio         NUMERIC(10,7),
  lng_negocio         NUMERIC(10,7),
  antiguedad_negocio_meses INT DEFAULT 0,
  tenencia_local      TEXT CHECK (tenencia_local IN ('alquilado_sin_contrato','alquilado_con_contrato','propio')),
  -- Datos SBS
  num_entidades_sbs   SMALLINT DEFAULT 0,
  calificacion_sbs    TEXT DEFAULT 'Normal',
  deuda_total_sbs     NUMERIC(12,2) DEFAULT 0,
  -- Estado en el sistema
  estado_cliente      TEXT DEFAULT 'activo'
                        CHECK (estado_cliente IN ('activo','bloqueado','inactivo')),
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

-- Trigger: calcular edad desde fecha_nacimiento (evita columna GENERATED problemática)
CREATE OR REPLACE FUNCTION public.fn_calcular_edad_perfil()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.fecha_nacimiento IS NOT NULL THEN
    NEW.edad := EXTRACT(YEAR FROM AGE(NEW.fecha_nacimiento))::INT;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_calcular_edad_perfil ON public.perfiles_clientes;
CREATE TRIGGER trg_calcular_edad_perfil
  BEFORE INSERT OR UPDATE OF fecha_nacimiento ON public.perfiles_clientes
  FOR EACH ROW EXECUTE FUNCTION public.fn_calcular_edad_perfil();

-- Historial de movimientos mensuales agregados (input principal del score)
-- Se calcula desde public.transacciones agrupando por mes
CREATE TABLE IF NOT EXISTS public.movimientos_mensuales (
  id                  SERIAL PRIMARY KEY,
  user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  cuenta_id           UUID REFERENCES public.cuentas(id),
  periodo             TEXT NOT NULL,        -- formato 'YYYY-MM'
  abonos_mes          NUMERIC(14,2) DEFAULT 0,
  cargos_mes          NUMERIC(14,2) DEFAULT 0,
  saldo_fin_mes       NUMERIC(14,2) DEFAULT 0,
  num_transacciones   INT DEFAULT 0,
  created_at          TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, cuenta_id, periodo)
);

-- Features calculados por cliente (resultado del feature engineering)
CREATE TABLE IF NOT EXISTS public.features_scoring (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Grupo A: Capacidad de Ahorro
  saldo_promedio          NUMERIC(12,2) DEFAULT 0,
  saldo_minimo            NUMERIC(12,2) DEFAULT 0,
  meses_saldo_positivo    SMALLINT DEFAULT 0,
  -- Grupo B: Regularidad de Ingresos
  ingreso_promedio        NUMERIC(12,2) DEFAULT 0,
  meses_con_abono         SMALLINT DEFAULT 0,
  volatilidad_ingresos    NUMERIC(10,4) DEFAULT 0,   -- desviación estándar
  -- Grupo C: Disciplina Financiera
  ratio_ahorro_neto       NUMERIC(8,4) DEFAULT 0,    -- (abonos-cargos)/abonos
  depositos_recurrentes   SMALLINT DEFAULT 0,
  -- Grupo D: Vínculo con la institución
  antiguedad_cuenta_meses INT DEFAULT 0,
  meses_activos           SMALLINT DEFAULT 0,
  -- Grupo E: Perfil de riesgo
  edad                    SMALLINT DEFAULT 0,
  num_entidades_sbs       SMALLINT DEFAULT 0,
  -- Derivados para reglas de monto
  cuota_max_estimada      NUMERIC(10,2) DEFAULT 0,   -- ingreso_promedio * 0.30
  monto_max_por_ingreso   NUMERIC(12,2) DEFAULT 0,   -- ingreso_promedio * 2
  -- Control
  periodos_analizados     SMALLINT DEFAULT 0,
  fecha_calculo           TIMESTAMPTZ DEFAULT now(),
  updated_at              TIMESTAMPTZ DEFAULT now()
);

-- Score transaccional calculado
CREATE TABLE IF NOT EXISTS public.scores_transaccionales (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Puntajes por grupo (800 pts total)
  pts_saldo               SMALLINT DEFAULT 0,    -- Grupo A: máx 200
  pts_regularidad         SMALLINT DEFAULT 0,    -- Grupo B: máx 160
  pts_disciplina          SMALLINT DEFAULT 0,    -- Grupo C: máx 160
  pts_vinculo             SMALLINT DEFAULT 0,    -- Grupo D: máx 160
  pts_riesgo              SMALLINT DEFAULT 0,    -- Grupo E: máx 120
  -- Score total transaccional
  score_transaccional     SMALLINT GENERATED ALWAYS AS (
    pts_saldo + pts_regularidad + pts_disciplina + pts_vinculo + pts_riesgo
  ) STORED,
  -- Segmento preliminar (antes de campo)
  segmento_preliminar     TEXT GENERATED ALWAYS AS (
    CASE
      WHEN (pts_saldo + pts_regularidad + pts_disciplina + pts_vinculo + pts_riesgo) >= 600
        THEN 'PREMIER'
      WHEN (pts_saldo + pts_regularidad + pts_disciplina + pts_vinculo + pts_riesgo) >= 440
        THEN 'ESTANDAR'
      WHEN (pts_saldo + pts_regularidad + pts_disciplina + pts_vinculo + pts_riesgo) >= 280
        THEN 'BASICO'
      ELSE 'NO_APLICA'
    END
  ) STORED,
  -- Hipótesis de monto (antes de visita de campo)
  monto_hipotesis         NUMERIC(12,2) DEFAULT 0,
  ingreso_promedio_ref    NUMERIC(12,2) DEFAULT 0,
  cuota_max_ref           NUMERIC(10,2) DEFAULT 0,
  -- Control
  es_valido               BOOLEAN DEFAULT TRUE,
  motivo_invalido         TEXT,
  fecha_calculo           TIMESTAMPTZ DEFAULT now(),
  updated_at              TIMESTAMPTZ DEFAULT now()
);

-- Requerido para ON CONFLICT (user_id) en calcular_score_transaccional
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'scores_transaccionales_user_id_key'
  ) THEN
    ALTER TABLE public.scores_transaccionales
      ADD CONSTRAINT scores_transaccionales_user_id_key UNIQUE (user_id);
  END IF;
END $$;

-- ============================================================
-- BLOQUE 2: TABLA PRINCIPAL — FICHA DE VISITA DE CAMPO
-- ============================================================

CREATE TABLE IF NOT EXISTS public.fichas_campo (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES auth.users(id),  -- cliente evaluado
  score_id              UUID REFERENCES public.scores_transaccionales(id),
  -- Asesor que realiza la visita
  asesor_nombre         TEXT NOT NULL,
  agencia               TEXT NOT NULL,
  fecha_visita          DATE NOT NULL,
  hora_inicio           TIME,
  hora_fin              TIME,

  -- F1: Verificación del negocio (máx 60 pts)
  negocio_verificado    BOOLEAN NOT NULL DEFAULT FALSE,
  motivo_no_verificado  TEXT,
  antiguedad_negocio    TEXT CHECK (antiguedad_negocio IN ('menos_1_anio','1_a_3_anios','mas_3_anios')),
  pts_antiguedad        SMALLINT DEFAULT 0,    -- 0, 20 o 40
  tenencia_local        TEXT CHECK (tenencia_local IN ('alquilado_sin_contrato','alquilado_con_contrato','propio')),
  pts_tenencia          SMALLINT DEFAULT 0,    -- 0, 10 o 20
  direccion_verificada  TEXT,
  pts_f1                SMALLINT GENERATED ALWAYS AS (pts_antiguedad + pts_tenencia) STORED,

  -- F2: Capacidad de pago real (máx 60 pts)
  ventas_diarias_rango  TEXT CHECK (ventas_diarias_rango IN ('menos_50','50_a_150','151_a_300','mas_300')),
  pts_ventas            SMALLINT DEFAULT 0,    -- 0, 15, 30 o 45
  ventas_mensuales_est  NUMERIC(10,2),
  gastos_fijos_mes      NUMERIC(10,2),
  ratio_gastos          TEXT CHECK (ratio_gastos IN ('mas_80pct','50_a_80pct','menos_50pct')),
  pts_gastos            SMALLINT DEFAULT 0,    -- 0, 5 o 15
  ingreso_consistente   BOOLEAN DEFAULT TRUE,
  obs_inconsistencia    TEXT,
  pts_f2                SMALLINT GENERATED ALWAYS AS (pts_ventas + pts_gastos) STORED,

  -- F3: Deuda informal (máx 40 pts, puede ser negativo)
  tiene_deuda_informal  TEXT CHECK (tiene_deuda_informal IN ('si_significativa','si_menor','no')),
  pts_deuda_informal    SMALLINT DEFAULT 0,    -- -50, -20 o +20
  monto_deuda_informal  NUMERIC(10,2) DEFAULT 0,
  detalle_deuda         TEXT,
  participa_pandero     TEXT CHECK (participa_pandero IN ('si_mayor_cuota','si_menor_cuota','no')),
  pts_pandero           SMALLINT DEFAULT 0,    -- -20, 0 o +20
  aporte_pandero_mes    NUMERIC(8,2) DEFAULT 0,
  pts_f3                SMALLINT GENERATED ALWAYS AS (pts_deuda_informal + pts_pandero) STORED,

  -- F4: Activos y respaldo (máx 40 pts)
  stock_visible         TEXT CHECK (stock_visible IN ('escaso','moderado','abundante')),
  pts_stock             SMALLINT DEFAULT 0,    -- 0, 10 o 20
  activos_hogar         TEXT CHECK (activos_hogar IN ('ninguno','al_menos_uno')),
  pts_activos           SMALLINT DEFAULT 0,    -- 0 o 20
  descripcion_activos   TEXT,
  pts_f4                SMALLINT GENERATED ALWAYS AS (pts_stock + pts_activos) STORED,

  -- F5: Carácter del cliente (veto / alerta, sin puntaje positivo)
  caracter_resultado    TEXT NOT NULL DEFAULT 'sin_penalidad'
                          CHECK (caracter_resultado IN ('sin_penalidad','alerta','veto')),
  obs_caracter          TEXT,

  -- Score de campo total (calculado)
  score_campo           SMALLINT GENERATED ALWAYS AS (
    pts_antiguedad + pts_tenencia +
    pts_ventas + pts_gastos +
    pts_deuda_informal + pts_pandero +
    pts_stock + pts_activos
  ) STORED,

  -- Score final consolidado
  score_transaccional_ref SMALLINT,   -- copia del score_transaccional al momento de la visita
  score_final           SMALLINT GENERATED ALWAYS AS (
    score_transaccional_ref + (
      pts_antiguedad + pts_tenencia +
      pts_ventas + pts_gastos +
      pts_deuda_informal + pts_pandero +
      pts_stock + pts_activos
    )
  ) STORED,

  -- Segmento resultante (post campo)
  segmento_resultante   TEXT GENERATED ALWAYS AS (
    CASE
      WHEN negocio_verificado = FALSE THEN 'DESCALIFICADO'
      WHEN caracter_resultado = 'veto' THEN 'DESCALIFICADO'
      WHEN (score_transaccional_ref + pts_antiguedad + pts_tenencia +
            pts_ventas + pts_gastos + pts_deuda_informal + pts_pandero +
            pts_stock + pts_activos) >= 750 THEN 'PREMIER'
      WHEN (score_transaccional_ref + pts_antiguedad + pts_tenencia +
            pts_ventas + pts_gastos + pts_deuda_informal + pts_pandero +
            pts_stock + pts_activos) >= 550 THEN 'ESTANDAR'
      WHEN (score_transaccional_ref + pts_antiguedad + pts_tenencia +
            pts_ventas + pts_gastos + pts_deuda_informal + pts_pandero +
            pts_stock + pts_activos) >= 350 THEN 'BASICO'
      ELSE 'NO_APLICA'
    END
  ) STORED,

  -- Propuesta del asesor
  monto_aprobado_propuesto  NUMERIC(12,2),
  plazo_propuesto_meses     SMALLINT,
  cuota_estimada            NUMERIC(10,2),
  recomendacion_asesor      TEXT CHECK (recomendacion_asesor IN (
                              'aprobar','aprobar_monto_reducido','elevar_comite','rechazar')),
  obs_finales               TEXT,

  -- Resolución del comité simplificado
  comite_resolucion     TEXT CHECK (comite_resolucion IN ('aprobado','aprobado_ajuste','rechazado')),
  comite_monto_final    NUMERIC(12,2),
  comite_plazo_final    SMALLINT,
  comite_motivo_rechazo TEXT,
  jefe_agencia          TEXT,
  fecha_comite          DATE,

  -- Estado general de la ficha
  estado_ficha          TEXT DEFAULT 'en_proceso'
                          CHECK (estado_ficha IN ('en_proceso','completada','cancelada')),
  created_at            TIMESTAMPTZ DEFAULT now(),
  updated_at            TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- BLOQUE 3: TABLA DE CRÉDITOS PREAPROBADOS (resultado final)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.creditos_preaprobados (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES auth.users(id),
  ficha_id              UUID REFERENCES public.fichas_campo(id),
  score_id              UUID REFERENCES public.scores_transaccionales(id),
  -- Datos del crédito aprobado
  segmento              TEXT NOT NULL,
  score_transaccional   SMALLINT NOT NULL,
  score_campo           SMALLINT NOT NULL,
  score_final           SMALLINT NOT NULL,
  monto_hipotesis       NUMERIC(12,2),
  monto_aprobado        NUMERIC(12,2) NOT NULL,
  plazo_meses           SMALLINT NOT NULL,
  tasa_tea              NUMERIC(6,4) DEFAULT 0.60,  -- TEA 60% referencial
  cuota_mensual         NUMERIC(10,2),
  -- Seguimiento del proceso
  estado                TEXT DEFAULT 'preaprobado'
                          CHECK (estado IN (
                            'preaprobado','contactado','visita_agendada',
                            'visita_realizada','en_comite','aprobado',
                            'rechazado','desembolsado','cancelado')),
  fecha_preaprobacion   DATE DEFAULT CURRENT_DATE,
  fecha_contacto        DATE,
  fecha_visita          DATE,
  fecha_aprobacion      DATE,
  fecha_desembolso      DATE,
  -- Mora (seguimiento post-desembolso)
  dias_mora             SMALLINT DEFAULT 0,
  estado_pago           TEXT DEFAULT 'al_dia'
                          CHECK (estado_pago IN ('al_dia','atraso_leve','atraso_30','atraso_90','castigado')),
  -- Para análisis de modelo
  variacion_monto_pct   NUMERIC(6,4) GENERATED ALWAYS AS (
    CASE WHEN monto_hipotesis > 0
      THEN (monto_aprobado - monto_hipotesis) / monto_hipotesis
      ELSE NULL
    END
  ) STORED,
  created_at            TIMESTAMPTZ DEFAULT now(),
  updated_at            TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- BLOQUE 4: FUNCIÓN — CALCULA FEATURES DESDE TRANSACCIONES
-- ============================================================

CREATE OR REPLACE FUNCTION public.calcular_features_scoring(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_saldo_promedio       NUMERIC;
  v_saldo_minimo         NUMERIC;
  v_meses_saldo_positivo SMALLINT;
  v_ingreso_promedio     NUMERIC;
  v_meses_con_abono      SMALLINT;
  v_volatilidad          NUMERIC;
  v_ratio_ahorro         NUMERIC;
  v_meses_activos        SMALLINT;
  v_antiguedad_meses     INT;
  v_periodos             SMALLINT;
BEGIN
  -- Agregar movimientos mensuales desde transacciones existentes
  INSERT INTO public.movimientos_mensuales (user_id, cuenta_id, periodo, abonos_mes, cargos_mes, saldo_fin_mes, num_transacciones)
  SELECT
    t.user_id,
    t.cuenta_id,
    TO_CHAR(t.fecha, 'YYYY-MM') AS periodo,
    SUM(CASE WHEN t.tipo = 'credito' THEN t.monto ELSE 0 END) AS abonos_mes,
    SUM(CASE WHEN t.tipo = 'debito'  THEN t.monto ELSE 0 END) AS cargos_mes,
    -- saldo final del mes: aproximado desde la última transacción del mes
    (SELECT c.saldo FROM public.cuentas c WHERE c.id = t.cuenta_id LIMIT 1) AS saldo_fin_mes,
    COUNT(*) AS num_transacciones
  FROM public.transacciones t
  WHERE t.user_id = p_user_id
    AND t.fecha >= NOW() - INTERVAL '12 months'
  GROUP BY t.user_id, t.cuenta_id, TO_CHAR(t.fecha, 'YYYY-MM')
  ON CONFLICT (user_id, cuenta_id, periodo) DO UPDATE SET
    abonos_mes       = EXCLUDED.abonos_mes,
    cargos_mes       = EXCLUDED.cargos_mes,
    saldo_fin_mes    = EXCLUDED.saldo_fin_mes,
    num_transacciones = EXCLUDED.num_transacciones;

  -- Calcular features agregados
  SELECT
    AVG(saldo_fin_mes),
    MIN(saldo_fin_mes),
    COUNT(*) FILTER (WHERE saldo_fin_mes > 0),
    AVG(abonos_mes),
    COUNT(*) FILTER (WHERE abonos_mes > 0),
    STDDEV(abonos_mes),
    AVG(CASE WHEN abonos_mes > 0
             THEN (abonos_mes - cargos_mes) / abonos_mes
             ELSE 0 END),
    COUNT(*) FILTER (WHERE num_transacciones > 0),
    COUNT(DISTINCT periodo)
  INTO
    v_saldo_promedio, v_saldo_minimo, v_meses_saldo_positivo,
    v_ingreso_promedio, v_meses_con_abono, v_volatilidad,
    v_ratio_ahorro, v_meses_activos, v_periodos
  FROM public.movimientos_mensuales
  WHERE user_id = p_user_id;

  -- Antigüedad de la cuenta más antigua del usuario
  SELECT EXTRACT(MONTH FROM AGE(NOW(), MIN(created_at)))::INT
  INTO v_antiguedad_meses
  FROM public.cuentas
  WHERE user_id = p_user_id;

  -- Insertar o actualizar features
  INSERT INTO public.features_scoring (
    user_id, saldo_promedio, saldo_minimo, meses_saldo_positivo,
    ingreso_promedio, meses_con_abono, volatilidad_ingresos,
    ratio_ahorro_neto, meses_activos, antiguedad_cuenta_meses,
    cuota_max_estimada, monto_max_por_ingreso, periodos_analizados
  ) VALUES (
    p_user_id,
    COALESCE(v_saldo_promedio, 0),
    COALESCE(v_saldo_minimo, 0),
    COALESCE(v_meses_saldo_positivo, 0),
    COALESCE(v_ingreso_promedio, 0),
    COALESCE(v_meses_con_abono, 0),
    COALESCE(v_volatilidad, 0),
    COALESCE(v_ratio_ahorro, 0),
    COALESCE(v_meses_activos, 0),
    COALESCE(v_antiguedad_meses, 0),
    COALESCE(v_ingreso_promedio * 0.30, 0),
    COALESCE(v_ingreso_promedio * 2, 0),
    COALESCE(v_periodos, 0)
  )
  ON CONFLICT (user_id) DO UPDATE SET
    saldo_promedio          = EXCLUDED.saldo_promedio,
    saldo_minimo            = EXCLUDED.saldo_minimo,
    meses_saldo_positivo    = EXCLUDED.meses_saldo_positivo,
    ingreso_promedio        = EXCLUDED.ingreso_promedio,
    meses_con_abono         = EXCLUDED.meses_con_abono,
    volatilidad_ingresos    = EXCLUDED.volatilidad_ingresos,
    ratio_ahorro_neto       = EXCLUDED.ratio_ahorro_neto,
    meses_activos           = EXCLUDED.meses_activos,
    antiguedad_cuenta_meses = EXCLUDED.antiguedad_cuenta_meses,
    cuota_max_estimada      = EXCLUDED.cuota_max_estimada,
    monto_max_por_ingreso   = EXCLUDED.monto_max_por_ingreso,
    periodos_analizados     = EXCLUDED.periodos_analizados,
    updated_at              = now();
END;
$$;

-- ============================================================
-- BLOQUE 5: FUNCIÓN — CALCULA SCORE TRANSACCIONAL
-- ============================================================

CREATE OR REPLACE FUNCTION public.calcular_score_transaccional(p_user_id UUID)
RETURNS TABLE (
  score_transaccional INT,
  segmento_preliminar TEXT,
  monto_hipotesis     NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
  f               public.features_scoring%ROWTYPE;
  p               public.perfiles_clientes%ROWTYPE;
  v_pts_saldo     SMALLINT;
  v_pts_regular   SMALLINT;
  v_pts_discipl   SMALLINT;
  v_pts_vinculo   SMALLINT;
  v_pts_riesgo    SMALLINT;
  v_score_total   SMALLINT;
  v_segmento      TEXT;
  v_monto_hip     NUMERIC;
BEGIN
  -- Cargar features
  SELECT * INTO f FROM public.features_scoring WHERE user_id = p_user_id;
  SELECT * INTO p FROM public.perfiles_clientes WHERE user_id = p_user_id;

  -- Grupo A: Saldo promedio (máx 200 pts)
  v_pts_saldo := CASE
    WHEN f.saldo_promedio >= 5000 THEN 200
    WHEN f.saldo_promedio >= 2000 THEN 160
    WHEN f.saldo_promedio >= 1000 THEN 120
    WHEN f.saldo_promedio >= 500  THEN 80
    WHEN f.saldo_promedio >= 200  THEN 40
    ELSE 0
  END;

  -- Grupo B: Meses con abono (máx 160 pts)
  v_pts_regular := CASE
    WHEN f.meses_con_abono >= 11 THEN 160
    WHEN f.meses_con_abono >= 9  THEN 128
    WHEN f.meses_con_abono >= 7  THEN 96
    WHEN f.meses_con_abono >= 5  THEN 64
    ELSE 24
  END;

  -- Grupo C: Ratio ahorro neto (máx 160 pts)
  v_pts_discipl := CASE
    WHEN f.ratio_ahorro_neto >= 0.30 THEN 160
    WHEN f.ratio_ahorro_neto >= 0.20 THEN 120
    WHEN f.ratio_ahorro_neto >= 0.10 THEN 80
    WHEN f.ratio_ahorro_neto >= 0.01 THEN 40
    ELSE 0
  END;

  -- Grupo D: Antigüedad de cuenta (máx 160 pts)
  v_pts_vinculo := CASE
    WHEN f.antiguedad_cuenta_meses >= 36 THEN 160
    WHEN f.antiguedad_cuenta_meses >= 24 THEN 120
    WHEN f.antiguedad_cuenta_meses >= 12 THEN 80
    WHEN f.antiguedad_cuenta_meses >= 6  THEN 40
    ELSE 0
  END;

  -- Grupo E: Entidades SBS (máx 120 pts)
  v_pts_riesgo := CASE
    WHEN COALESCE(p.num_entidades_sbs, 0) = 0 THEN 120
    WHEN COALESCE(p.num_entidades_sbs, 0) = 1 THEN 90
    WHEN COALESCE(p.num_entidades_sbs, 0) <= 3 THEN 48
    ELSE 12
  END;

  v_score_total := v_pts_saldo + v_pts_regular + v_pts_discipl + v_pts_vinculo + v_pts_riesgo;

  -- Segmento preliminar (umbral ≈75% del score final)
  v_segmento := CASE
    WHEN v_score_total >= 600 THEN 'PREMIER'
    WHEN v_score_total >= 440 THEN 'ESTANDAR'
    WHEN v_score_total >= 280 THEN 'BASICO'
    ELSE 'NO_APLICA'
  END;

  -- Hipótesis de monto: mínimo entre techo del segmento y 2x ingreso promedio
  v_monto_hip := CASE
    WHEN v_segmento = 'PREMIER'  THEN LEAST(f.monto_max_por_ingreso, 5000)
    WHEN v_segmento = 'ESTANDAR' THEN LEAST(f.monto_max_por_ingreso, 2500)
    WHEN v_segmento = 'BASICO'   THEN LEAST(f.monto_max_por_ingreso, 1000)
    ELSE 0
  END;

  -- Guardar o actualizar en scores_transaccionales
  INSERT INTO public.scores_transaccionales (
    user_id, pts_saldo, pts_regularidad, pts_disciplina,
    pts_vinculo, pts_riesgo, monto_hipotesis,
    ingreso_promedio_ref, cuota_max_ref
  ) VALUES (
    p_user_id, v_pts_saldo, v_pts_regular, v_pts_discipl,
    v_pts_vinculo, v_pts_riesgo, v_monto_hip,
    f.ingreso_promedio, f.cuota_max_estimada
  )
  ON CONFLICT (user_id) DO UPDATE SET
    pts_saldo           = EXCLUDED.pts_saldo,
    pts_regularidad     = EXCLUDED.pts_regularidad,
    pts_disciplina      = EXCLUDED.pts_disciplina,
    pts_vinculo         = EXCLUDED.pts_vinculo,
    pts_riesgo          = EXCLUDED.pts_riesgo,
    monto_hipotesis     = EXCLUDED.monto_hipotesis,
    ingreso_promedio_ref= EXCLUDED.ingreso_promedio_ref,
    cuota_max_ref       = EXCLUDED.cuota_max_ref,
    updated_at          = now();

  RETURN QUERY SELECT v_score_total::INT, v_segmento, v_monto_hip;
END;
$$;

-- ============================================================
-- BLOQUE 6: VISTAS POWER BI
-- ============================================================

-- Vista 1: Universo elegible con score transaccional
CREATE OR REPLACE VIEW public.vw_pbi_universo_scoring AS
SELECT
  st.user_id,
  pc.nombres || ' ' || pc.apellidos   AS nombre_cliente,
  pc.distrito,
  pc.provincia,
  pc.departamento,
  pc.tipo_negocio,
  pc.antiguedad_negocio_meses,
  pc.num_entidades_sbs,
  -- Features clave
  fs.saldo_promedio,
  fs.ingreso_promedio,
  fs.meses_con_abono,
  fs.ratio_ahorro_neto,
  fs.antiguedad_cuenta_meses,
  fs.meses_activos,
  fs.periodos_analizados,
  -- Score transaccional por grupos
  st.pts_saldo,
  st.pts_regularidad,
  st.pts_disciplina,
  st.pts_vinculo,
  st.pts_riesgo,
  st.score_transaccional,
  st.segmento_preliminar,
  st.monto_hipotesis,
  st.ingreso_promedio_ref,
  st.cuota_max_ref,
  st.fecha_calculo
FROM public.scores_transaccionales st
JOIN public.features_scoring    fs ON st.user_id = fs.user_id
LEFT JOIN public.perfiles_clientes pc ON st.user_id = pc.user_id
WHERE st.es_valido = TRUE
  AND st.segmento_preliminar <> 'NO_APLICA';

-- Vista 2: Fichas de campo completas con score final
CREATE OR REPLACE VIEW public.vw_pbi_fichas_campo AS
SELECT
  fc.id                         AS id_ficha,
  fc.fecha_visita,
  DATE_TRUNC('month', fc.fecha_visita::TIMESTAMPTZ) AS mes_visita,
  EXTRACT(YEAR  FROM fc.fecha_visita)::INT AS anio,
  EXTRACT(MONTH FROM fc.fecha_visita)::INT AS numero_mes,
  fc.asesor_nombre,
  fc.agencia,
  -- Cliente
  pc.nombres || ' ' || pc.apellidos AS nombre_cliente,
  pc.distrito,
  pc.tipo_negocio,
  -- Scores por componente
  fc.score_transaccional_ref,
  fc.pts_f1,
  fc.pts_f2,
  fc.pts_f3,
  fc.pts_f4,
  fc.score_campo,
  fc.score_final,
  fc.segmento_resultante,
  -- Detalle de campo
  fc.negocio_verificado,
  fc.antiguedad_negocio,
  fc.tenencia_local,
  fc.ventas_diarias_rango,
  fc.ventas_mensuales_est,
  fc.gastos_fijos_mes,
  CASE WHEN fc.ventas_mensuales_est > 0
    THEN ROUND(fc.gastos_fijos_mes / fc.ventas_mensuales_est * 100, 1)
    ELSE NULL
  END                           AS pct_gastos_sobre_ventas,
  fc.tiene_deuda_informal,
  fc.monto_deuda_informal,
  fc.participa_pandero,
  fc.stock_visible,
  fc.activos_hogar,
  fc.caracter_resultado,
  -- Montos y propuesta
  fc.monto_aprobado_propuesto,
  fc.plazo_propuesto_meses,
  fc.cuota_estimada,
  fc.recomendacion_asesor,
  -- Resolución del comité
  fc.comite_resolucion,
  fc.comite_monto_final,
  fc.comite_plazo_final,
  fc.estado_ficha
FROM public.fichas_campo fc
LEFT JOIN public.perfiles_clientes pc ON fc.user_id = pc.user_id;

-- Vista 3: Embudo de conversión (KPIs de campaña)
CREATE OR REPLACE VIEW public.vw_pbi_embudo_campania AS
SELECT
  agencia,
  asesor_nombre,
  DATE_TRUNC('month', fecha_visita::TIMESTAMPTZ) AS mes,
  COUNT(*)                                            AS total_visitas,
  COUNT(*) FILTER (WHERE negocio_verificado = TRUE)   AS negocios_verificados,
  COUNT(*) FILTER (WHERE caracter_resultado = 'veto') AS vetos_caracter,
  COUNT(*) FILTER (WHERE segmento_resultante = 'PREMIER')   AS premier,
  COUNT(*) FILTER (WHERE segmento_resultante = 'ESTANDAR')  AS estandar,
  COUNT(*) FILTER (WHERE segmento_resultante = 'BASICO')    AS basico,
  COUNT(*) FILTER (WHERE segmento_resultante = 'NO_APLICA') AS no_aplica,
  COUNT(*) FILTER (WHERE segmento_resultante = 'DESCALIFICADO') AS descalificados,
  COUNT(*) FILTER (WHERE recomendacion_asesor = 'aprobar') AS recomendados_aprobar,
  COUNT(*) FILTER (WHERE comite_resolucion = 'aprobado' OR comite_resolucion = 'aprobado_ajuste') AS aprobados_comite,
  SUM(comite_monto_final) FILTER (WHERE comite_resolucion IN ('aprobado','aprobado_ajuste')) AS monto_total_aprobado,
  AVG(score_final) FILTER (WHERE segmento_resultante <> 'DESCALIFICADO') AS score_final_promedio,
  -- Tasa de aprobación post-visita
  ROUND(
    COUNT(*) FILTER (WHERE comite_resolucion IN ('aprobado','aprobado_ajuste'))::NUMERIC /
    NULLIF(COUNT(*) FILTER (WHERE negocio_verificado = TRUE), 0) * 100, 1
  ) AS tasa_aprobacion_pct,
  -- Variación monto campo vs hipótesis (promedio)
  AVG(
    CASE WHEN st.monto_hipotesis > 0
      THEN (fc.comite_monto_final - st.monto_hipotesis) / st.monto_hipotesis * 100
      ELSE NULL END
  ) AS variacion_monto_campo_vs_score_pct
FROM public.fichas_campo fc
LEFT JOIN public.scores_transaccionales st ON fc.score_id = st.id
GROUP BY agencia, asesor_nombre, DATE_TRUNC('month', fecha_visita::TIMESTAMPTZ);

-- Vista 4: Seguimiento crediticio y mora (KPIs de calidad)
CREATE OR REPLACE VIEW public.vw_pbi_calidad_cartera AS
SELECT
  cp.id,
  cp.segmento,
  cp.score_transaccional,
  cp.score_campo,
  cp.score_final,
  -- Rangos de score para análisis de distribución
  CASE
    WHEN cp.score_final >= 900 THEN '900-1000'
    WHEN cp.score_final >= 800 THEN '800-899'
    WHEN cp.score_final >= 700 THEN '700-799'
    WHEN cp.score_final >= 600 THEN '600-699'
    WHEN cp.score_final >= 500 THEN '500-599'
    WHEN cp.score_final >= 400 THEN '400-499'
    ELSE '300-399'
  END                         AS rango_score,
  cp.monto_hipotesis,
  cp.monto_aprobado,
  cp.variacion_monto_pct,
  cp.plazo_meses,
  cp.tasa_tea,
  cp.cuota_mensual,
  -- Fechas del proceso
  cp.fecha_preaprobacion,
  cp.fecha_contacto,
  cp.fecha_visita,
  cp.fecha_aprobacion,
  cp.fecha_desembolso,
  -- Días entre etapas (para medir eficiencia operativa)
  (cp.fecha_desembolso - cp.fecha_preaprobacion) AS dias_preaprobacion_a_desembolso,
  (cp.fecha_aprobacion - cp.fecha_visita)        AS dias_visita_a_aprobacion,
  -- Estado y mora
  cp.estado,
  cp.dias_mora,
  cp.estado_pago,
  -- Clasificación de mora (categorías SBS)
  CASE
    WHEN cp.dias_mora = 0          THEN 'Normal'
    WHEN cp.dias_mora <= 8         THEN 'CPP'
    WHEN cp.dias_mora <= 30        THEN 'Deficiente'
    WHEN cp.dias_mora <= 60        THEN 'Dudoso'
    ELSE                                'Pérdida'
  END                         AS categoria_sbs,
  -- Datos del cliente
  pc.distrito,
  pc.tipo_negocio,
  fc.agencia,
  fc.asesor_nombre,
  fc.tiene_deuda_informal,
  fc.participa_pandero,
  fc.negocio_verificado
FROM public.creditos_preaprobados cp
LEFT JOIN public.fichas_campo      fc ON cp.ficha_id = fc.id
LEFT JOIN public.perfiles_clientes pc ON cp.user_id = pc.user_id;

-- Vista 5: Scorecard de KPIs del piloto (resumen ejecutivo para Power BI)
CREATE OR REPLACE VIEW public.vw_pbi_kpis_piloto AS
WITH base AS (
  SELECT
    fc.agencia,
    DATE_TRUNC('month', fc.fecha_visita::TIMESTAMPTZ) AS mes,
    COUNT(DISTINCT fc.id)  AS visitas_totales,
    COUNT(DISTINCT cp.id)  AS desembolsos,
    SUM(cp.monto_aprobado) AS monto_desembolsado,
    COUNT(DISTINCT cp.id) FILTER (WHERE cp.dias_mora > 30)  AS creditos_mora_30,
    COUNT(DISTINCT cp.id) FILTER (WHERE cp.dias_mora > 90)  AS creditos_mora_90,
    AVG(fc.score_final)    AS score_final_promedio
  FROM public.fichas_campo fc
  LEFT JOIN public.creditos_preaprobados cp ON fc.id = cp.ficha_id
  GROUP BY fc.agencia, DATE_TRUNC('month', fc.fecha_visita::TIMESTAMPTZ)
)
SELECT
  agencia,
  mes,
  visitas_totales,
  desembolsos,
  monto_desembolsado,
  ROUND(creditos_mora_30::NUMERIC / NULLIF(desembolsos,0) * 100, 2) AS mora_30_pct,
  ROUND(creditos_mora_90::NUMERIC / NULLIF(desembolsos,0) * 100, 2) AS mora_90_pct,
  ROUND(desembolsos::NUMERIC / NULLIF(visitas_totales,0) * 100, 2)  AS tasa_conversion_pct,
  ROUND(score_final_promedio, 0)                                      AS score_promedio,
  CASE
    WHEN ROUND(creditos_mora_30::NUMERIC / NULLIF(desembolsos,0) * 100, 2) <= 5
      THEN 'OK'
    WHEN ROUND(creditos_mora_30::NUMERIC / NULLIF(desembolsos,0) * 100, 2) <= 8
      THEN 'ALERTA'
    ELSE 'CRITICO'
  END AS semaforo_mora_30,
  CASE
    WHEN ROUND(desembolsos::NUMERIC / NULLIF(visitas_totales,0) * 100, 2) >= 20
      THEN 'OK'
    WHEN ROUND(desembolsos::NUMERIC / NULLIF(visitas_totales,0) * 100, 2) >= 10
      THEN 'ALERTA'
    ELSE 'CRITICO'
  END AS semaforo_conversion
FROM base;

-- ============================================================
-- BLOQUE 7: RLS (Row Level Security)
-- ============================================================

ALTER TABLE public.perfiles_clientes      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimientos_mensuales  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.features_scoring       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scores_transaccionales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fichas_campo           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.creditos_preaprobados  ENABLE ROW LEVEL SECURITY;

-- Clientes: solo ven sus propios datos
DROP POLICY IF EXISTS "Cliente ve su perfil" ON public.perfiles_clientes;
CREATE POLICY "Cliente ve su perfil"
  ON public.perfiles_clientes FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Cliente ve sus movimientos" ON public.movimientos_mensuales;
CREATE POLICY "Cliente ve sus movimientos"
  ON public.movimientos_mensuales FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Cliente ve sus features" ON public.features_scoring;
CREATE POLICY "Cliente ve sus features"
  ON public.features_scoring FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Cliente ve su score" ON public.scores_transaccionales;
CREATE POLICY "Cliente ve su score"
  ON public.scores_transaccionales FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Cliente ve su crédito preaprobado" ON public.creditos_preaprobados;
CREATE POLICY "Cliente ve su crédito preaprobado"
  ON public.creditos_preaprobados FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Cliente ve su ficha de campo" ON public.fichas_campo;
CREATE POLICY "Cliente ve su ficha de campo"
  ON public.fichas_campo FOR SELECT
  USING (auth.uid() = user_id);

-- ============================================================
-- BLOQUE 8: DATOS DE EJEMPLO (descomenta para pruebas)
-- ============================================================

/*
-- Ejemplo: calcular features y score para un usuario existente
-- Reemplaza 'TU-UUID-AQUI' con un UUID de auth.users

SELECT public.calcular_features_scoring('TU-UUID-AQUI');
SELECT * FROM public.calcular_score_transaccional('TU-UUID-AQUI');

-- Ver resultado
SELECT
  score_transaccional,
  segmento_preliminar,
  monto_hipotesis
FROM public.scores_transaccionales
WHERE user_id = 'TU-UUID-AQUI';
*/

-- Migración: si edad existía como columna GENERATED, reemplazarla
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'perfiles_clientes'
      AND a.attname = 'edad'
      AND a.attgenerated <> ''
  ) THEN
    ALTER TABLE public.perfiles_clientes DROP COLUMN edad;
    ALTER TABLE public.perfiles_clientes ADD COLUMN edad INT DEFAULT 0;
  ELSE
    ALTER TABLE public.perfiles_clientes
      ADD COLUMN IF NOT EXISTS edad INT DEFAULT 0;
  END IF;
END $$;

-- ============================================================
-- FIN DEL SCRIPT
-- scoring_preaprobados.sql — v1.1 corregido — 2026
-- ============================================================

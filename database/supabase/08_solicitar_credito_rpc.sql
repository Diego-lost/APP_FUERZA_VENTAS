-- RPC: solicitar aumento de crédito por producto (Mujeres Unidas / Prospera)
-- Ejecutar TODO este archivo en Supabase SQL Editor (incluye paso 09).
-- Orden: después de 05_login_rpc.sql

-- ── Paso A: columna tipo_producto (antes era 09) ──────────
ALTER TABLE public.creditos_preaprobados
  ADD COLUMN IF NOT EXISTS tipo_producto TEXT DEFAULT 'prospera';

ALTER TABLE public.creditos_preaprobados
  DROP CONSTRAINT IF EXISTS creditos_preaprobados_tipo_producto_check;

ALTER TABLE public.creditos_preaprobados
  ADD CONSTRAINT creditos_preaprobados_tipo_producto_check
  CHECK (tipo_producto IN ('prospera', 'mujeres_unidas', 'construyendo_suenos'));

UPDATE public.creditos_preaprobados cp
SET tipo_producto = CASE
  WHEN (RIGHT(regexp_replace(pc.dni, '[^0-9]', '', 'g'), 1)::INT % 2) = 0
    THEN 'prospera'
  ELSE 'mujeres_unidas'
END
FROM public.perfiles_clientes pc
WHERE pc.user_id = cp.user_id
  AND cp.tipo_producto IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_creditos_user_producto_activo
  ON public.creditos_preaprobados (user_id, tipo_producto)
  WHERE estado IN ('desembolsado', 'aprobado', 'preaprobado');

-- ── Paso A2: tabla solicitudes_prestamo (viene del 01, a veces no se ejecutó) ──
CREATE TABLE IF NOT EXISTS public.solicitudes_prestamo (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  monto          NUMERIC(12,2) NOT NULL,
  plazo_meses    INTEGER NOT NULL,
  tasa_anual     NUMERIC(5,2) NOT NULL,
  cuota_mensual  NUMERIC(10,2) NOT NULL,
  proposito      TEXT,
  estado         TEXT NOT NULL DEFAULT 'pendiente',
  created_at     TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.solicitudes_prestamo ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Usuario ve sus propias solicitudes" ON public.solicitudes_prestamo;
CREATE POLICY "Usuario ve sus propias solicitudes"
  ON public.solicitudes_prestamo FOR ALL
  USING (auth.uid() = user_id);

-- ── Paso B: RPC ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.solicitar_aumento_credito(
  p_producto_id TEXT,
  p_monto_adicional NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_credito RECORD;
  v_base RECORD;
  v_techo NUMERIC;
  v_nuevo_monto NUMERIC;
  v_incremento NUMERIC;
  v_pct_auto NUMERIC;
  v_min_auto NUMERIC;
  v_tem NUMERIC;
  v_factor NUMERIC;
  v_nueva_cuota NUMERIC;
  v_monto_inicial NUMERIC;
  v_plazo SMALLINT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No autenticado';
  END IF;

  IF p_producto_id NOT IN ('mujeres_unidas', 'prospera') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'producto_invalido');
  END IF;

  -- Reglas por producto
  IF p_producto_id = 'mujeres_unidas' THEN
    v_pct_auto := 0.10;
    v_min_auto := 300;
  ELSE
    v_pct_auto := 0.20;
    v_min_auto := 500;
  END IF;

  SELECT *
  INTO v_credito
  FROM public.creditos_preaprobados
  WHERE user_id = v_user_id
    AND tipo_producto = p_producto_id
    AND estado IN ('desembolsado', 'aprobado', 'preaprobado')
  ORDER BY created_at DESC
  LIMIT 1;

  -- Crear crédito del producto si aún no existe (a partir de otro crédito del cliente)
  IF NOT FOUND THEN
    SELECT *
    INTO v_base
    FROM public.creditos_preaprobados
    WHERE user_id = v_user_id
      AND estado IN ('desembolsado', 'aprobado', 'preaprobado')
    ORDER BY created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'error', 'no_credit');
    END IF;

    v_monto_inicial := CASE p_producto_id
      WHEN 'mujeres_unidas' THEN CASE v_base.segmento
        WHEN 'PREMIER'  THEN 3500
        WHEN 'ESTANDAR' THEN 2000
        ELSE 1000
      END
      ELSE CASE v_base.segmento
        WHEN 'PREMIER'  THEN 5000
        WHEN 'ESTANDAR' THEN 3500
        ELSE 1500
      END
    END;

    v_plazo := CASE v_base.segmento
      WHEN 'PREMIER'  THEN 12
      WHEN 'ESTANDAR' THEN 6
      ELSE 3
    END;

    v_tem := POWER(1.60, 1.0 / 12) - 1;
    IF v_plazo > 0 AND ABS(POWER(1 + v_tem, v_plazo) - 1) > 0.000001 THEN
      v_factor := v_tem * POWER(1 + v_tem, v_plazo) / (POWER(1 + v_tem, v_plazo) - 1);
    ELSE
      v_factor := 0;
    END IF;
    v_nueva_cuota := ROUND(v_monto_inicial * v_factor, 2);

    INSERT INTO public.creditos_preaprobados (
      user_id, ficha_id, score_id,
      segmento, tipo_producto,
      score_transaccional, score_campo, score_final,
      monto_hipotesis, monto_aprobado, plazo_meses,
      tasa_tea, cuota_mensual,
      estado, fecha_preaprobacion, fecha_desembolso,
      dias_mora, estado_pago
    ) VALUES (
      v_user_id, v_base.ficha_id, v_base.score_id,
      v_base.segmento, p_producto_id,
      v_base.score_transaccional, v_base.score_campo, v_base.score_final,
      v_monto_inicial, v_monto_inicial, v_plazo,
      0.60, v_nueva_cuota,
      'desembolsado', CURRENT_DATE, CURRENT_DATE,
      0, 'al_dia'
    )
    RETURNING * INTO v_credito;

    INSERT INTO public.solicitudes_prestamo (
      user_id, monto, plazo_meses, tasa_anual, cuota_mensual, proposito, estado
    ) VALUES (
      v_user_id, v_monto_inicial, v_plazo, 60.00, v_nueva_cuota,
      CASE p_producto_id
        WHEN 'mujeres_unidas' THEN 'Crédito Mujeres Unidas — apertura'
        ELSE 'Crédito Prospera — apertura'
      END,
      'aprobado'
    );

    RETURN jsonb_build_object(
      'ok', true,
      'nuevo', true,
      'tipo_producto', p_producto_id,
      'monto_aprobado', v_monto_inicial,
      'cuota_mensual', v_nueva_cuota,
      'incremento', v_monto_inicial
    );
  END IF;

  -- Techo según producto + segmento
  IF p_producto_id = 'mujeres_unidas' THEN
    v_techo := CASE v_credito.segmento
      WHEN 'PREMIER'  THEN 8000
      WHEN 'ESTANDAR' THEN 4000
      WHEN 'BASICO'   THEN 1500
      ELSE 2000
    END;
  ELSE
    v_techo := CASE v_credito.segmento
      WHEN 'PREMIER'  THEN 15000
      WHEN 'ESTANDAR' THEN 8000
      WHEN 'BASICO'   THEN 3000
      ELSE 4000
    END;
  END IF;

  v_incremento := COALESCE(
    p_monto_adicional,
    GREATEST(v_min_auto, ROUND(v_credito.monto_aprobado * v_pct_auto / 100) * 100)
  );

  v_nuevo_monto := LEAST(v_credito.monto_aprobado + v_incremento, v_techo);

  IF v_nuevo_monto <= v_credito.monto_aprobado THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'limite_alcanzado',
      'tipo_producto', p_producto_id,
      'monto_actual', v_credito.monto_aprobado,
      'techo', v_techo
    );
  END IF;

  v_tem := POWER(1.60, 1.0 / 12) - 1;
  IF v_credito.plazo_meses > 0
     AND ABS(POWER(1 + v_tem, v_credito.plazo_meses) - 1) > 0.000001 THEN
    v_factor := v_tem * POWER(1 + v_tem, v_credito.plazo_meses)
              / (POWER(1 + v_tem, v_credito.plazo_meses) - 1);
  ELSE
    v_factor := 0;
  END IF;
  v_nueva_cuota := ROUND(v_nuevo_monto * v_factor, 2);

  UPDATE public.creditos_preaprobados
  SET monto_aprobado = v_nuevo_monto,
      cuota_mensual = v_nueva_cuota,
      updated_at = now()
  WHERE id = v_credito.id;

  INSERT INTO public.solicitudes_prestamo (
    user_id, monto, plazo_meses, tasa_anual, cuota_mensual, proposito, estado
  ) VALUES (
    v_user_id,
    v_nuevo_monto - v_credito.monto_aprobado,
    v_credito.plazo_meses,
    60.00,
    v_nueva_cuota,
    CASE p_producto_id
      WHEN 'mujeres_unidas' THEN 'Crédito Mujeres Unidas — aumento'
      ELSE 'Crédito Prospera — aumento'
    END,
    'aprobado'
  );

  RETURN jsonb_build_object(
    'ok', true,
    'nuevo', false,
    'tipo_producto', p_producto_id,
    'monto_aprobado', v_nuevo_monto,
    'cuota_mensual', v_nueva_cuota,
    'incremento', v_nuevo_monto - v_credito.monto_aprobado,
    'techo', v_techo
  );
END;
$$;

DROP FUNCTION IF EXISTS public.solicitar_aumento_credito(NUMERIC, TEXT);
DROP FUNCTION IF EXISTS public.solicitar_aumento_credito(TEXT, TEXT);

REVOKE ALL ON FUNCTION public.solicitar_aumento_credito(TEXT, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.solicitar_aumento_credito(TEXT, NUMERIC) TO authenticated;

-- Refrescar caché de PostgREST (importante tras crear/alterar funciones)
NOTIFY pgrst, 'reload schema';
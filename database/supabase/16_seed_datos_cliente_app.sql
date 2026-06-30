-- ============================================================
-- Datos demo app clientes: tarjetas, notificaciones, cronograma
-- Ejecutar si Tarjetas / Notificaciones vacías o sin cronograma.
-- Requiere: 01b (o 01), 13 (cronograma_cuotas + notificaciones)
-- ============================================================

-- ── 1. Tarjeta débito por cliente (vinculada a su cuenta) ────
INSERT INTO public.tarjetas (
  user_id, tipo, numero_enmascarado, estado, saldo_disponible, cuenta_asociada
)
SELECT DISTINCT ON (c.user_id)
  c.user_id,
  'debito',
  '**** **** **** ' || RIGHT(regexp_replace(c.numero_cuenta, '[^0-9]', '', 'g'), 4),
  'activa',
  c.saldo,
  c.numero_cuenta
FROM public.cuentas c
WHERE NOT EXISTS (
  SELECT 1 FROM public.tarjetas t WHERE t.user_id = c.user_id
)
ORDER BY c.user_id, c.created_at;

-- Tarjeta crédito opcional (~30% de clientes con tarjeta débito)
INSERT INTO public.tarjetas (
  user_id, tipo, numero_enmascarado, estado, saldo_disponible, cuenta_asociada
)
SELECT
  t.user_id,
  'credito',
  '**** **** **** ' || LPAD((ABS(hashtext(t.user_id::TEXT)) % 10000)::TEXT, 4, '0'),
  'activa',
  LEAST(t.saldo_disponible * 0.5, 3000),
  t.cuenta_asociada
FROM public.tarjetas t
WHERE t.tipo = 'debito'
  AND (ABS(hashtext(t.user_id::TEXT)) % 10) < 3
  AND NOT EXISTS (
    SELECT 1 FROM public.tarjetas t2
    WHERE t2.user_id = t.user_id AND t2.tipo = 'credito'
  );

-- ── 2. Notificación de bienvenida ───────────────────────────
INSERT INTO public.notificaciones (
  destinatario_tipo, user_id, titulo, cuerpo, tipo, leida
)
SELECT
  'cliente',
  pc.user_id,
  'Bienvenido a SURGIR Móvil',
  'Consulta saldos, créditos y realiza pagos desde tu banca móvil.',
  'bienvenida',
  FALSE
FROM public.perfiles_clientes pc
WHERE NOT EXISTS (
  SELECT 1 FROM public.notificaciones n
  WHERE n.user_id = pc.user_id
    AND n.destinatario_tipo = 'cliente'
);

-- Notificación por cada préstamo activo sin aviso de desembolso
INSERT INTO public.notificaciones (
  destinatario_tipo, user_id, titulo, cuerpo, tipo, leida, data_json
)
SELECT
  'cliente',
  p.user_id,
  'Crédito desembolsado',
  'Tu crédito ' || p.numero_enmascarado || ' de S/ '
    || p.capital_total::TEXT || ' está activo. Revisa tu cronograma en Créditos.',
  'desembolsado',
  FALSE,
  jsonb_build_object('prestamo_id', p.id, 'cod_credito', p.numero_enmascarado)
FROM public.prestamos p
WHERE NOT EXISTS (
  SELECT 1 FROM public.notificaciones n
  WHERE n.user_id = p.user_id
    AND n.tipo = 'desembolsado'
    AND (n.data_json->>'prestamo_id')::TEXT = p.id::TEXT
);

-- ── 3. Cronograma para préstamos sin cuotas ───────────────────
DO $$
DECLARE
  r RECORD;
  v_cuota NUMERIC;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'cronograma_cuotas'
  ) THEN
    RAISE NOTICE 'Tabla cronograma_cuotas no existe. Ejecuta 13_ecosistema_integrado.sql primero.';
    RETURN;
  END IF;

  FOR r IN
    SELECT
      p.id,
      p.user_id,
      p.capital_total,
      p.cuotas_total,
      GREATEST(p.capital_cuota + p.intereses_cuota, 1) AS cuota_mensual
    FROM public.prestamos p
    WHERE NOT EXISTS (
      SELECT 1 FROM public.cronograma_cuotas cc WHERE cc.prestamo_id = p.id
    )
  LOOP
    PERFORM public.fn_generar_cronograma(
      r.id,
      r.user_id,
      r.capital_total,
      r.cuotas_total,
      60.00,
      r.cuota_mensual
    );
  END LOOP;
END $$;

-- ── 4. Desembolsar solicitudes en_comite atascadas (opcional) ─
DO $$
DECLARE
  r RECORD;
  v_res JSONB;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'fn_desembolsar_solicitud'
  ) THEN
    RETURN;
  END IF;

  FOR r IN
    SELECT id FROM public.solicitudes_prestamo
    WHERE estado = 'en_comite'
  LOOP
    v_res := public.fn_desembolsar_solicitud(r.id);
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';

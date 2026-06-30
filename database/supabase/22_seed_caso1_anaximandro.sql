-- ============================================================
-- Caso 1 — Cliente del manual (Anaximandro Quispe)
-- DNI 40118120 · asignado al asesor AG-001-01
-- Ejecutar después de 04, 10 y 21.
-- Login app clientes: 40118120 + Cliente2026!
-- Login FVentas: AG-001-01 + Asesor2026!
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
  v_uid           UUID := '40118120-0000-4000-8000-000000000001';
  v_email         TEXT := 'anaximandro.quispe@cliente.pe';
  v_asesor_nombre TEXT;
  v_agencia       TEXT;
  v_cuenta_id     UUID := gen_random_uuid();
  v_score_id      UUID := gen_random_uuid();
  v_ficha_id      UUID := gen_random_uuid();
BEGIN
  SELECT an.nombres || ' ' || an.apellidos, ag.nombre
  INTO v_asesor_nombre, v_agencia
  FROM public.asesores_negocio an
  JOIN public.agencias ag ON ag.id = an.id_agencia
  WHERE an.codigo = 'AG-001-01'
    AND an.activo = TRUE;

  IF v_asesor_nombre IS NULL THEN
    RAISE EXCEPTION 'No existe el asesor AG-001-01. Ejecuta 03_seed_agencias_asesores.sql';
  END IF;

  -- Auth (misma contraseña que clientes seed)
  PERFORM public.seed_auth_user(v_uid, v_email);

  INSERT INTO public.auth_mock (id, email)
  VALUES (v_uid, v_email)
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;

  -- Perfil — datos del Caso 1
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
    v_uid, '40118120', 'Anaximandro', 'Quispe',
    '1985-03-15', '964110201',
    'El Tambo', 'Huancayo', 'Junín',
    'Bodega Don Anaxi', 'Bodega', 'Av. Principal 120, El Tambo',
    -12.0581, -75.2027,
    48, 'propio',
    1, 'Normal', 4500.00,
    'activo'
  )
  ON CONFLICT (user_id) DO UPDATE SET
    dni = EXCLUDED.dni,
    nombres = EXCLUDED.nombres,
    apellidos = EXCLUDED.apellidos,
    telefono = EXCLUDED.telefono,
    nombre_negocio = EXCLUDED.nombre_negocio,
    lat_negocio = EXCLUDED.lat_negocio,
    lng_negocio = EXCLUDED.lng_negocio,
    antiguedad_negocio_meses = EXCLUDED.antiguedad_negocio_meses,
    num_entidades_sbs = EXCLUDED.num_entidades_sbs,
    deuda_total_sbs = EXCLUDED.deuda_total_sbs;

  -- Cuenta de ahorro (ingresos ~2200, gastos ~900 del manual)
  DELETE FROM public.cuentas WHERE user_id = v_uid;

  INSERT INTO public.cuentas (id, user_id, tipo, numero_cuenta, saldo, moneda)
  VALUES (v_cuenta_id, v_uid, 'ahorro', '019-4011812', 1850.00, 'PEN');

  -- Score transaccional mínimo (pre-evaluación APTO ~85)
  INSERT INTO public.scores_transaccionales (
    id, user_id,
    pts_saldo, pts_regularidad, pts_disciplina, pts_vinculo, pts_riesgo,
    monto_hipotesis, ingreso_promedio_ref
  ) VALUES (
    v_score_id, v_uid,
    30, 20, 15, 10, 10,
    1000.00, 2200.00
  )
  ON CONFLICT (user_id) DO UPDATE SET
    pts_saldo = EXCLUDED.pts_saldo,
    pts_regularidad = EXCLUDED.pts_regularidad,
    monto_hipotesis = EXCLUDED.monto_hipotesis,
    ingreso_promedio_ref = EXCLUDED.ingreso_promedio_ref,
    updated_at = now();

  -- Ficha de campo → vincula al asesor AG-001-01 (cartera FVentas)
  DELETE FROM public.fichas_campo WHERE user_id = v_uid;

  INSERT INTO public.fichas_campo (
    id, user_id, score_id,
    asesor_nombre, agencia, fecha_visita,
    negocio_verificado,
    antiguedad_negocio, tenencia_local,
    ventas_mensuales_est, gastos_fijos_mes,
    score_transaccional_ref,
    monto_aprobado_propuesto, plazo_propuesto_meses, cuota_estimada,
    recomendacion_asesor,
    estado_ficha
  ) VALUES (
    v_ficha_id, v_uid, v_score_id,
    v_asesor_nombre, v_agencia, CURRENT_DATE - 30,
    TRUE,
    'mas_3_anios', 'propio',
    2200.00, 900.00,
    85,
    1000.00, 12, 100.95,
    'Cliente apto para Crédito Empresarial — Caso 1 piloto.',
    'completada'
  );

  -- Sin crédito activo previo (solicitud nueva desde la app)
  DELETE FROM public.creditos_preaprobados
  WHERE user_id = v_uid;

  DELETE FROM public.solicitudes_prestamo
  WHERE user_id = v_uid;

  RAISE NOTICE 'Caso 1 listo: DNI 40118120 · email % · asesor %', v_email, v_asesor_nombre;
END;
$$;

NOTIFY pgrst, 'reload schema';

-- Verificación
SELECT pc.dni, pc.nombres, pc.apellidos, am.email, fc.asesor_nombre
FROM public.perfiles_clientes pc
JOIN public.auth_mock am ON am.id = pc.user_id
LEFT JOIN public.fichas_campo fc ON fc.user_id = pc.user_id
WHERE pc.dni = '40118120';

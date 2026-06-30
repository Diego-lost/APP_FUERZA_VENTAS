-- Sincroniza saldo pendiente de prestamos → creditos_preaprobados
-- para que Fuerza de Ventas (web + app) vea la deuda actualizada al pagar cuotas.
-- Ejecutar DESPUÉS de 30_cobranza_completa.sql

ALTER TABLE public.creditos_preaprobados
  ADD COLUMN IF NOT EXISTS saldo_pendiente NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS cuotas_pagadas SMALLINT DEFAULT 0;

-- Copia capital_pendiente y cuotas pagadas desde prestamos activo del cliente.
CREATE OR REPLACE FUNCTION public.sync_saldo_credito_cliente(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_capital   NUMERIC(12,2);
  v_cuota_nro INT;
  v_cuotas    INT;
BEGIN
  SELECT capital_pendiente, cuota_numero, cuotas_total
  INTO v_capital, v_cuota_nro, v_cuotas
  FROM public.prestamos
  WHERE user_id = p_user_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  UPDATE public.creditos_preaprobados
  SET saldo_pendiente = v_capital,
      cuotas_pagadas = GREATEST(0, LEAST(v_cuotas, v_cuota_nro - 1)),
      updated_at = now()
  WHERE user_id = p_user_id
    AND estado = 'desembolsado';
END;
$$;

REVOKE ALL ON FUNCTION public.sync_saldo_credito_cliente(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sync_saldo_credito_cliente(UUID) TO authenticated;

-- Backfill clientes con préstamo activo
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT DISTINCT user_id FROM public.prestamos LOOP
    PERFORM public.sync_saldo_credito_cliente(r.user_id);
  END LOOP;
END $$;

-- Pago de cuota: además de mora, sincroniza saldo visible al asesor
CREATE OR REPLACE FUNCTION public.cliente_pagar_cuota(
  p_prestamo_id UUID,
  p_cuenta_id UUID,
  p_nro_cuota INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_prestamo RECORD;
  v_cuenta RECORD;
  v_cuota RECORD;
  v_nro INT;
  v_capital_pendiente NUMERIC(12,2);
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  SELECT * INTO v_prestamo
  FROM public.prestamos
  WHERE id = p_prestamo_id AND user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'prestamo_no_encontrado');
  END IF;

  SELECT * INTO v_cuenta
  FROM public.cuentas
  WHERE id = p_cuenta_id AND user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'cuenta_invalida');
  END IF;

  v_nro := COALESCE(p_nro_cuota, v_prestamo.cuota_numero);

  SELECT * INTO v_cuota
  FROM public.cronograma_cuotas
  WHERE prestamo_id = p_prestamo_id AND nro_cuota = v_nro
    AND estado_cuota IN ('pendiente', 'vencida')
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'cuota_no_pendiente');
  END IF;

  IF v_cuenta.saldo < v_cuota.monto_cuota THEN
    RETURN jsonb_build_object('ok', false, 'error', 'saldo_insuficiente');
  END IF;

  UPDATE public.cuentas SET saldo = saldo - v_cuota.monto_cuota WHERE id = p_cuenta_id;
  UPDATE public.cronograma_cuotas
  SET estado_cuota = 'pagada', fecha_pago = CURRENT_DATE
  WHERE id = v_cuota.id;
  UPDATE public.prestamos
  SET capital_pendiente = GREATEST(0, capital_pendiente - v_cuota.monto_capital),
      cuota_numero = LEAST(cuotas_total, cuota_numero + 1),
      fecha_limite = (CURRENT_DATE + INTERVAL '1 month')::DATE
  WHERE id = p_prestamo_id
  RETURNING capital_pendiente INTO v_capital_pendiente;

  INSERT INTO public.transacciones (user_id, cuenta_id, tipo, descripcion, monto)
  VALUES (v_user_id, p_cuenta_id, 'debito',
    'Pago cuota ' || v_nro::TEXT || ' crédito ' || v_prestamo.numero_enmascarado,
    v_cuota.monto_cuota);

  INSERT INTO public.pagos (user_id, servicio, numero_contrato, monto, estado)
  VALUES (v_user_id, 'telefono', v_prestamo.numero_enmascarado, v_cuota.monto_cuota, 'completado');

  INSERT INTO public.notificaciones (destinatario_tipo, user_id, titulo, cuerpo, tipo)
  VALUES ('cliente', v_user_id, 'Pago registrado',
    'Cuota ' || v_nro::TEXT || ' pagada por S/ ' || v_cuota.monto_cuota::TEXT,
    'pago_cuota');

  PERFORM public.sync_mora_cliente(v_user_id);
  PERFORM public.sync_saldo_credito_cliente(v_user_id);

  RETURN jsonb_build_object(
    'ok', true,
    'cuota_pagada', v_nro,
    'monto', v_cuota.monto_cuota,
    'nuevo_saldo', v_cuenta.saldo - v_cuota.monto_cuota,
    'capital_pendiente', v_capital_pendiente
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cliente_pagar_cuota(UUID, UUID, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cliente_pagar_cuota(UUID, UUID, INT) TO authenticated;

NOTIFY pgrst, 'reload schema';

-- ============================================================
-- Fix transferencia: validar cuenta destino antes de debitar
-- Ejecutar si la transferencia debita sin acreditar al destino
-- ============================================================

CREATE OR REPLACE FUNCTION public.cliente_realizar_transferencia(
  p_cuenta_origen_id UUID,
  p_cuenta_destino_numero TEXT,
  p_monto NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_origen RECORD;
  v_destino RECORD;
  v_destino_num TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  IF p_monto IS NULL OR p_monto <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'monto_invalido');
  END IF;

  v_destino_num := trim(COALESCE(p_cuenta_destino_numero, ''));
  IF v_destino_num = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'cuenta_destino_requerida');
  END IF;

  SELECT * INTO v_origen
  FROM public.cuentas
  WHERE id = p_cuenta_origen_id AND user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'cuenta_origen_invalida');
  END IF;

  IF v_origen.numero_cuenta = v_destino_num THEN
    RETURN jsonb_build_object('ok', false, 'error', 'misma_cuenta');
  END IF;

  IF v_origen.saldo < p_monto THEN
    RETURN jsonb_build_object('ok', false, 'error', 'saldo_insuficiente');
  END IF;

  SELECT * INTO v_destino
  FROM public.cuentas
  WHERE numero_cuenta = v_destino_num
    AND user_id != v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'cuenta_destino_no_encontrada',
      'hint', 'Usa el número de cuenta de otro cliente (ej. 019-0000001 del seed).'
    );
  END IF;

  UPDATE public.cuentas SET saldo = saldo - p_monto WHERE id = v_origen.id;
  UPDATE public.cuentas SET saldo = saldo + p_monto WHERE id = v_destino.id;

  INSERT INTO public.transacciones (user_id, cuenta_id, tipo, descripcion, monto)
  VALUES (v_user_id, v_origen.id, 'debito',
    'Transferencia a ' || v_destino_num, p_monto);

  INSERT INTO public.transacciones (user_id, cuenta_id, tipo, descripcion, monto)
  VALUES (v_destino.user_id, v_destino.id, 'credito',
    'Transferencia recibida de ' || v_origen.numero_cuenta, p_monto);

  INSERT INTO public.notificaciones (destinatario_tipo, user_id, titulo, cuerpo, tipo)
  VALUES ('cliente', v_user_id, 'Transferencia realizada',
    'Enviaste S/ ' || p_monto::TEXT || ' a cuenta ' || v_destino_num,
    'transferencia');

  INSERT INTO public.notificaciones (destinatario_tipo, user_id, titulo, cuerpo, tipo)
  VALUES ('cliente', v_destino.user_id, 'Transferencia recibida',
    'Recibiste S/ ' || p_monto::TEXT || ' desde ' || v_origen.numero_cuenta,
    'transferencia');

  RETURN jsonb_build_object(
    'ok', true,
    'nuevo_saldo', v_origen.saldo - p_monto,
    'cuenta_destino', v_destino_num
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cliente_realizar_transferencia(UUID, TEXT, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cliente_realizar_transferencia(UUID, TEXT, NUMERIC) TO authenticated;

NOTIFY pgrst, 'reload schema';

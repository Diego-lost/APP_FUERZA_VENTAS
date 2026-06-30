-- (Opcional) Ya incluido al inicio de 08_solicitar_credito_rpc.sql
-- Solo ejecuta este archivo si corriste una versión antigua de 08 sin la columna.

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

NOTIFY pgrst, 'reload schema';

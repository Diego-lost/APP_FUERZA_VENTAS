-- ============================================================
-- Parche: alinear public.cuentas con 01_supabase_setup.sql
-- Ejecutar si el seed 04 falla con "numero_cuenta does not exist"
-- (pasa cuando cuentas se creó desde scoring_preaprobados_fixed u otro script)
-- ============================================================

ALTER TABLE public.cuentas ADD COLUMN IF NOT EXISTS numero_cuenta TEXT;
ALTER TABLE public.cuentas ADD COLUMN IF NOT EXISTS moneda TEXT DEFAULT 'PEN';

UPDATE public.cuentas
SET numero_cuenta = '019-' || LPAD(
      COALESCE(NULLIF(regexp_replace(id::text, '[^0-9]', '', 'g'), ''), '0'),
      7, '0'
    )
WHERE numero_cuenta IS NULL OR numero_cuenta = '';

UPDATE public.cuentas SET moneda = 'PEN' WHERE moneda IS NULL;

-- Permitir tipos del seed y del setup oficial
ALTER TABLE public.cuentas DROP CONSTRAINT IF EXISTS cuentas_tipo_check;
ALTER TABLE public.cuentas
  ADD CONSTRAINT cuentas_tipo_check
  CHECK (tipo IN ('corriente', 'ahorro', 'ahorros'));

-- transacciones: columna descripcion (requerida por el seed)
ALTER TABLE public.transacciones ADD COLUMN IF NOT EXISTS descripcion TEXT;

UPDATE public.transacciones
SET descripcion = COALESCE(descripcion, INITCAP(tipo::text) || ' automático')
WHERE descripcion IS NULL;

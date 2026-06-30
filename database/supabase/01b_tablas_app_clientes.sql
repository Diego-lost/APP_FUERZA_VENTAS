-- ============================================================
-- Tablas base app clientes (si NO ejecutaste 01_supabase_setup.sql)
-- Ejecutar ANTES de 13_ecosistema_integrado.sql
-- Idempotente: CREATE IF NOT EXISTS
-- ============================================================

-- ── cuentas ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.cuentas (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tipo           TEXT NOT NULL CHECK (tipo IN ('corriente', 'ahorro')),
  numero_cuenta  TEXT NOT NULL,
  saldo          NUMERIC(12,2) NOT NULL DEFAULT 0,
  moneda         TEXT NOT NULL DEFAULT 'PEN',
  created_at     TIMESTAMPTZ DEFAULT now()
);

-- ── transacciones ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.transacciones (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  cuenta_id      UUID REFERENCES public.cuentas(id) ON DELETE SET NULL,
  tipo           TEXT NOT NULL CHECK (tipo IN ('debito', 'credito')),
  descripcion    TEXT NOT NULL,
  monto          NUMERIC(12,2) NOT NULL,
  fecha          TIMESTAMPTZ DEFAULT now()
);

-- ── pagos ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.pagos (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  servicio         TEXT NOT NULL CHECK (servicio IN ('agua','luz','cable','telefono','gas')),
  numero_contrato  TEXT NOT NULL,
  monto            NUMERIC(10,2) NOT NULL,
  estado           TEXT NOT NULL DEFAULT 'completado',
  fecha            TIMESTAMPTZ DEFAULT now()
);

-- ── solicitudes_prestamo (si 08 no la creó) ─────────────────
CREATE TABLE IF NOT EXISTS public.solicitudes_prestamo (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  monto          NUMERIC(12,2) NOT NULL,
  plazo_meses    INTEGER NOT NULL,
  tasa_anual     NUMERIC(5,2) NOT NULL DEFAULT 60,
  cuota_mensual  NUMERIC(10,2) NOT NULL DEFAULT 0,
  proposito      TEXT,
  estado         TEXT NOT NULL DEFAULT 'pendiente',
  created_at     TIMESTAMPTZ DEFAULT now()
);

-- ── tarjetas ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tarjetas (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tipo               TEXT NOT NULL CHECK (tipo IN ('debito','credito')),
  numero_enmascarado TEXT NOT NULL,
  estado             TEXT NOT NULL DEFAULT 'activa'
                       CHECK (estado IN ('activa','apagada','bloqueada')),
  saldo_disponible   NUMERIC(12,2) NOT NULL DEFAULT 0,
  cuenta_asociada    TEXT NOT NULL,
  created_at         TIMESTAMPTZ DEFAULT now()
);

-- ── prestamos (la que falta y rompe el script 13) ───────────
CREATE TABLE IF NOT EXISTS public.prestamos (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tipo               TEXT NOT NULL DEFAULT 'prestamo personal',
  numero_enmascarado TEXT NOT NULL,
  capital_total      NUMERIC(12,2) NOT NULL,
  capital_pendiente  NUMERIC(12,2) NOT NULL,
  cuota_numero       INTEGER NOT NULL DEFAULT 1,
  cuotas_total       INTEGER NOT NULL,
  fecha_limite       DATE NOT NULL,
  capital_cuota      NUMERIC(12,2) NOT NULL DEFAULT 0,
  intereses_cuota    NUMERIC(12,2) NOT NULL DEFAULT 0,
  seguros_cuota      NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at         TIMESTAMPTZ DEFAULT now()
);

-- ── RLS básico ──────────────────────────────────────────────
ALTER TABLE public.cuentas       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transacciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pagos         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prestamos     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tarjetas      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitudes_prestamo ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Usuario ve sus propias cuentas" ON public.cuentas;
CREATE POLICY "Usuario ve sus propias cuentas"
  ON public.cuentas FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Usuario ve sus propias transacciones" ON public.transacciones;
CREATE POLICY "Usuario ve sus propias transacciones"
  ON public.transacciones FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Usuario ve sus propios pagos" ON public.pagos;
CREATE POLICY "Usuario ve sus propios pagos"
  ON public.pagos FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Usuario ve sus propios prestamos" ON public.prestamos;
CREATE POLICY "Usuario ve sus propios prestamos"
  ON public.prestamos FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Usuario ve sus propias tarjetas" ON public.tarjetas;
CREATE POLICY "Usuario ve sus propias tarjetas"
  ON public.tarjetas FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Usuario ve sus propias solicitudes" ON public.solicitudes_prestamo;
CREATE POLICY "Usuario ve sus propias solicitudes"
  ON public.solicitudes_prestamo FOR ALL USING (auth.uid() = user_id);

NOTIFY pgrst, 'reload schema';

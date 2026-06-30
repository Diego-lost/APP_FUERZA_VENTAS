-- Lectura pública de agencias para el mapa de sucursales en la app
ALTER TABLE public.agencias ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Publico lee agencias activas" ON public.agencias;
CREATE POLICY "Publico lee agencias activas"
  ON public.agencias FOR SELECT
  USING (activa = TRUE);

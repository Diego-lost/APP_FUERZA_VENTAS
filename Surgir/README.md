# Surgir — Portal Fuerza de Ventas (Web)

Portal web en **React + Vite** para asesores de **Financiera SURGIR**.
Conectado a **Supabase** — la misma base de datos que la app Flutter (`Aplicacion banco 2`).

## Puesta en marcha

```powershell
npm install
copy .env.example .env   # Mismas credenciales que Aplicacion banco 2/.env
npm run dev
```

Abrir http://localhost:5173

### Requisitos en Supabase

Ejecutar en el SQL Editor (si aún no lo hiciste):

1. `database/supabase/10_fuerza_ventas_auth.sql`
2. `database/supabase/11_fuerza_ventas_modulos.sql`

### Acceso demo

| Código asesor | Contraseña |
|---------------|------------|
| `AG-001-01`   | `Asesor2026!` |

## Arquitectura

```
Portal web (5173)  ──►  Supabase  ◄──  App Flutter Fuerza de Ventas
```

Ya **no** usa el backend FastAPI en Docker. Web y app comparten datos.

## Módulos conectados a Supabase

| Módulo | Fuente Supabase |
|--------|-----------------|
| Login | `get_asesor_email_by_codigo` + Auth |
| Dashboard / Cartera | `asesor_get_ruta_dia` |
| Ficha cliente | `perfiles_clientes` + `asesor_consulta_buro` |
| Solicitudes | `solicitudes_prestamo` + `asesor_crear_solicitud_credito` |
| Buró | `asesor_consulta_buro` |
| Cobranza | `asesor_listar_mora_dia` + `asesor_registrar_accion_cobranza` |
| Reportes | `solicitudes_prestamo` del mes |

## Pendiente en Supabase

- Notas internas en solicitudes
- Política RLS para actualizar `fichas_campo` (visitas)

## Cobranza (script 30)

Ejecutar `database/supabase/30_cobranza_completa.sql` para:

- Tabla `acciones_cobranza` (gestiones persistidas)
- Sincronización de mora desde `cronograma_cuotas`
- RPC `asesor_listar_mora_dia`, `asesor_registrar_accion_cobranza`, `asesor_historial_cobranza`

## Variables de entorno

```
VITE_SUPABASE_URL=https://tu-proyecto.supabase.co
VITE_SUPABASE_ANON_KEY=tu_anon_key
```

## Despliegue en Vercel

Portal en producción: **https://financiera-surgir.vercel.app**

### Variables obligatorias (Settings → Environment Variables)

Sin estas variables el build de Vite **no incluye** la conexión a Supabase y la página queda en blanco.

| Variable | Ejemplo |
|----------|---------|
| `VITE_SUPABASE_URL` | `https://xxx.supabase.co` |
| `VITE_SUPABASE_ANON_KEY` | `eyJ...` (anon key del proyecto) |

Marca **Production**, **Preview** y **Development**. Después de guardar, haz **Redeploy** (no basta con guardar las variables).

Copia los mismos valores que en `.env` local o en la app Flutter.

### Build

| Configuración | Valor |
|---------------|-------|
| Framework | Vite |
| Build | `npm run build` |
| Output | `dist` |

`vercel.json` redirige rutas SPA (`/login`, `/inicio`, etc.) a `index.html`.

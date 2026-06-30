# Supabase — App Fuerza de Ventas

## 1. Configurar `.env`

Copia `.env.example` a `.env` en esta carpeta (misma URL y anon key que la app de clientes):

```
SUPABASE_URL=https://TU_PROYECTO.supabase.co
SUPABASE_ANON_KEY=eyJ...
GOOGLE_MAPS_API_KEY=AIzaSy...
```

Habilita en Google Cloud: **Maps SDK for Android**, **Geocoding API** y **Places API**.

## 2. SQL en Supabase

Ejecuta en el SQL Editor, después de los seeds:

```
database/supabase/10_fuerza_ventas_auth.sql
```

Eso crea usuarios auth para los 360 asesores, el RPC de login y las políticas RLS de cartera.

Luego ejecuta también:

```
database/supabase/11_fuerza_ventas_modulos.sql
```

Para habilitar solicitudes, documentos, buró, ruta y transmisión.

Y para **registro de clientes/asesores + GPS**:

```
database/supabase/25_fventas_registro_maps.sql
```

Para **cobranza completa** (mora desde cronograma + gestiones guardadas):

```
database/supabase/30_cobranza_completa.sql
```

O ejecuta `scripts/apply_cobranza_sql.ps1` (copia el SQL y abre el editor).

## 3. Credenciales de prueba

| Campo | Valor |
|-------|-------|
| Código | `AG-001-01` (cualquier asesor activo) |
| Contraseña | `Asesor2026!` |

Para listar códigos:

```sql
SELECT codigo, nombres, apellidos, email
FROM public.asesores_negocio
WHERE activo = TRUE
LIMIT 10;
```

## 4. Ejecutar la app

```bash
flutter pub get
flutter run
```

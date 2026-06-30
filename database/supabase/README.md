# Base de datos Supabase — SURGIR Piloto

Scripts corregidos para ejecutar en **Supabase → SQL Editor**, en este orden:

| # | Archivo | Descripción |
|---|---------|-------------|
| 1 | `00_extensions.sql` | Habilita `pgcrypto` |
| 2 | `01_supabase_setup.sql` | Tablas base (cuentas, transacciones, préstamos…) |
| 2b | `01b_tablas_app_clientes.sql` | **Solo si el 13 falla** con `prestamos no existe` (no corriste el 01) |
| 3 | `02_scoring_preaprobados.sql` | Scoring, fichas de campo, vistas Power BI |
| 4 | `03_seed_agencias_asesores.sql` | 30 agencias + 360 asesores |
| 4b | `03b_align_cuentas_schema.sql` | Solo si `04` falla por `numero_cuenta` (opcional; ya va en `04`) |
| 5 | `04_seed_scoring_1800.sql` | 1.800 clientes + función `seed_auth_user` incluida |
| 6 | `05_login_rpc.sql` | RPC login por DNI (requerido para la app Flutter) |
| 7 | `06_fix_auth_passwords.sql` | Solo si el login falla: arregla hash y `auth.identities` |
| 8 | `07_agencias_public_read.sql` | Permite leer agencias en el mapa de la app |
| 9 | `08_solicitar_credito_rpc.sql` | Columna `tipo_producto` + RPC (todo en un solo archivo) |
| 10 | `10_fuerza_ventas_auth.sql` | Auth asesores + RLS cartera (app Fuerza de Ventas) |
| 11 | `11_fuerza_ventas_modulos.sql` | Solicitudes, documentos, buró y transmisión (asesores) |
| 12 | `12_fix_buro_rpc.sql` | Solo si consulta buró falla (columna `created_at` → `fecha_calculo`) |
| 13 | `13_ecosistema_integrado.sql` | Sync E2E, cronograma, notificaciones, operaciones cliente, RBAC |
| 14 | `14_fix_desembolso_cliente.sql` | **Si FVentas crea solicitud pero clientes no ve crédito** (columnas + desembolso resiliente) |
| 15 | `15_asesor_listar_solicitudes.sql` | **Si FVentas "Estado de solicitudes" vacío** pero hay datos en BD |
| 16 | `16_seed_datos_cliente_app.sql` | **Tarjetas / notificaciones vacías** o préstamos sin cronograma |
| 17 | `17_seguridad_asesores_rbac.sql` | **Criterio 4:** bloqueo asesor + matriz RBAC (`asesor_obtener_perfil_rbac`) |
| 18 | `18_fix_cliente_bloqueo.sql` | **Bloqueo 5 intentos clientes** no funciona + DNI normalizado |
| 19 | `19_fix_asesor_bloqueo.sql` | **Bloqueo 5 intentos FVentas** (10 seg, igual que clientes) |
| 20 | `20_fix_verificar_bloqueo_volatile.sql` | **Login clientes/asesores dice "Revisa tu conexión"** (STABLE + UPDATE) |
| 21 | `21_cliente_solicitud_fventas.sql` | **Caso 1:** cliente solicita crédito → FVentas evalúa y aprueba |
| 22 | `22_seed_caso1_anaximandro.sql` | *(Opcional)* Cliente precargado — solo si no usas registro en app |
| 23 | `23_cliente_auto_registro.sql` | **Registro en app:** tú ingresas los datos del Caso 1 |
| 25 | `25_fventas_registro_maps.sql` | **FVentas:** registrar clientes, crear asesores (admin), GPS |
| 26 | `26_fix_registro_recomendacion_asesor.sql` | **Registro app:** fix CHECK `recomendacion_asesor` |
| 27 | `27_fix_transferencia_destino.sql` | **Transferencias:** valida cuenta destino antes de debitar |
| 28 | `28_asesor_responder_solicitud.sql` | **FVentas:** asesor aprueba / rechaza / eleva solicitud del cliente |
| 29 | `29_desembolso_abona_cuenta.sql` | **Al aprobar:** abona cuenta + crédito activo en app clientes |
| 30 | `30_cobranza_completa.sql` | **Cobranza:** mora desde cronograma + gestiones persistidas |
| 31 | `31_desembolso_seleccion_transmision.sql` | **Aprobar ≠ desembolsar:** desembolso selectivo en Transmisión |
| 32 | `32_sync_deuda_tras_pago.sql` | **Pago cuota cliente:** sincroniza saldo pendiente visible al asesor (web + FVentas) |
| — | `09_credito_producto.sql` | Opcional; ya está incluido en el 08 |

`02b_seed_auth_helper.sql` es opcional (ya está integrado en el paso 5).

## Apps Flutter

En `flutter_financiera_surgir_clientes/` y `Aplicacion banco 2/` copia `.env.example` → `.env` con tu URL y anon key (Settings → API en Supabase).

### App clientes
- Login: DNI + contraseña `Cliente2026!`

### App Fuerza de Ventas
- Requiere ejecutar `10_fuerza_ventas_auth.sql` y `11_fuerza_ventas_modulos.sql`
- Login: código de asesor (ej. `AG-001-01`) + contraseña `Asesor2026!`

## Correcciones aplicadas

1. **`auth.users`**: el seed ya no falla por FK; cada cliente se registra con `seed_auth_user()`.
2. **`mes_offset`**: variable declarada en el bloque PL/pgSQL del seed.
3. **`edad`**: columna normal + trigger (no `GENERATED`, que falla en inserts).
4. **`scores_transaccionales`**: restricción `UNIQUE(user_id)` para `ON CONFLICT`.
5. **Políticas RLS**: `DROP POLICY IF EXISTS` antes de crear (re-ejecución segura).
6. **Agencias/asesores**: `ON CONFLICT DO NOTHING` (idempotente).
7. **Cuota**: protección contra división por cero en el cálculo de `factor_cuota`.

## Credenciales de prueba (clientes seed)

- **Email**: generado como `nombre.apellido{N}@cliente.pe` (ver tabla `auth_mock` o `perfiles_clientes`).
- **Contraseña**: `Cliente2026!`

Ejemplo para buscar un cliente:

```sql
SELECT pc.dni, pc.nombres, pc.apellidos, am.email
FROM public.perfiles_clientes pc
JOIN public.auth_mock am ON am.id = pc.user_id
LIMIT 10;
```

## Verificación rápida

```sql
SELECT 'agencias' AS tabla, COUNT(*) FROM public.agencias
UNION ALL SELECT 'asesores', COUNT(*) FROM public.asesores_negocio
UNION ALL SELECT 'perfiles_clientes', COUNT(*) FROM public.perfiles_clientes
UNION ALL SELECT 'creditos_preaprobados', COUNT(*) FROM public.creditos_preaprobados;
```

Valores esperados: **30** agencias, **360** asesores, **1800** perfiles.

## Nota

Ejecuta cada archivo por separado con **Run**. Si un script falla a mitad, revisa el error, corrige y vuelve a ejecutar solo el archivo afectado (los seeds usan `ON CONFLICT` donde aplica).

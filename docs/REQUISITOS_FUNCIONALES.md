# Requisitos Funcionales — Ecosistema Móvil SURGIR (Supabase)

## Autenticación y seguridad

| RF | Descripción | Implementación |
|----|-------------|----------------|
| RF-01 | Login asesor por código de empleado | `get_asesor_email_by_codigo` + Supabase Auth |
| RF-04 | Bloqueo tras 5 intentos fallidos | `cliente_registrar_intento_fallido` / `perfiles_clientes.bloqueado_hasta` |
| RF-06 | Perfiles: operador, super_operador, supervisor, administrador | `asesores_negocio.perfil` |
| RF-57 | Consentimiento Ley 29733 en consulta buró | `consultas_buro` + RPC con firma base64 |

## Originación (Fuerza de Ventas)

| RF | Descripción | Implementación |
|----|-------------|----------------|
| RF-09 | Cartera diaria asignada | `fichas_campo` + `asesor_get_ruta_dia` |
| RF-47 | Simulador con cronograma de amortización francesa | `CreditSimulator` + tabla cronograma en UI |
| RF-62..65 | Transmisión electrónica al sistema central | `asesor_transmitir_pendientes` |
| RF-80 | Reportes solo supervisor/admin | `asesor_reporte_productividad` retorna 403 |

## App Clientes (Homebanking)

| RF | Descripción | Implementación |
|----|-------------|----------------|
| RF-C10 | Consulta cuentas de ahorro | `cuentas` + pantalla Accounts |
| RF-C11 | Créditos con cronograma de cuotas | `prestamos` + `cronograma_cuotas` |
| RF-C12 | Movimientos de cuenta | `transacciones` |
| RF-C13 | Tarjetas | `tarjetas` |
| RF-C14 | Notificaciones push/in-app | `notificaciones` |
| RF-C15 | Pago de cuota que impacta BD | `cliente_pagar_cuota` |
| RF-C16 | Transferencias | `cliente_realizar_transferencia` |

## Sincronización

| RF | Descripción | Implementación |
|----|-------------|----------------|
| RF-S01 | Cola mobile → core | `sync_outbox` |
| RF-S02 | Bitácora bidireccional | `sync_log` |
| RF-S03 | Retroalimentación core → app clientes | `fn_desembolsar_solicitud` |

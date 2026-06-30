# Historias de Usuario — Ecosistema Móvil SURGIR

## App Fuerza de Ventas (`Aplicacion banco 2`)

| ID | Historia | Criterio de aceptación |
|----|----------|------------------------|
| HU-09 | Como asesor quiero ver mi cartera del día con filtros y prioridad | Lista offline/online con mora, visitas y orden |
| HU-17 | Como asesor quiero registrar una solicitud de crédito en campo | Stepper con simulador RF-47 y transmisión |
| HU-20 | Como asesor quiero ver el estado de mis solicitudes del mes | Listado por estado y expediente |
| HU-25 | Como asesor quiero transmitir solicitudes y documentos al comité | RPC `asesor_transmitir_pendientes` |
| HU-57 | Como asesor debo obtener consentimiento firmado antes del buró | RPC `asesor_consulta_buro_con_consentimiento` |

## App Clientes (`flutter_financiera_surgir_clientes`)

| ID | Historia | Criterio de aceptación |
|----|----------|------------------------|
| HU-C01 | Como cliente quiero iniciar sesión con mi DNI | Login RPC + JWT Supabase + secure storage |
| HU-C02 | Como cliente quiero ver mis cuentas y saldos | Tabla `cuentas` vía RLS |
| HU-C03 | Como cliente quiero ver mis créditos con cronograma | Tablas `prestamos` + `cronograma_cuotas` |
| HU-C04 | Como cliente quiero pagar mi cuota desde la app | RPC `cliente_pagar_cuota` impacta saldos |
| HU-C05 | Como cliente quiero transferir entre cuentas | RPC `cliente_realizar_transferencia` |
| HU-C06 | Como cliente quiero ver notificaciones de operaciones | Tabla `notificaciones` |

## Integración end-to-end

| ID | Historia | Criterio de aceptación |
|----|----------|------------------------|
| HU-E2E-01 | Como sistema, al transmitir una solicitud debo reflejarla en la app clientes | `fn_desembolsar_solicitud` crea préstamo + cronograma + notificación |
| HU-E2E-02 | Como auditor quiero trazabilidad del puente al núcleo | Tablas `sync_outbox` y `sync_log` en Supabase |

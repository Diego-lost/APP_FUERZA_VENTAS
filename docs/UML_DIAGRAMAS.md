# Diagramas UML — Ecosistema Móvil SURGIR

Arquitectura: **Supabase (PostgreSQL)** como única base de datos compartida.

## Diagrama de componentes

```mermaid
flowchart TB
    subgraph apps [Apps Flutter]
        FV[Aplicacion banco 2\nFuerza de Ventas]
        CL[flutter_financiera_surgir_clientes\nApp Clientes]
    end

    subgraph supa [Supabase]
        AUTH[Auth JWT]
        DB[(PostgreSQL)]
        RPC[RPC / RLS]
    end

    FV -->|supabase_flutter| AUTH
    CL -->|supabase_flutter| AUTH
    FV --> RPC
    CL --> RPC
    RPC --> DB
    AUTH --> DB
```

## Diagrama de secuencia — Originación E2E

```mermaid
sequenceDiagram
    participant A as Asesor FVentas
    participant S as Supabase RPC
    participant DB as PostgreSQL
    participant C as App Clientes

    A->>S: asesor_crear_solicitud_credito
    S->>DB: INSERT solicitudes_prestamo
    A->>S: asesor_transmitir_pendientes
    S->>DB: UPDATE estado=en_comite
    S->>DB: fn_desembolsar_solicitud
    DB->>DB: INSERT prestamos, cronograma_cuotas
    DB->>DB: INSERT sync_outbox, sync_log
    DB->>DB: INSERT notificaciones
    C->>DB: SELECT prestamos, cronograma_cuotas
    C->>A: Cliente ve crédito desembolsado
```

## Diagrama de casos de uso

```mermaid
flowchart LR
    Asesor((Asesor))
    Cliente((Cliente))
    Supervisor((Supervisor))

    Asesor --> UC1[Gestionar cartera]
    Asesor --> UC2[Consultar buró]
    Asesor --> UC3[Crear solicitud]
    Asesor --> UC4[Transmitir al comité]
    Supervisor --> UC5[Ver reportes]
    Cliente --> UC6[Login DNI]
    Cliente --> UC7[Consultar productos]
    Cliente --> UC8[Pagar cuota]
    Cliente --> UC9[Transferir]
```

## Diagrama de estados — Solicitud de crédito

```mermaid
stateDiagram-v2
    [*] --> pendiente
    pendiente --> en_comite: asesor_transmitir_pendientes
    en_comite --> desembolsado: fn_desembolsar_solicitud
    desembolsado --> [*]
    pendiente --> rechazado: comité
    en_comite --> rechazado: comité
```

## Diagrama de clases (dominio banking — app clientes)

```mermaid
classDiagram
    class BankingRepository {
        +fetchAccounts()
        +fetchLoans()
        +fetchInstallments()
        +fetchMovements()
        +payInstallment()
        +transfer()
    }
    class BankAccount {
        +id
        +numeroCuenta
        +saldo
    }
    class LoanProduct {
        +capitalPendiente
        +cuotaMensual
    }
    class Installment {
        +nroCuota
        +estadoCuota
    }
    BankingRepository --> BankAccount
    BankingRepository --> LoanProduct
    BankingRepository --> Installment
```

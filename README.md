# APP Fuerza de Ventas — Financiera SURGIR

Ecosistema digital para asesores en campo: app móvil Flutter, portal web React y backend integrado con Supabase.

## Componentes

| Carpeta | Descripción |
|---------|-------------|
| [`Aplicacion banco 2/`](Aplicacion%20banco%202/) | App móvil Flutter — cartera, solicitudes, buró, transmisión |
| [`Surgir/`](Surgir/) | Portal web React + Vite — panel del asesor en navegador |
| [`mobile_backend_core_andino_fastapi-main/`](mobile_backend_core_andino_fastapi-main/) | API FastAPI — puente al núcleo central |
| [`database/`](database/) | Scripts SQL Supabase (migraciones y RPC) |
| [`docs/`](docs/) | Requisitos, historias de usuario y diagramas |

## Configuración rápida

### 1. Base de datos (Supabase)

Ejecuta los scripts en `database/supabase/` según el orden en [`database/supabase/README.md`](database/supabase/README.md).

### 2. App móvil Flutter

```bash
cd "Aplicacion banco 2"
cp .env.example .env   # completa SUPABASE_URL y SUPABASE_ANON_KEY
flutter pub get
flutter run
```

### 3. Portal web

```bash
cd Surgir
cp .env.example .env   # mismas credenciales Supabase
npm install
npm run dev
```

### 4. Backend (opcional)

```bash
cd mobile_backend_core_andino_fastapi-main
docker compose up
```

## Módulos principales

- Cartera del día y planificación de ruta
- Registro de clientes y nueva solicitud de crédito
- Simulador y pre-evaluación / buró de crédito
- Captura de documentos y transmisión electrónica
- Cobranza, campañas y reportes de productividad

## Stack

Flutter · React · Vite · Supabase · FastAPI · PostgreSQL

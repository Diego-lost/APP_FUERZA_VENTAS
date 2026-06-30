import { Routes, Route, Navigate } from 'react-router-dom'
import PrivateRoute from './components/layout/PrivateRoute.jsx'
import Header from './components/layout/Header.jsx'

import LoginPage from './pages/LoginPage.jsx'
import DashboardPage from './pages/DashboardPage.jsx'
import CarteraPage from './pages/CarteraPage.jsx'
import FichaClientePage from './pages/FichaClientePage.jsx'
import SolicitudesPage from './pages/SolicitudesPage.jsx'
import NuevaSolicitudPage from './pages/NuevaSolicitudPage.jsx'
import EvaluacionPage from './pages/EvaluacionPage.jsx'
import CobranzaPage from './pages/CobranzaPage.jsx'
import ReportesPage from './pages/ReportesPage.jsx'
import NuevoClientePage from './pages/NuevoClientePage.jsx'
import NuevoAsesorPage from './pages/NuevoAsesorPage.jsx'
import SimuladorPage from './pages/SimuladorPage.jsx'
import DocumentosPage from './pages/DocumentosPage.jsx'
import TransmisionPage from './pages/TransmisionPage.jsx'
import CampanasPage from './pages/CampanasPage.jsx'
import RolesPage from './pages/RolesPage.jsx'
import RutaPage from './pages/RutaPage.jsx'

// Layout de las rutas autenticadas: cabecera + pestañas + contenido.
function PrivateLayout({ children }) {
  return (
    <PrivateRoute>
      <Header />
      <main className="cm-main">
        <div className="cm-container">{children}</div>
      </main>
    </PrivateRoute>
  )
}

export default function App() {
  return (
    <Routes>
      {/* Público */}
      <Route path="/login" element={<LoginPage />} />

      {/* Privado */}
      <Route path="/inicio" element={<PrivateLayout><DashboardPage /></PrivateLayout>} />
      <Route path="/cartera" element={<PrivateLayout><CarteraPage /></PrivateLayout>} />
      <Route path="/clientes/:clienteId/ficha" element={<PrivateLayout><FichaClientePage /></PrivateLayout>} />
      <Route path="/solicitudes" element={<PrivateLayout><SolicitudesPage /></PrivateLayout>} />
      <Route path="/solicitudes/nueva" element={<PrivateLayout><NuevaSolicitudPage /></PrivateLayout>} />
      <Route path="/evaluacion" element={<PrivateLayout><EvaluacionPage /></PrivateLayout>} />
      <Route path="/cobranza" element={<PrivateLayout><CobranzaPage /></PrivateLayout>} />
      <Route path="/reportes" element={<PrivateLayout><ReportesPage /></PrivateLayout>} />
      <Route path="/clientes/nuevo" element={<PrivateLayout><NuevoClientePage /></PrivateLayout>} />
      <Route path="/asesores/nuevo" element={<PrivateLayout><NuevoAsesorPage /></PrivateLayout>} />
      <Route path="/ruta" element={<PrivateLayout><RutaPage /></PrivateLayout>} />
      <Route path="/simulador" element={<PrivateLayout><SimuladorPage /></PrivateLayout>} />
      <Route path="/documentos" element={<PrivateLayout><DocumentosPage /></PrivateLayout>} />
      <Route path="/transmision" element={<PrivateLayout><TransmisionPage /></PrivateLayout>} />
      <Route path="/campanas" element={<PrivateLayout><CampanasPage /></PrivateLayout>} />
      <Route path="/roles" element={<PrivateLayout><RolesPage /></PrivateLayout>} />

      <Route path="/" element={<Navigate to="/inicio" replace />} />
      <Route path="*" element={<Navigate to="/inicio" replace />} />
    </Routes>
  )
}

import { useState, useEffect } from 'react'
import { Shield, RefreshCw, CheckCircle2, XCircle } from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Card from '../components/ui/Card.jsx'
import Loader from '../components/ui/Loader.jsx'
import Alert from '../components/ui/Alert.jsx'
import { obtenerPerfilRbac } from '../services/fventasService.js'
import { extractError, humanizar } from '../utils/format.js'

const PERMISO_LABELS = {
  cartera_clientes: 'Ver cartera de clientes',
  originar_credito: 'Originar solicitudes de crédito',
  consulta_buro: 'Consulta de buró',
  transmision_expediente: 'Transmisión de expediente',
  reportes_productividad: 'Reportes de productividad (supervisor)',
  administracion: 'Administración del sistema',
}

export default function RolesPage() {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const cargar = () => {
    setLoading(true)
    setError(null)
    obtenerPerfilRbac()
      .then((raw) => {
        if (raw?.ok !== true) {
          throw new Error(
            raw?.error === 'no_auth' ? 'No autenticado.' : 'Acceso denegado.',
          )
        }
        setData(raw)
      })
      .catch((err) => setError(extractError(err)))
      .finally(() => setLoading(false))
  }

  useEffect(() => { cargar() }, [])

  const permisos = data?.permisos ? Object.entries(data.permisos) : []
  const matriz = data?.matriz || []

  return (
    <>
      <PageHead
        title="Roles y permisos (RBAC)"
        subtitle="Perfil validado por Supabase Auth — misma matriz que la app móvil."
        icon={Shield}
        actions={
          <button className="hb-btn hb-btn-gray hb-btn-sm" onClick={cargar}>
            <RefreshCw size={15} /> Actualizar
          </button>
        }
      />
      {error && <Alert tipo="error">{error}</Alert>}

      {loading ? (
        <Loader text="Cargando permisos…" />
      ) : data && (
        <>
          <Card title="Tu sesión" icon={Shield}>
            <strong style={{ fontSize: 16 }}>
              {data.nombres} {data.apellidos}
            </strong>
            <p style={{ color: 'var(--hb-muted)', margin: '6px 0 0' }}>
              Código {data.codigo} · Perfil: {humanizar(data.perfil)}
            </p>
            <p style={{ fontSize: 12, color: 'var(--hb-muted)', marginTop: 8 }}>
              Sesión JWT validada por Supabase Auth en el portal web.
            </p>
          </Card>

          <Card title="Tus permisos" style={{ marginTop: 16 }}>
            {permisos.length === 0 ? (
              <p style={{ color: 'var(--hb-muted)' }}>Sin permisos configurados.</p>
            ) : (
              <ul style={{ listStyle: 'none', margin: 0, padding: 0 }}>
                {permisos.map(([key, val]) => (
                  <li
                    key={key}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 10,
                      padding: '10px 0',
                      borderBottom: '1px solid var(--hb-border)',
                    }}
                  >
                    {val ? (
                      <CheckCircle2 size={18} color="#16a34a" />
                    ) : (
                      <XCircle size={18} color="#f87171" />
                    )}
                    <span style={{ flex: 1 }}>{PERMISO_LABELS[key] || key}</span>
                    <span style={{ fontSize: 12, fontWeight: 600, color: val ? '#16a34a' : '#ef4444' }}>
                      {val ? 'Permitido' : 'Denegado'}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </Card>

          <Card title="Matriz de roles (backend)" style={{ marginTop: 16 }}>
            {matriz.length === 0 ? (
              <p style={{ color: 'var(--hb-muted)' }}>Sin datos de matriz.</p>
            ) : (
              matriz.map((row, i) => (
                <div
                  key={i}
                  style={{
                    padding: '12px 0',
                    borderBottom: i < matriz.length - 1 ? '1px solid var(--hb-border)' : 'none',
                  }}
                >
                  <strong>{row.rol || '—'}</strong>
                  <div style={{ fontSize: 13, color: 'var(--hb-muted)', marginTop: 4 }}>
                    Reportes: {row.reportes ? 'Sí' : 'No'} · Admin: {row.admin ? 'Sí' : 'No'}
                  </div>
                </div>
              ))
            )}
          </Card>
        </>
      )}
    </>
  )
}

import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { Route, MapPin, RefreshCw, ExternalLink } from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Loader from '../components/ui/Loader.jsx'
import Alert from '../components/ui/Alert.jsx'
import Badge from '../components/ui/Badge.jsx'
import Money from '../components/ui/Money.jsx'
import { listarCartera } from '../services/carteraService.js'
import { extractError, humanizar } from '../utils/format.js'

function mapsUrl(stop) {
  if (stop.lat && stop.lng) {
    return `https://www.google.com/maps/search/?api=1&query=${stop.lat},${stop.lng}`
  }
  const q = encodeURIComponent(`${stop.direccion || stop.distrito || stop.cliente_nombre}, Peru`)
  return `https://www.google.com/maps/search/?api=1&query=${q}`
}

export default function RutaPage() {
  const navigate = useNavigate()
  const [stops, setStops] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const cargar = () => {
    setLoading(true)
    setError(null)
    listarCartera()
      .then((data) => setStops(data || []))
      .catch((err) => setError(extractError(err)))
      .finally(() => setLoading(false))
  }

  useEffect(() => { cargar() }, [])

  return (
    <>
      <PageHead
        title="Planificación de ruta"
        subtitle="Paradas del día ordenadas por prioridad (misma fuente que la app)."
        icon={Route}
        actions={
          <button className="hb-btn hb-btn-gray hb-btn-sm" onClick={cargar}>
            <RefreshCw size={15} /> Actualizar
          </button>
        }
      />
      {error && <Alert tipo="error">{error}</Alert>}

      {loading ? (
        <Loader text="Cargando ruta del día…" />
      ) : stops.length === 0 ? (
        <div className="hb-card hb-table-empty">No hay paradas programadas para hoy.</div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {stops.map((stop, idx) => (
            <div key={stop.id} className="hb-card" style={{ padding: 16 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
                <div>
                  <div style={{ fontSize: 12, color: 'var(--hb-muted)', marginBottom: 4 }}>
                    Parada {idx + 1} · Score {stop.score_prioridad}
                  </div>
                  <strong style={{ fontSize: 16 }}>{stop.cliente_nombre}</strong>
                  <div style={{ fontSize: 13, color: 'var(--hb-muted)', marginTop: 4 }}>
                    DNI {stop.documento} · {humanizar(stop.tipo_gestion)}
                    {stop.es_nueva_solicitud && (
                      <Badge estado="pendiente" style={{ marginLeft: 8 }}>Nueva solicitud</Badge>
                    )}
                  </div>
                  {stop.distrito && (
                    <div style={{ fontSize: 13, marginTop: 4 }}>
                      <MapPin size={13} style={{ verticalAlign: -2 }} /> {stop.distrito}
                    </div>
                  )}
                  {stop.solicitud_monto > 0 && (
                    <div style={{ fontSize: 13, marginTop: 4 }}>
                      Solicitud: <Money value={stop.solicitud_monto} /> · {stop.solicitud_plazo} meses
                    </div>
                  )}
                </div>
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'flex-start' }}>
                  <a
                    className="hb-btn hb-btn-gray hb-btn-sm"
                    href={mapsUrl(stop)}
                    target="_blank"
                    rel="noreferrer"
                  >
                    <ExternalLink size={14} /> Maps
                  </a>
                  <button
                    className="hb-btn hb-btn-sm"
                    onClick={() => navigate(`/clientes/${stop.cliente_id}/ficha`)}
                  >
                    Ficha
                  </button>
                  <button className="hb-btn hb-btn-ghost hb-btn-sm" onClick={() => navigate('/cartera')}>
                    Gestionar visita
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  )
}

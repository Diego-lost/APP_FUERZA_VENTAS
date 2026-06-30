import { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Route, MapPin, RefreshCw, ExternalLink, CheckCircle2, ClipboardCheck,
} from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Loader from '../components/ui/Loader.jsx'
import Alert from '../components/ui/Alert.jsx'
import Badge from '../components/ui/Badge.jsx'
import Money from '../components/ui/Money.jsx'
import Modal from '../components/ui/Modal.jsx'
import { listarRuta, marcarVisita } from '../services/carteraService.js'
import { extractError, humanizar } from '../utils/format.js'

const RESULTADOS = [
  { v: 'visitado', l: 'Visitado' },
  { v: 'no_encontrado', l: 'No encontrado' },
  { v: 'reagendado', l: 'Reagendado' },
  { v: 'negocio_cerrado', l: 'Negocio cerrado' },
]

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
  const [ok, setOk] = useState(null)
  const [target, setTarget] = useState(null)
  const [resultado, setResultado] = useState('visitado')
  const [observacion, setObservacion] = useState('')
  const [saving, setSaving] = useState(false)

  const cargar = useCallback(() => {
    setLoading(true)
    setError(null)
    listarRuta()
      .then((data) => setStops(data || []))
      .catch((err) => setError(extractError(err)))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => { cargar() }, [cargar])

  const abrirGestion = (stop) => {
    setTarget(stop)
    setResultado('visitado')
    setObservacion('')
    setOk(null)
  }

  const guardar = async () => {
    if (!target) return
    setSaving(true)
    setError(null)
    try {
      await marcarVisita(target.id, { resultado, observacion })
      setStops((prev) => prev.filter((s) => s.id !== target.id))
      setOk(`Visita de ${target.cliente_nombre} registrada. Eliminado de la planificación de ruta.`)
      setTarget(null)
    } catch (err) {
      setError(extractError(err))
    } finally {
      setSaving(false)
    }
  }

  return (
    <>
      <PageHead
        title="Planificación de ruta"
        subtitle="Paradas con ubicación GPS de tu cartera del día. Al gestionar, desaparecen de la ruta."
        icon={Route}
        actions={
          <button className="hb-btn hb-btn-gray hb-btn-sm" onClick={cargar}>
            <RefreshCw size={15} /> Actualizar
          </button>
        }
      />
      {error && <Alert tipo="error">{error}</Alert>}
      {ok && <Alert tipo="success">{ok}</Alert>}

      {loading ? (
        <Loader text="Cargando ruta del día…" />
      ) : stops.length === 0 ? (
        <div className="hb-card hb-table-empty">
          No hay paradas con ubicación GPS pendientes. Registra clientes con coordenadas o gestiona visitas desde Cartera del día.
        </div>
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
                    {stop.es_nuevo_cliente && (
                      <Badge estado="pendiente" style={{ marginLeft: 8 }} label="Nuevo cliente" />
                    )}
                    {stop.es_nueva_solicitud && (
                      <Badge estado="pendiente" style={{ marginLeft: 8 }} label="Nueva solicitud" />
                    )}
                    {stop.es_credito_aprobado && (
                      <Badge estado="aprobado" tone="green" style={{ marginLeft: 8 }} label="Visita desembolso" />
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
                  <button className="hb-btn hb-btn-sm" onClick={() => abrirGestion(stop)}>
                    <ClipboardCheck size={14} /> Gestionar
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {target && (
        <Modal
          title={`Gestionar visita · ${target.cliente_nombre}`}
          icon={MapPin}
          onClose={() => setTarget(null)}
          footer={
            <>
              <button className="hb-btn hb-btn-gray" onClick={() => setTarget(null)}>Cancelar</button>
              <button className="hb-btn" onClick={guardar} disabled={saving}>
                <CheckCircle2 size={16} /> {saving ? 'Guardando…' : 'Confirmar gestión'}
              </button>
            </>
          }
        >
          <p style={{ fontSize: 13, color: 'var(--hb-muted)', marginTop: 0 }}>
            Al confirmar, el cliente desaparece de la planificación de ruta y de la cartera del día.
          </p>
          <div className="hb-field">
            <label>Resultado de la visita</label>
            <div className="cm-chips">
              {RESULTADOS.map((r) => (
                <button
                  key={r.v}
                  type="button"
                  className={`cm-chip ${resultado === r.v ? 'sel' : ''}`}
                  onClick={() => setResultado(r.v)}
                >
                  {r.l}
                </button>
              ))}
            </div>
          </div>
          <div className="hb-field" style={{ marginBottom: 0 }}>
            <label htmlFor="obs-ruta">Observación</label>
            <textarea
              id="obs-ruta"
              className="hb-textarea"
              placeholder="Detalle de la gestión (opcional)…"
              value={observacion}
              onChange={(e) => setObservacion(e.target.value)}
            />
          </div>
        </Modal>
      )}
    </>
  )
}

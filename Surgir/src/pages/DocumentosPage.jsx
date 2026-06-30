import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { Camera } from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Card from '../components/ui/Card.jsx'
import Alert from '../components/ui/Alert.jsx'
import Loader from '../components/ui/Loader.jsx'
import { listarCartera } from '../services/carteraService.js'
import { registrarDocumento, listarDocumentosCliente } from '../services/fventasService.js'
import { extractError, formatDateTime, humanizar } from '../utils/format.js'

const TIPOS = [
  { v: 'dni_frontal', l: 'DNI frontal' },
  { v: 'dni_posterior', l: 'DNI posterior' },
  { v: 'foto_negocio', l: 'Foto del negocio' },
  { v: 'recibo_servicio', l: 'Recibo de servicio' },
  { v: 'contrato_alquiler', l: 'Contrato de alquiler' },
  { v: 'otro', l: 'Otro documento' },
]

export default function DocumentosPage() {
  const navigate = useNavigate()
  const [clientes, setClientes] = useState([])
  const [clienteId, setClienteId] = useState('')
  const [tipo, setTipo] = useState('dni_frontal')
  const [referencia, setReferencia] = useState('')
  const [obs, setObs] = useState('')
  const [recent, setRecent] = useState([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState(null)
  const [ok, setOk] = useState(null)

  useEffect(() => {
    listarCartera()
      .then((data) => setClientes(data || []))
      .catch((err) => setError(extractError(err)))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => {
    if (!clienteId) {
      setRecent([])
      return
    }
    listarDocumentosCliente(clienteId)
      .then(setRecent)
      .catch(() => setRecent([]))
  }, [clienteId])

  const submit = async (e) => {
    e.preventDefault()
    setError(null)
    setOk(null)
    if (!clienteId) {
      setError('Selecciona un cliente.')
      return
    }
    setSaving(true)
    try {
      await registrarDocumento({
        userId: clienteId,
        tipo,
        referencia: referencia.trim() || `Captura web ${new Date().toISOString()}`,
        observaciones: obs.trim() || null,
      })
      setOk('Documento registrado. Transmítelo desde el módulo de transmisión.')
      setReferencia('')
      setObs('')
      setRecent(await listarDocumentosCliente(clienteId))
    } catch (err) {
      setError(extractError(err))
    } finally {
      setSaving(false)
    }
  }

  const clienteSel = clientes.find((c) => c.cliente_id === clienteId)

  return (
    <>
      <PageHead
        title="Captura de documentos"
        subtitle="Registra documentos del expediente (equivalente a captura en campo)."
        icon={Camera}
      />
      {error && <Alert tipo="error">{error}</Alert>}
      {ok && <Alert tipo="success">{ok}</Alert>}

      {loading ? (
        <Loader text="Cargando clientes…" />
      ) : (
        <Card title="Nuevo documento" icon={Camera}>
          <form onSubmit={submit} className="hb-grid-2">
            <div className="hb-field" style={{ gridColumn: '1 / -1' }}>
              <label>Cliente *</label>
              <select className="hb-input" value={clienteId} onChange={(e) => setClienteId(e.target.value)}>
                <option value="">— Seleccionar —</option>
                {clientes.map((c) => (
                  <option key={c.cliente_id} value={c.cliente_id}>
                    {c.cliente_nombre} · DNI {c.documento}
                  </option>
                ))}
              </select>
              {clienteSel && (
                <button
                  type="button"
                  className="hb-btn hb-btn-ghost hb-btn-sm"
                  style={{ marginTop: 8 }}
                  onClick={() => navigate(`/clientes/${clienteSel.cliente_id}/ficha`)}
                >
                  Ver ficha
                </button>
              )}
            </div>
            <div className="hb-field">
              <label>Tipo de documento</label>
              <select className="hb-input" value={tipo} onChange={(e) => setTipo(e.target.value)}>
                {TIPOS.map((t) => <option key={t.v} value={t.v}>{t.l}</option>)}
              </select>
            </div>
            <div className="hb-field">
              <label>Referencia / archivo</label>
              <input className="hb-input" placeholder="Nombre o URL del archivo" value={referencia} onChange={(e) => setReferencia(e.target.value)} />
            </div>
            <div className="hb-field" style={{ gridColumn: '1 / -1' }}>
              <label>Observaciones</label>
              <textarea className="hb-textarea" value={obs} onChange={(e) => setObs(e.target.value)} />
            </div>
            <div style={{ gridColumn: '1 / -1' }}>
              <button className="hb-btn" type="submit" disabled={saving}>
                <Camera size={16} /> {saving ? 'Guardando…' : 'Registrar documento'}
              </button>
            </div>
          </form>

          {recent.length > 0 && (
            <>
              <h3 style={{ marginTop: 24, fontSize: 15 }}>Últimos documentos</h3>
              <div className="hb-table-wrap">
                <table className="hb-table">
                  <thead>
                    <tr>
                      <th>Tipo</th>
                      <th>Referencia</th>
                      <th>Estado</th>
                      <th>Fecha</th>
                    </tr>
                  </thead>
                  <tbody>
                    {recent.map((d) => (
                      <tr key={d.id}>
                        <td>{humanizar(d.tipo)}</td>
                        <td>{d.referencia || '—'}</td>
                        <td>{d.estado || 'pendiente'}</td>
                        <td>{formatDateTime(d.created_at)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          )}
        </Card>
      )}
    </>
  )
}

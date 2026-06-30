import { useState } from 'react'
import { Gavel } from 'lucide-react'
import Modal from './ui/Modal.jsx'
import Alert from './ui/Alert.jsx'
import Money from './ui/Money.jsx'
import { responderSolicitud } from '../services/fventasService.js'
import { extractError } from '../utils/format.js'

const DECISIONES = [
  { id: 'aprobar', label: 'Aprobar', desc: 'Aprueba la solicitud; el desembolso se hace en Transmisión' },
  { id: 'aprobar_monto_reducido', label: 'Aprobar monto reducido', desc: 'Aprueba un monto menor; desembolso en Transmisión' },
  { id: 'elevar_comite', label: 'Elevar a comité', desc: 'Requiere revisión del comité' },
  { id: 'rechazar', label: 'Rechazar', desc: 'No procede la solicitud' },
]

export default function SolicitudDecisionModal({ solicitud, onClose, onSuccess }) {
  const [decision, setDecision] = useState('aprobar')
  const [obs, setObs] = useState('')
  const [montoAjustado, setMontoAjustado] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  if (!solicitud) return null

  const submit = async () => {
    setError(null)
    setLoading(true)
    try {
      const monto =
        decision === 'aprobar_monto_reducido'
          ? Number(String(montoAjustado).replace(',', '.'))
          : undefined
      if (decision === 'aprobar_monto_reducido') {
        if (!monto || monto <= 0 || monto >= solicitud.monto_solicitado) {
          throw new Error('Indica un monto menor al solicitado.')
        }
      }
      const res = await responderSolicitud({
        solicitudId: solicitud.id,
        decision,
        observaciones: obs.trim() || null,
        montoAjustado: monto,
      })
      onSuccess?.(res)
      onClose()
    } catch (err) {
      setError(extractError(err))
    } finally {
      setLoading(false)
    }
  }

  return (
    <Modal title="Decisión del asesor" icon={Gavel} onClose={onClose}>
      <p style={{ marginTop: 0, color: 'var(--hb-muted)' }}>
        {solicitud.cliente_nombre} · <Money value={solicitud.monto_solicitado} /> ·{' '}
        {solicitud.plazo_meses || '—'} meses
      </p>
      {error && <Alert tipo="error">{error}</Alert>}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 14 }}>
        {DECISIONES.map((d) => (
          <label
            key={d.id}
            style={{
              display: 'flex',
              gap: 10,
              padding: '10px 12px',
              borderRadius: 10,
              border: `1px solid ${decision === d.id ? '#e30613' : 'var(--hb-border)'}`,
              background: decision === d.id ? '#fff5f5' : 'var(--hb-bg)',
              cursor: 'pointer',
            }}
          >
            <input
              type="radio"
              name="decision"
              checked={decision === d.id}
              onChange={() => setDecision(d.id)}
            />
            <span>
              <strong>{d.label}</strong>
              <div style={{ fontSize: 12, color: 'var(--hb-muted)' }}>{d.desc}</div>
            </span>
          </label>
        ))}
      </div>
      {decision === 'aprobar_monto_reducido' && (
        <div className="hb-field">
          <label>Monto aprobado (S/)</label>
          <input
            className="hb-input"
            inputMode="decimal"
            placeholder={`Menor a ${solicitud.monto_solicitado}`}
            value={montoAjustado}
            onChange={(e) => setMontoAjustado(e.target.value)}
          />
        </div>
      )}
      <div className="hb-field">
        <label>Observaciones (opcional)</label>
        <textarea className="hb-textarea" value={obs} onChange={(e) => setObs(e.target.value)} />
      </div>
      <button className="hb-btn" onClick={submit} disabled={loading}>
        <Gavel size={16} /> {loading ? 'Guardando…' : 'Confirmar decisión'}
      </button>
    </Modal>
  )
}

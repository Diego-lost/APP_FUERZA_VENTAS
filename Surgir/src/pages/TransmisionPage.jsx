import { useState, useEffect } from 'react'
import { CloudUpload, RefreshCw, Banknote, FileText } from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Card from '../components/ui/Card.jsx'
import Alert from '../components/ui/Alert.jsx'
import Loader from '../components/ui/Loader.jsx'
import Badge from '../components/ui/Badge.jsx'
import Money from '../components/ui/Money.jsx'
import { desembolsarSolicitudes, transmitirPendientes, listarDocumentosPendientes } from '../services/fventasService.js'
import { listarSolicitudes } from '../services/solicitudesService.js'
import { extractError, formatDate } from '../utils/format.js'

export default function TransmisionPage() {
  const [loading, setLoading] = useState(true)
  const [txLoading, setTxLoading] = useState(false)
  const [desembolsoLoading, setDesembolsoLoading] = useState(false)
  const [aprobadas, setAprobadas] = useState([])
  const [documentos, setDocumentos] = useState([])
  const [seleccionadas, setSeleccionadas] = useState(new Set())
  const [error, setError] = useState(null)
  const [result, setResult] = useState(null)

  const cargar = async () => {
    setLoading(true)
    setError(null)
    try {
      const [sols, docs] = await Promise.all([
        listarSolicitudes(),
        listarDocumentosPendientes(),
      ])
      const aprob = (sols || []).filter((s) => s.estado === 'aprobado')
      setAprobadas(aprob)
      setDocumentos(docs || [])
      setSeleccionadas(new Set(aprob.map((s) => s.id)))
    } catch (err) {
      setError(extractError(err))
    } finally {
      setLoading(false)
    }
  }

  const toggle = (id) => {
    setSeleccionadas((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const toggleTodas = () => {
    if (seleccionadas.size === aprobadas.length) {
      setSeleccionadas(new Set())
    } else {
      setSeleccionadas(new Set(aprobadas.map((s) => s.id)))
    }
  }

  const desembolsar = async () => {
    const ids = [...seleccionadas]
    if (!ids.length) {
      setError('Selecciona al menos una solicitud aprobada.')
      return
    }
    setDesembolsoLoading(true)
    setError(null)
    setResult(null)
    try {
      const res = await desembolsarSolicitudes(ids)
      setResult(res)
      await cargar()
    } catch (err) {
      setError(extractError(err))
    } finally {
      setDesembolsoLoading(false)
    }
  }

  const transmitirDocs = async () => {
    setTxLoading(true)
    setError(null)
    try {
      const res = await transmitirPendientes()
      setResult(res)
      await cargar()
    } catch (err) {
      setError(extractError(err))
    } finally {
      setTxLoading(false)
    }
  }

  useEffect(() => { cargar() }, [])

  return (
    <>
      <PageHead
        title="Transmisión electrónica"
        subtitle="Desembolsa las solicitudes aprobadas que elijas y transmite documentos al sistema central."
        icon={CloudUpload}
        actions={
          <button className="hb-btn hb-btn-gray hb-btn-sm" onClick={cargar}>
            <RefreshCw size={15} /> Actualizar
          </button>
        }
      />

      {error && <Alert tipo="error">{error}</Alert>}
      {result && (
        <Alert tipo="success">
          {result.desembolsos_ok != null && (
            <>Desembolsados: {result.desembolsos_ok} solicitud(es).
            {result.desembolsos_fallidos > 0 && ` Fallidos: ${result.desembolsos_fallidos}.`}</>
          )}
          {result.documentos_transmitidos != null && result.desembolsos_ok == null && (
            <>Documentos transmitidos: {result.documentos_transmitidos}.</>
          )}
        </Alert>
      )}

      <Card title="Solicitudes aprobadas — desembolso" icon={Banknote}>
        {loading ? (
          <Loader text="Cargando…" />
        ) : aprobadas.length === 0 ? (
          <p style={{ color: 'var(--hb-muted)' }}>
            No hay solicitudes en estado <strong>Aprobado</strong>. Evalúa solicitudes pendientes primero.
          </p>
        ) : (
          <>
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12, cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={seleccionadas.size === aprobadas.length && aprobadas.length > 0}
                onChange={toggleTodas}
              />
              <span>Seleccionar todas ({aprobadas.length})</span>
            </label>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {aprobadas.map((s) => (
                <label
                  key={s.id}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 12,
                    padding: '12px 14px',
                    borderRadius: 10,
                    border: '1px solid var(--hb-border)',
                    background: seleccionadas.has(s.id) ? '#fff5f5' : 'var(--hb-bg)',
                    cursor: 'pointer',
                  }}
                >
                  <input
                    type="checkbox"
                    checked={seleccionadas.has(s.id)}
                    onChange={() => toggle(s.id)}
                  />
                  <div style={{ flex: 1 }}>
                    <strong>{s.cliente_nombre}</strong>
                    <div style={{ fontSize: 13, color: 'var(--hb-muted)' }}>
                      <Money value={s.monto_aprobado || s.monto_solicitado} /> · {s.plazo_meses || '—'} meses · {formatDate(s.created_at)}
                    </div>
                  </div>
                  <Badge estado="aprobado" />
                </label>
              ))}
            </div>
            <button
              className="hb-btn"
              style={{ marginTop: 16 }}
              onClick={desembolsar}
              disabled={desembolsoLoading || seleccionadas.size === 0}
            >
              <Banknote size={16} />
              {desembolsoLoading
                ? 'Desembolsando…'
                : `Desembolsar seleccionados (${seleccionadas.size})`}
            </button>
          </>
        )}
      </Card>

      <Card title="Documentos capturados" icon={FileText} style={{ marginTop: 16 }}>
        {loading ? (
          <Loader text="Cargando…" />
        ) : documentos.length === 0 ? (
          <p style={{ color: 'var(--hb-muted)' }}>No hay documentos pendientes de transmisión.</p>
        ) : (
          <ul style={{ margin: 0, paddingLeft: 18 }}>
            {documentos.map((d) => (
              <li key={d.id} style={{ marginBottom: 8 }}>
                <strong>{d.tipo}</strong> — {d.cliente_nombre || 'Cliente'}
              </li>
            ))}
          </ul>
        )}
        <button
          className="hb-btn hb-btn-gray"
          style={{ marginTop: 16 }}
          onClick={transmitirDocs}
          disabled={txLoading || documentos.length === 0}
        >
          <CloudUpload size={16} />
          {txLoading ? 'Transmitiendo…' : 'Transmitir documentos'}
        </button>
      </Card>
    </>
  )
}

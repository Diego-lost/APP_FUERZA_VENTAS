import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import {
  ArrowLeft, UserCircle2, Phone, MapPin, Store, BadgeCheck,
  Wallet, History, Gift, Activity, PlusCircle, Gavel,
} from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Card from '../components/ui/Card.jsx'
import Loader from '../components/ui/Loader.jsx'
import Alert from '../components/ui/Alert.jsx'
import Badge from '../components/ui/Badge.jsx'
import Money from '../components/ui/Money.jsx'
import SolicitudDecisionModal from '../components/SolicitudDecisionModal.jsx'
import { obtenerFicha } from '../services/clientesService.js'
import { listarSolicitudes } from '../services/solicitudesService.js'
import { extractError, formatPct, formatDate, humanizar } from '../utils/format.js'

export default function FichaClientePage() {
  const { clienteId } = useParams()
  const navigate = useNavigate()
  const [ficha, setFicha] = useState(null)
  const [solicitudes, setSolicitudes] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [evaluarDe, setEvaluarDe] = useState(null)
  const [okMsg, setOkMsg] = useState(null)

  useEffect(() => {
    let alive = true
    setLoading(true)
    Promise.all([obtenerFicha(clienteId), listarSolicitudes()])
      .then(([data, sols]) => {
        if (!alive) return
        setFicha(data)
        setSolicitudes((sols || []).filter((s) => s.user_id === clienteId))
      })
      .catch((err) => alive && setError(extractError(err)))
      .finally(() => alive && setLoading(false))
    return () => { alive = false }
  }, [clienteId])

  if (loading) return <Loader text="Cargando ficha del cliente…" />
  if (error) return <Alert tipo="error">{error}</Alert>
  if (!ficha) return null

  const { cliente, posicion, historial = [], oferta, indicadores, cuentas = [] } = ficha
  const nombre = `${cliente.nombres} ${cliente.apellidos}`.trim()

  const irNuevaSolicitud = () => {
    navigate('/solicitudes/nueva', {
      state: {
        numero_documento: cliente.numero_documento,
        nombres: cliente.nombres,
        apellidos: cliente.apellidos,
        telefono: cliente.telefono,
        tipo_negocio: cliente.tipo_negocio,
        nombre_negocio: cliente.nombre_negocio,
      },
    })
  }

  const pendienteEval = solicitudes.find((s) => ['enviado', 'pendiente'].includes(s.estado))

  return (
    <>
      <button className="cm-back" onClick={() => navigate(-1)}><ArrowLeft size={16} /> Volver</button>

      {okMsg && <Alert tipo="success">{okMsg}</Alert>}

      <PageHead
        title={nombre}
        subtitle={`DNI ${cliente.numero_documento}`}
        icon={UserCircle2}
        actions={
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {pendienteEval && (
              <button className="hb-btn hb-btn-gray" onClick={() => setEvaluarDe(pendienteEval)}>
                <Gavel size={16} /> Evaluar solicitud
              </button>
            )}
            <button className="hb-btn" onClick={irNuevaSolicitud}>
              <PlusCircle size={16} /> Nueva solicitud
            </button>
          </div>
        }
      />

      <div className="hb-grid-2" style={{ alignItems: 'start' }}>
        <Card title="Datos del cliente" icon={BadgeCheck}>
          <dl className="cm-dl">
            <div><dt>Calificación SBS</dt><dd><Badge estado={cliente.calificacion_sbs} /></dd></div>
            <div><dt><Phone size={12} style={{ verticalAlign: -1 }} /> Teléfono</dt><dd>{cliente.telefono || '—'}</dd></div>
            <div><dt><Store size={12} style={{ verticalAlign: -1 }} /> Negocio</dt><dd>{cliente.nombre_negocio || '—'}</dd></div>
            <div><dt>Tipo de negocio</dt><dd>{humanizar(cliente.tipo_negocio) || '—'}</dd></div>
            <div><dt>Antigüedad negocio</dt><dd>{cliente.antiguedad_negocio_meses != null ? `${cliente.antiguedad_negocio_meses} meses` : '—'}</dd></div>
            <div style={{ gridColumn: '1 / -1' }}><dt><MapPin size={12} style={{ verticalAlign: -1 }} /> Dirección</dt><dd style={{ fontWeight: 500, fontSize: 14 }}>{cliente.direccion || '—'}</dd></div>
          </dl>
        </Card>

        <Card title="Posición consolidada" icon={Wallet}>
          <div className="cm-kpis" style={{ marginBottom: 0, gridTemplateColumns: '1fr 1fr' }}>
            <div className="cm-kpi" style={{ borderLeftColor: '#e2132b' }}>
              <div>
                <div className="cm-kpi-label">Deuda pendiente</div>
                <span className="cm-kpi-val" style={{ fontSize: 20 }}><Money value={posicion?.deuda_total} /></span>
              </div>
            </div>
            <div className="cm-kpi" style={{ borderLeftColor: '#2563eb' }}>
              <div>
                <div className="cm-kpi-label">Saldo en cuentas</div>
                <span className="cm-kpi-val" style={{ fontSize: 20 }}><Money value={posicion?.saldo_cuentas} /></span>
              </div>
            </div>
            <div className="cm-kpi" style={{ borderLeftColor: '#00a9a5' }}>
              <div>
                <div className="cm-kpi-label">Créditos al día</div>
                <span className="cm-kpi-val">{posicion?.cuentas_vigentes ?? 0}</span>
              </div>
            </div>
            <div className="cm-kpi" style={{ borderLeftColor: '#8e24aa' }}>
              <div>
                <div className="cm-kpi-label">Mayor mora</div>
                <span className="cm-kpi-val">{posicion?.dias_mayor_mora ?? 0}<small style={{ fontSize: 13 }}> días</small></span>
              </div>
            </div>
          </div>
        </Card>
      </div>

      {cuentas.length > 0 && (
        <Card title="Cuentas del cliente" icon={Wallet} style={{ marginTop: 16 }}>
          <div className="hb-table-wrap">
            <table className="hb-table">
              <thead>
                <tr>
                  <th>Cuenta</th>
                  <th>Tipo</th>
                  <th className="num">Saldo</th>
                </tr>
              </thead>
              <tbody>
                {cuentas.map((c) => (
                  <tr key={c.id}>
                    <td>{c.numero_cuenta}</td>
                    <td>{humanizar(c.tipo)}</td>
                    <td className="num"><Money value={c.saldo} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      {oferta && (
        <Card title="Oferta pre-aprobada" icon={Gift} style={{ marginTop: 16, borderColor: '#bfe3c8', background: '#f6fbf7' }}>
          <dl className="cm-dl">
            <div><dt>Monto máximo</dt><dd><Money value={oferta.monto_maximo} /></dd></div>
            <div><dt>Plazo sugerido</dt><dd>{oferta.plazo_sugerido_meses ? `${oferta.plazo_sugerido_meses} meses` : '—'}</dd></div>
            <div><dt>TEA referencial</dt><dd>{formatPct(oferta.tea_referencial)}</dd></div>
            <div><dt>Confianza</dt><dd>{oferta.score_confianza}/100</dd></div>
            <div><dt>Vence</dt><dd style={{ fontSize: 14 }}>{formatDate(oferta.fecha_vencimiento)}</dd></div>
          </dl>
        </Card>
      )}

      {indicadores && (
        <Card title="Comportamiento de pago" icon={Activity} style={{ marginTop: 16 }}>
          <dl className="cm-dl">
            <div><dt>Cuotas puntuales</dt><dd>{formatPct(indicadores.pct_puntual)}</dd></div>
            <div><dt>Mora promedio</dt><dd>{indicadores.dias_prom_mora} días</dd></div>
            <div><dt>Total pagado</dt><dd><Money value={indicadores.monto_pagado} /></dd></div>
          </dl>
        </Card>
      )}

      <Card title="Historial de créditos" icon={History} style={{ marginTop: 16 }}>
        {historial.length === 0 ? (
          <p className="hb-table-empty" style={{ margin: 0 }}>Sin créditos registrados.</p>
        ) : (
          <div className="hb-table-wrap">
            <table className="hb-table">
              <thead>
                <tr>
                  <th>Producto</th>
                  <th className="num">Desembolsado</th>
                  <th className="num">Saldo pendiente</th>
                  <th className="num">Plazo</th>
                  <th className="num">TEA</th>
                  <th className="num">Cuotas</th>
                  <th className="num">Mora</th>
                  <th>Estado</th>
                </tr>
              </thead>
              <tbody>
                {historial.map((h, i) => (
                  <tr key={i}>
                    <td>{humanizar(h.producto) || 'Crédito'}</td>
                    <td className="num"><Money value={h.monto_desembolsado} /></td>
                    <td className="num"><Money value={h.saldo_pendiente} /></td>
                    <td className="num">{h.plazo_meses ?? '—'} m</td>
                    <td className="num">{formatPct(h.tea)}</td>
                    <td className="num">{h.cuotas_pagadas}/{h.cuotas_total}</td>
                    <td className="num">{h.dias_mora} d</td>
                    <td><Badge estado={h.estado} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {evaluarDe && (
        <SolicitudDecisionModal
          solicitud={evaluarDe}
          onClose={() => setEvaluarDe(null)}
          onSuccess={(res) => {
            setOkMsg(
              res.desembolsado
                ? `Desembolsado S/ ${Number(res.monto).toFixed(2)} — el cliente verá el saldo en su app.`
                : 'Decisión registrada.',
            )
            listarSolicitudes().then((sols) => {
              setSolicitudes((sols || []).filter((s) => s.user_id === clienteId))
            })
            obtenerFicha(clienteId).then(setFicha)
          }}
        />
      )}
    </>
  )
}

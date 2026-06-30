import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { Megaphone, RefreshCw, TrendingUp, RefreshCcw } from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Loader from '../components/ui/Loader.jsx'
import Alert from '../components/ui/Alert.jsx'
import Money from '../components/ui/Money.jsx'
import { listarCampanas } from '../services/fventasService.js'
import { extractError } from '../utils/format.js'

function mapCampana(row) {
  const pc = row.perfiles_clientes || {}
  const monto = Number(row.saldo_pendiente ?? row.monto_aprobado) || 0
  const segmento = String(row.segmento || '').toUpperCase()
  const tipo = monto >= 8000 || segmento.includes('PLUS') ? 'ampliacion' : 'renovacion'
  const nombre = `${pc.nombres ?? ''} ${pc.apellidos ?? ''}`.trim() || 'Cliente'
  return {
    id: row.id,
    userId: row.user_id,
    clienteNombre: nombre,
    dni: pc.dni || '',
    tipo,
    tipoLabel: tipo === 'ampliacion' ? 'Ampliación' : 'Renovación',
    montoOfertado: tipo === 'ampliacion' ? monto * 1.25 : monto,
    diasRestantes: 15 + Math.round(monto % 10),
  }
}

export default function CampanasPage() {
  const navigate = useNavigate()
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const cargar = () => {
    setLoading(true)
    setError(null)
    listarCampanas()
      .then((rows) => setItems(rows.map(mapCampana)))
      .catch((err) => setError(extractError(err)))
      .finally(() => setLoading(false))
  }

  useEffect(() => { cargar() }, [])

  return (
    <>
      <PageHead
        title="Campañas activas"
        subtitle="Ofertas de renovación y ampliación para clientes al día."
        icon={Megaphone}
        actions={
          <button className="hb-btn hb-btn-gray hb-btn-sm" onClick={cargar}>
            <RefreshCw size={15} /> Actualizar
          </button>
        }
      />
      {error && <Alert tipo="error">{error}</Alert>}

      {loading ? (
        <Loader text="Cargando campañas…" />
      ) : items.length === 0 ? (
        <div className="hb-card hb-table-empty">No hay campañas activas en tu cartera.</div>
      ) : (
        <div className="cm-quick-grid">
          {items.map((o) => {
            const Icon = o.tipo === 'ampliacion' ? TrendingUp : RefreshCcw
            const color = o.tipo === 'ampliacion' ? '#7c3aed' : '#0d9488'
            return (
              <button
                key={o.id}
                className="cm-quick"
                onClick={() => navigate(`/clientes/${o.userId}/ficha`)}
              >
                <span className="cm-quick-ico" style={{ background: `${color}1a`, color }}>
                  <Icon size={24} />
                </span>
                <div style={{ flex: 1, textAlign: 'left' }}>
                  <h3>{o.clienteNombre}</h3>
                  <p>
                    {o.tipoLabel} · DNI {o.dni}<br />
                    Oferta <Money value={o.montoOfertado} /> · {o.diasRestantes} días restantes
                  </p>
                </div>
              </button>
            )
          })}
        </div>
      )}
    </>
  )
}

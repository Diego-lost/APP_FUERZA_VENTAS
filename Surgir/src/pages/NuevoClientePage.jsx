import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { UserPlus, MapPin, CheckCircle2 } from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Card from '../components/ui/Card.jsx'
import Alert from '../components/ui/Alert.jsx'
import { registrarCliente } from '../services/fventasService.js'
import { extractError } from '../utils/format.js'

export default function NuevoClientePage() {
  const navigate = useNavigate()
  const [f, setF] = useState({
    dni: '',
    nombres: '',
    apellidos: '',
    telefono: '',
    nombre_negocio: '',
    distrito: '',
    direccion: '',
    lat: '',
    lng: '',
    antiguedad_meses: '12',
    ingresos: '2000',
    gastos: '900',
    password: 'Cliente2026!',
  })
  const [error, setError] = useState(null)
  const [done, setDone] = useState(null)
  const [saving, setSaving] = useState(false)

  const set = (k) => (e) => setF((s) => ({ ...s, [k]: e.target.value }))

  const usarUbicacion = () => {
    if (!navigator.geolocation) {
      setError('Tu navegador no soporta geolocalización.')
      return
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setF((s) => ({
          ...s,
          lat: String(pos.coords.latitude.toFixed(6)),
          lng: String(pos.coords.longitude.toFixed(6)),
        }))
        setError(null)
      },
      () => setError('No se pudo obtener la ubicación. Ingresa lat/lng manualmente.'),
    )
  }

  const onSubmit = async (e) => {
    e.preventDefault()
    setError(null)
    if (!/^\d{8}$/.test(f.dni.trim())) {
      setError('DNI inválido (8 dígitos).')
      return
    }
    if (!f.nombres.trim() || !f.apellidos.trim()) {
      setError('Nombres y apellidos son obligatorios.')
      return
    }
    const lat = Number(f.lat)
    const lng = Number(f.lng)
    if (!lat || !lng) {
      setError('Indica la ubicación del negocio (botón "Usar mi ubicación" o lat/lng).')
      return
    }

    setSaving(true)
    try {
      const res = await registrarCliente({
        dni: f.dni.trim(),
        nombres: f.nombres.trim(),
        apellidos: f.apellidos.trim(),
        telefono: f.telefono.trim() || null,
        nombre_negocio: f.nombre_negocio.trim() || null,
        distrito: f.distrito.trim() || null,
        direccion: f.direccion.trim() || null,
        lat,
        lng,
        antiguedad_meses: parseInt(f.antiguedad_meses, 10) || 12,
        ingresos: Number(f.ingresos) || 2000,
        gastos: Number(f.gastos) || 900,
        password: f.password,
      })
      setDone({ userId: res.user_id, dni: f.dni.trim() })
    } catch (err) {
      setError(extractError(err))
    } finally {
      setSaving(false)
    }
  }

  if (done) {
    return (
      <>
        <PageHead title="Cliente registrado" icon={CheckCircle2} />
        <Alert tipo="success">
          Cliente DNI {done.dni} creado. Puede iniciar sesión en la app Clientes con su DNI y contraseña.
        </Alert>
        <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
          <button className="hb-btn" onClick={() => navigate(`/clientes/${done.userId}/ficha`)}>
            Ver ficha del cliente
          </button>
          <button className="hb-btn hb-btn-gray" onClick={() => { setDone(null); setF((s) => ({ ...s, dni: '' })) }}>
            Registrar otro
          </button>
        </div>
      </>
    )
  }

  return (
    <>
      <PageHead
        title="Nuevo cliente"
        subtitle="Registro en campo con ubicación del negocio (mismo flujo que la app móvil)."
        icon={UserPlus}
      />
      {error && <Alert tipo="error">{error}</Alert>}

      <Card title="Datos del cliente" icon={UserPlus}>
        <form onSubmit={onSubmit} className="hb-grid-2">
          <div className="hb-field">
            <label>DNI *</label>
            <input className="hb-input" maxLength={8} value={f.dni} onChange={set('dni')} />
          </div>
          <div className="hb-field">
            <label>Teléfono</label>
            <input className="hb-input" value={f.telefono} onChange={set('telefono')} />
          </div>
          <div className="hb-field">
            <label>Nombres *</label>
            <input className="hb-input" value={f.nombres} onChange={set('nombres')} />
          </div>
          <div className="hb-field">
            <label>Apellidos *</label>
            <input className="hb-input" value={f.apellidos} onChange={set('apellidos')} />
          </div>
          <div className="hb-field">
            <label>Nombre del negocio</label>
            <input className="hb-input" value={f.nombre_negocio} onChange={set('nombre_negocio')} />
          </div>
          <div className="hb-field">
            <label>Distrito</label>
            <input className="hb-input" value={f.distrito} onChange={set('distrito')} />
          </div>
          <div className="hb-field" style={{ gridColumn: '1 / -1' }}>
            <label>Dirección del negocio</label>
            <input className="hb-input" value={f.direccion} onChange={set('direccion')} />
          </div>

          <div className="hb-field" style={{ gridColumn: '1 / -1' }}>
            <label><MapPin size={14} style={{ verticalAlign: -2 }} /> Ubicación GPS *</label>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
              <input className="hb-input" style={{ width: 140 }} placeholder="Latitud" value={f.lat} onChange={set('lat')} />
              <input className="hb-input" style={{ width: 140 }} placeholder="Longitud" value={f.lng} onChange={set('lng')} />
              <button type="button" className="hb-btn hb-btn-gray hb-btn-sm" onClick={usarUbicacion}>
                Usar mi ubicación
              </button>
              {f.lat && f.lng && (
                <a
                  className="hb-btn hb-btn-ghost hb-btn-sm"
                  href={`https://www.google.com/maps/search/?api=1&query=${f.lat},${f.lng}`}
                  target="_blank"
                  rel="noreferrer"
                >
                  Ver en mapa
                </a>
              )}
            </div>
          </div>

          <div className="hb-field">
            <label>Antigüedad (meses)</label>
            <input className="hb-input" type="number" value={f.antiguedad_meses} onChange={set('antiguedad_meses')} />
          </div>
          <div className="hb-field">
            <label>Ingresos mensuales (S/)</label>
            <input className="hb-input" type="number" value={f.ingresos} onChange={set('ingresos')} />
          </div>
          <div className="hb-field">
            <label>Gastos mensuales (S/)</label>
            <input className="hb-input" type="number" value={f.gastos} onChange={set('gastos')} />
          </div>
          <div className="hb-field">
            <label>Contraseña inicial</label>
            <input className="hb-input" type="password" value={f.password} onChange={set('password')} />
          </div>

          <div style={{ gridColumn: '1 / -1' }}>
            <button className="hb-btn" type="submit" disabled={saving}>
              <UserPlus size={16} /> {saving ? 'Registrando…' : 'Registrar cliente'}
            </button>
          </div>
        </form>
      </Card>
    </>
  )
}

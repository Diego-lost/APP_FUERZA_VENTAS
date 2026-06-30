import { useState, useEffect } from 'react'
import { BadgePlus } from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Card from '../components/ui/Card.jsx'
import Alert from '../components/ui/Alert.jsx'
import Loader from '../components/ui/Loader.jsx'
import { crearAsesor, listarAgencias } from '../services/fventasService.js'
import { extractError, humanizar } from '../utils/format.js'

const NIVELES = ['Junior I', 'Junior II', 'Senior I', 'Senior II']
const PERFILES = ['operador', 'super_operador', 'supervisor', 'administrador']

export default function NuevoAsesorPage() {
  const [agencias, setAgencias] = useState([])
  const [loadingAg, setLoadingAg] = useState(true)
  const [accessError, setAccessError] = useState(null)
  const [f, setF] = useState({
    codigo: '',
    nombres: '',
    apellidos: '',
    email: '',
    telefono: '',
    dni: '',
    id_agencia: '',
    nivel: 'Junior I',
    perfil: 'operador',
    password: 'Asesor2026!',
  })
  const [error, setError] = useState(null)
  const [ok, setOk] = useState(null)
  const [saving, setSaving] = useState(false)

  const set = (k) => (e) => setF((s) => ({ ...s, [k]: e.target.value }))

  useEffect(() => {
    listarAgencias()
      .then((ags) => {
        setAgencias(ags)
        if (ags.length) setF((s) => ({ ...s, id_agencia: String(ags[0].id) }))
      })
      .catch((err) => {
        const msg = extractError(err)
        setAccessError(
          msg.includes('sin_permiso')
            ? 'Solo administradores pueden crear asesores.'
            : msg,
        )
      })
      .finally(() => setLoadingAg(false))
  }, [])

  const onSubmit = async (e) => {
    e.preventDefault()
    setError(null)
    setOk(null)
    if (!f.codigo.trim() || !f.nombres.trim() || !f.apellidos.trim() || !f.email.trim()) {
      setError('Completa código, nombres, apellidos y email.')
      return
    }
    setSaving(true)
    try {
      const res = await crearAsesor({
        codigo: f.codigo.trim(),
        nombres: f.nombres.trim(),
        apellidos: f.apellidos.trim(),
        email: f.email.trim(),
        telefono: f.telefono.trim() || null,
        dni: f.dni.trim() || null,
        id_agencia: Number(f.id_agencia),
        nivel: f.nivel,
        perfil: f.perfil,
        password: f.password,
      })
      setOk(`Asesor ${res.codigo || f.codigo} creado. Login: código + contraseña.`)
    } catch (err) {
      setError(extractError(err))
    } finally {
      setSaving(false)
    }
  }

  if (loadingAg) return <Loader text="Cargando agencias…" />

  return (
    <>
      <PageHead
        title="Nuevo asesor"
        subtitle="Alta de personal de fuerza de ventas (requiere perfil administrador)."
        icon={BadgePlus}
      />
      {accessError && <Alert tipo="warn">{accessError}</Alert>}
      {error && <Alert tipo="error">{error}</Alert>}
      {ok && <Alert tipo="success">{ok}</Alert>}

      <Card title="Datos del asesor" icon={BadgePlus}>
        <form onSubmit={onSubmit} className="hb-grid-2">
          <div className="hb-field">
            <label>Código empleado *</label>
            <input className="hb-input" placeholder="AG-001-02" value={f.codigo} onChange={set('codigo')} />
          </div>
          <div className="hb-field">
            <label>Email *</label>
            <input className="hb-input" type="email" value={f.email} onChange={set('email')} />
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
            <label>Teléfono</label>
            <input className="hb-input" value={f.telefono} onChange={set('telefono')} />
          </div>
          <div className="hb-field">
            <label>DNI</label>
            <input className="hb-input" maxLength={8} value={f.dni} onChange={set('dni')} />
          </div>
          <div className="hb-field">
            <label>Agencia *</label>
            <select className="hb-input" value={f.id_agencia} onChange={set('id_agencia')} disabled={!agencias.length}>
              {agencias.map((a) => (
                <option key={a.id} value={a.id}>{a.nombre || a.codigo || `Agencia ${a.id}`}</option>
              ))}
            </select>
          </div>
          <div className="hb-field">
            <label>Nivel</label>
            <select className="hb-input" value={f.nivel} onChange={set('nivel')}>
              {NIVELES.map((n) => <option key={n} value={n}>{n}</option>)}
            </select>
          </div>
          <div className="hb-field">
            <label>Perfil RBAC</label>
            <select className="hb-input" value={f.perfil} onChange={set('perfil')}>
              {PERFILES.map((p) => <option key={p} value={p}>{humanizar(p)}</option>)}
            </select>
          </div>
          <div className="hb-field">
            <label>Contraseña inicial</label>
            <input className="hb-input" type="password" value={f.password} onChange={set('password')} />
          </div>
          <div style={{ gridColumn: '1 / -1' }}>
            <button className="hb-btn" type="submit" disabled={saving || !!accessError}>
              <BadgePlus size={16} /> {saving ? 'Creando…' : 'Crear asesor'}
            </button>
          </div>
        </form>
      </Card>
    </>
  )
}

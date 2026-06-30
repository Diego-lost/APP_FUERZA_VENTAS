import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Target, Eye, HeartHandshake, Route, ShieldCheck,
  User, Lock, LogIn, ChevronLeft, ChevronRight,
} from 'lucide-react'
import Logo from '../components/ui/Logo.jsx'
import Alert from '../components/ui/Alert.jsx'
import { useAuth } from '../context/AuthContext.jsx'
import { extractError } from '../utils/format.js'

// Carrusel institucional — Financiera SURGIR.
const SLIDES = [
  {
    tag: 'FINANCIERA SURGIR',
    icon: Target,
    titulo: 'Misión',
    desc: 'Impulsar el crecimiento de microempresarios peruanos con crédito responsable, cercano y accesible.',
    pills: ['Inclusión', 'Cercanía', 'Responsabilidad'],
  },
  {
    tag: 'FINANCIERA SURGIR',
    icon: Eye,
    titulo: 'Visión',
    desc: 'Ser la financiera de referencia para emprendedores, reconocida por acompañar a cada cliente en su camino al éxito.',
    pills: ['Confianza', 'Innovación', 'Crecimiento'],
  },
  {
    tag: 'NUESTROS VALORES',
    icon: HeartHandshake,
    titulo: 'Valores',
    desc: 'Integridad en cada gestión, respeto por las personas y compromiso con el desarrollo de las comunidades.',
    pills: ['Integridad', 'Respeto', 'Compromiso'],
  },
  {
    tag: 'FUERZA DE VENTAS',
    icon: Route,
    titulo: 'En el campo',
    desc: 'Cartera del día, evaluaciones crediticias, solicitudes y cobranza en un solo portal para el asesor SURGIR.',
    pills: ['Cartera', 'Evaluación', 'Cobranza'],
  },
]

export default function LoginPage() {
  const { login, isAuthenticated } = useAuth()
  const navigate = useNavigate()
  const [codigo, setCodigo] = useState('')
  const [password, setPassword] = useState('')
  const [recordar, setRecordar] = useState(true)
  const [error, setError] = useState(null)
  const [loading, setLoading] = useState(false)
  const [slide, setSlide] = useState(0)

  // Si ya hay sesión, va directo al panel.
  useEffect(() => {
    if (isAuthenticated) navigate('/inicio', { replace: true })
  }, [isAuthenticated, navigate])

  // Auto-rotación del carrusel.
  useEffect(() => {
    const id = setInterval(() => setSlide((s) => (s + 1) % SLIDES.length), 6000)
    return () => clearInterval(id)
  }, [])

  const onSubmit = async (e) => {
    e.preventDefault()
    setError(null)
    if (!codigo.trim() || !password) {
      setError('Ingresa tu código de asesor y contraseña.')
      return
    }
    setLoading(true)
    try {
      await login(codigo.trim(), password)
      navigate('/inicio', { replace: true })
    } catch (err) {
      setError(extractError(err, 'No se pudo iniciar sesión.'))
    } finally {
      setLoading(false)
    }
  }

  const s = SLIDES[slide]
  const SlideIcon = s.icon
  const prev = () => setSlide((v) => (v - 1 + SLIDES.length) % SLIDES.length)
  const next = () => setSlide((v) => (v + 1) % SLIDES.length)

  return (
    <div className="cm-login">
      {/* Cabecera flotante */}
      <div className="cm-login-topbar">
        <Logo size={40} variant="dark" subtitle="FUERZA DE VENTAS" />
        <span className="cm-login-chip">Portal interno · Asesores SURGIR</span>
      </div>

      {/* ===== Izquierda: carrusel "Nuestra esencia" ===== */}
      <section className="cm-hero">
        <span className="cm-hero-blob b1" />
        <span className="cm-hero-blob b2" />
        <button className="cm-hero-arrow left" onClick={prev} aria-label="Anterior"><ChevronLeft size={22} /></button>
        <button className="cm-hero-arrow right" onClick={next} aria-label="Siguiente"><ChevronRight size={22} /></button>

        <div className="cm-hero-inner">
          <span className="cm-hero-tag">{s.tag}</span>
          <div className="cm-hero-icon"><SlideIcon size={62} strokeWidth={1.5} /></div>
          <h1>{s.titulo}</h1>
          <p>{s.desc}</p>
          <div className="cm-hero-pills">
            {s.pills.map((p) => <span key={p} className="cm-hero-pill">{p}</span>)}
          </div>
        </div>

        <div className="cm-hero-dots">
          {SLIDES.map((_, i) => (
            <button
              key={i}
              className={`cm-hero-dot ${i === slide ? 'active' : ''}`}
              onClick={() => setSlide(i)}
              aria-label={`Ir al slide ${i + 1}`}
            />
          ))}
        </div>
      </section>

      {/* ===== Derecha: formulario de acceso ===== */}
      <section className="cm-auth">
        <span className="cm-auth-blob a1" />
        <span className="cm-auth-blob a2" />
        <div className="cm-auth-inner">
          <span className="cm-secure"><ShieldCheck size={15} /> Conexión segura</span>
          <h2>Inicia sesión</h2>
          <p className="cm-auth-lead">Acceso de asesores · ingresa con tu código.</p>

          <Alert tipo="error">{error}</Alert>

          <form onSubmit={onSubmit}>
            <div className="cm-field">
              <label htmlFor="codigo">Código de asesor</label>
              <div className="cm-input-wrap">
                <User size={18} />
                <input
                  id="codigo"
                  placeholder="Ej. AG-001-01"
                  autoComplete="username"
                  inputMode="numeric"
                  value={codigo}
                  onChange={(e) => setCodigo(e.target.value)}
                  autoFocus
                />
              </div>
            </div>

            <div className="cm-field">
              <label htmlFor="password">Contraseña</label>
              <div className="cm-input-wrap">
                <Lock size={18} />
                <input
                  id="password"
                  type="password"
                  placeholder="Tu contraseña"
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
              </div>
            </div>

            <div className="cm-auth-row">
              <label className="cm-check">
                <input type="checkbox" checked={recordar} onChange={(e) => setRecordar(e.target.checked)} />
                Recordarme
              </label>
              <button type="button" className="cm-link" onClick={(e) => e.preventDefault()}>
                ¿Olvidó su contraseña?
              </button>
            </div>

            <button type="submit" className="cm-submit" disabled={loading}>
              <LogIn size={18} />
              {loading ? 'Ingresando…' : 'Iniciar sesión'}
            </button>
          </form>

          <p className="cm-auth-hint">
            Demo · código <strong>AG-001-01</strong> · clave <strong>Asesor2026!</strong>
          </p>
        </div>
      </section>
    </div>
  )
}

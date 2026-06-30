import { AlertTriangle } from 'lucide-react'
import Logo from '../components/ui/Logo.jsx'

export default function SupabaseConfigPage({ issues = [] }) {
  return (
    <div style={{
      minHeight: '100vh',
      display: 'grid',
      placeItems: 'center',
      padding: 24,
      background: '#f8f9fb',
      fontFamily: '"Segoe UI", Roboto, Arial, sans-serif',
    }}
    >
      <div style={{
        maxWidth: 520,
        width: '100%',
        background: '#fff',
        borderRadius: 16,
        border: '1px solid #e2e5ea',
        boxShadow: '0 4px 24px rgba(16,24,40,.08)',
        padding: 28,
      }}
      >
        <Logo size={44} subtitle="FUERZA DE VENTAS" />
        <div style={{
          display: 'flex', alignItems: 'center', gap: 10,
          marginTop: 24, marginBottom: 12, color: '#b45309',
        }}
        >
          <AlertTriangle size={22} />
          <h1 style={{ margin: 0, fontSize: 20, color: '#1a1d21' }}>
            Configuración incompleta
          </h1>
        </div>
        <p style={{ margin: '0 0 16px', color: '#5c6370', lineHeight: 1.5 }}>
          La app no puede conectar con Supabase. En <strong>Vercel</strong> agrega estas
          variables en <em>Settings → Environment Variables</em> y vuelve a desplegar:
        </p>
        <ul style={{ margin: '0 0 16px', paddingLeft: 20, color: '#374151', lineHeight: 1.6 }}>
          {issues.map((issue) => <li key={issue}>{issue}</li>)}
        </ul>
        <pre style={{
          background: '#f3f4f6',
          borderRadius: 10,
          padding: 14,
          fontSize: 13,
          overflow: 'auto',
          margin: '0 0 16px',
        }}
        >
{`VITE_SUPABASE_URL=https://xxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJ...`}
        </pre>
        <p style={{ margin: 0, fontSize: 13, color: '#6b7280' }}>
          Usa las mismas credenciales que en <code>.env</code> local o en la app Flutter.
          Después de guardarlas, haz <strong>Redeploy</strong> en Vercel.
        </p>
      </div>
    </div>
  )
}

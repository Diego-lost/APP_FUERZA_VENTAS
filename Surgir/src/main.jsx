import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import App from './App.jsx'
import { AuthProvider } from './context/AuthContext.jsx'
import SupabaseConfigPage from './pages/SupabaseConfigPage.jsx'
import { getSupabaseConfigIssues, isSupabaseConfigured } from './lib/supabaseConfig.js'
import './index.css'

const root = ReactDOM.createRoot(document.getElementById('root'))

if (!isSupabaseConfigured) {
  root.render(<SupabaseConfigPage issues={getSupabaseConfigIssues()} />)
} else {
  root.render(
    <React.StrictMode>
      <BrowserRouter>
        <AuthProvider>
          <App />
        </AuthProvider>
      </BrowserRouter>
    </React.StrictMode>,
  )
}

import { createContext, useContext, useState, useCallback, useMemo, useEffect } from 'react'
import { supabase } from '../lib/supabase.js'
import * as authService from '../services/authService.js'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [token, setToken] = useState(() => authService.getStoredToken())
  const [user, setUser] = useState(() => authService.getStoredUser())
  const [booting, setBooting] = useState(true)

  useEffect(() => {
    let alive = true

    authService.restoreSession()
      .then((session) => {
        if (!alive) return
        if (session) {
          authService.saveSession(session.token, session.user)
          setToken(session.token)
          setUser(session.user)
        } else {
          authService.clearSession()
          setToken(null)
          setUser(null)
        }
      })
      .catch(() => {
        if (!alive) return
        authService.clearSession()
        setToken(null)
        setUser(null)
      })
      .finally(() => {
        if (alive) setBooting(false)
      })

    if (!supabase) return undefined

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (!alive) return
      if (!session) {
        authService.clearSession()
        setToken(null)
        setUser(null)
      }
    })

    return () => {
      alive = false
      subscription.unsubscribe()
    }
  }, [])

  const login = useCallback(async (codigoEmpleado, password) => {
    const { token: newToken, user: newUser } = await authService.login(codigoEmpleado, password)
    authService.saveSession(newToken, newUser)
    setToken(newToken)
    setUser(newUser)
    return newUser
  }, [])

  const logout = useCallback(async () => {
    await authService.logout()
    setToken(null)
    setUser(null)
  }, [])

  const value = useMemo(
    () => ({
      user,
      token,
      booting,
      isAuthenticated: Boolean(token),
      login,
      logout,
    }),
    [user, token, booting, login, logout],
  )

  if (booting) {
    return (
      <div style={{
        minHeight: '100vh', display: 'grid', placeItems: 'center',
        background: '#f8f9fb', color: '#5c6370', fontWeight: 600,
      }}
      >
        Cargando sesión…
      </div>
    )
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth debe usarse dentro de <AuthProvider>')
  return ctx
}

export default useAuth

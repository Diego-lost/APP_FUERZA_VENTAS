import { supabase, supabaseError } from '../lib/supabase.js'

export const TOKEN_KEY = 'cm_token'
export const USER_KEY = 'cm_user'

async function fetchAdvisorProfile() {
  const { data: raw, error } = await supabase.rpc('get_resumen_cartera_asesor')
  if (error) throw new Error(supabaseError(error))
  if (!raw?.ok) throw new Error(raw?.error || 'asesor_no_encontrado')

  return {
    id: null,
    codigo_empleado: raw.codigo,
    nombres: raw.nombres ?? '',
    apellidos: raw.apellidos ?? '',
    nombre: `${raw.nombres ?? ''} ${raw.apellidos ?? ''}`.trim() || raw.codigo,
    perfil: raw.nivel ?? 'operador',
    agencia_id: null,
    zona: raw.zona_asignada,
    total_clientes: raw.total_clientes,
    clientes_en_mora: raw.clientes_en_mora,
  }
}

/** Login asesor: código + contraseña → sesión Supabase (igual que la app Flutter). */
export async function login(codigoEmpleado, password) {
  const { data: email, error: rpcError } = await supabase.rpc(
    'get_asesor_email_by_codigo',
    { p_codigo: codigoEmpleado.trim() },
  )
  if (rpcError) throw new Error(supabaseError(rpcError))
  if (!email) {
    throw new Error('No encontramos un asesor activo con ese código.')
  }

  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email: String(email).trim(),
    password,
  })
  if (authError) {
    const msg = authError.message?.toLowerCase() || ''
    if (msg.includes('invalid') || msg.includes('credentials')) {
      throw new Error('Contraseña incorrecta. Para asesores de prueba usa: Asesor2026!')
    }
    throw new Error(supabaseError(authError))
  }

  const token = authData.session?.access_token
  const user = await fetchAdvisorProfile()
  user.codigo_empleado = user.codigo_empleado || codigoEmpleado.trim()

  return { token, user }
}

/** Restaura sesión Supabase al recargar la página. */
export async function restoreSession() {
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) return null

  try {
    const user = await fetchAdvisorProfile()
    return { token: session.access_token, user }
  } catch {
    await supabase.auth.signOut()
    return null
  }
}

export function saveSession(token, user) {
  localStorage.setItem(TOKEN_KEY, token)
  localStorage.setItem(USER_KEY, JSON.stringify(user))
}

export function clearSession() {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(USER_KEY)
}

export function getStoredToken() {
  return localStorage.getItem(TOKEN_KEY)
}

export function getStoredUser() {
  try {
    const raw = localStorage.getItem(USER_KEY)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

export async function logout() {
  await supabase.auth.signOut()
  clearSession()
}

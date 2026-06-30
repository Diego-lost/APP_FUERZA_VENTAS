export const supabaseUrl = (import.meta.env.VITE_SUPABASE_URL || '').trim()
export const supabaseAnonKey = (import.meta.env.VITE_SUPABASE_ANON_KEY || '').trim()

export function getSupabaseConfigIssues() {
  const issues = []
  if (!supabaseUrl) {
    issues.push('Falta VITE_SUPABASE_URL (Project URL de Supabase).')
  } else if (!/^https?:\/\//i.test(supabaseUrl)) {
    issues.push('VITE_SUPABASE_URL debe ser una URL válida (https://xxx.supabase.co).')
  }
  if (!supabaseAnonKey) {
    issues.push('Falta VITE_SUPABASE_ANON_KEY (anon public key, empieza con eyJ...).')
  } else if (!supabaseAnonKey.startsWith('eyJ')) {
    issues.push('VITE_SUPABASE_ANON_KEY no tiene formato válido (debe empezar con eyJ).')
  }
  return issues
}

export const isSupabaseConfigured = getSupabaseConfigIssues().length === 0

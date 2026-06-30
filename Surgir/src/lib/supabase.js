import { createClient } from '@supabase/supabase-js'
import { isSupabaseConfigured, supabaseAnonKey, supabaseUrl } from './supabaseConfig.js'

export { isSupabaseConfigured, getSupabaseConfigIssues } from './supabaseConfig.js'

export const supabase = isSupabaseConfigured
  ? createClient(supabaseUrl, supabaseAnonKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: false,
    },
  })
  : null

export function supabaseError(err, fallback = 'Ocurrió un error. Intente nuevamente.') {
  if (!err) return fallback
  if (typeof err === 'string') return err
  return err.message || err.error_description || fallback
}

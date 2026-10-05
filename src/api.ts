import { createClient } from '@supabase/supabase-js'

// Clé "publishable" : prévue pour être publique. Les règles et la sécurité
// (mains cachées, tour de jeu, validité des coups) sont appliquées dans la base.
const SUPABASE_URL = 'https://pgdmtokjwevqmvorujgs.supabase.co'
const SUPABASE_KEY = 'sb_publishable_raG6hGktoPEhiYepyxKQzA_nMLz1eWS'

export const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, {
  auth: { persistSession: false },
})

export type Player = { id: string; name: string; seat: number; count: number; active: boolean }

export type LogEvent = {
  k: 'create' | 'join' | 'start' | 'play' | 'draw' | 'keep' | 'reshuffle' | 'empty' | 'leave' | 'win' | 'lobby' | 'penalty'
  p?: string
  c?: string
  n?: number
  left?: number
  playable?: boolean
  t: number
}

export type GameState = {
  code: string
  status: 'lobby' | 'playing' | 'finished'
  version: number
  host_id: string
  current_seat: number | null
  phase: 'play' | 'drawn'
  winner_id: string | null
  deck_count: number
  discard_count: number
  specials_count: number
  top_commune: string | null
  top_special: string | null
  forbidden: string | null
  log: LogEvent[]
  players: Player[]
  me: { id: string; name: string; seat: number; hand: string[]; active: boolean }
  drawn_card: string | null
  playable: string[]
}

export type Session = { code: string; token: string }

async function call<T>(fn: string, args: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.rpc(fn, args)
  if (error) throw new Error(error.message || 'Erreur de connexion au serveur')
  return data as T
}

export const api = {
  createRoom: (name: string) => call<Session>('jm_create_room', { p_name: name }),
  joinRoom: (code: string, name: string) => call<Session>('jm_join_room', { p_code: code, p_name: name }),
  state: (token: string) => call<GameState>('jm_get_state', { p_token: token }),
  start: (token: string, first: string | null) => call<void>('jm_start_game', { p_token: token, p_first: first }),
  play: (token: string, card: string) => call<void>('jm_play_card', { p_token: token, p_card: card }),
  draw: (token: string) => call<{ card: string | null; playable: boolean }>('jm_draw_card', { p_token: token }),
  pass: (token: string) => call<void>('jm_pass', { p_token: token }),
  leave: (token: string) => call<void>('jm_leave_room', { p_token: token }),
  backToLobby: (token: string) => call<void>('jm_back_to_lobby', { p_token: token }),
}

// La session active est propre à l'onglet (sessionStorage) : on peut ainsi ouvrir
// plusieurs joueurs dans le même navigateur. La dernière partie est aussi gardée
// dans localStorage pour proposer « Reprendre ma partie » après fermeture de l'onglet.
const KEY = 'juramatch:session'
const LAST = 'juramatch:last'
const read = (store: Storage, key: string): Session | null => {
  try {
    const raw = store.getItem(key)
    return raw ? (JSON.parse(raw) as Session) : null
  } catch {
    return null
  }
}
export const sessionStore = {
  get: () => read(sessionStorage, KEY),
  last: () => read(localStorage, LAST),
  set(s: Session) {
    try {
      sessionStorage.setItem(KEY, JSON.stringify(s))
      localStorage.setItem(LAST, JSON.stringify(s))
    } catch { /* navigation privée */ }
  },
  clear() {
    try {
      const cur = read(sessionStorage, KEY)
      sessionStorage.removeItem(KEY)
      if (cur && read(localStorage, LAST)?.token === cur.token) localStorage.removeItem(LAST)
    } catch { /* rien */ }
  },
  forgetLast() {
    try { localStorage.removeItem(LAST) } catch { /* rien */ }
  },
}

/** S'abonne aux notifications temps réel d'une partie. Retourne la fonction de désabonnement. */
export function subscribeRoom(code: string, onUpdate: () => void) {
  const channel = supabase
    .channel('juramatch:' + code)
    .on('broadcast', { event: 'update' }, () => onUpdate())
    .subscribe()
  return () => { supabase.removeChannel(channel) }
}

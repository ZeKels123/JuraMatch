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
  k: 'create' | 'join' | 'start' | 'play' | 'draw' | 'keep' | 'reshuffle' | 'empty' | 'leave' | 'win' | 'lobby' | 'penalty' | 'question' | 'answer'
  p?: string
  q?: string
  ok?: boolean
  a?: string
  g?: string
  by?: string
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
  question: Question | null
}

export type Question = {
  by: string
  by_name: string
  target: string
  target_name: string
  text: string
  choices: string[]
  stage: 'answer' | 'pick'
}

export type Session = { code: string; token: string }

async function call<T>(fn: string, args: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.rpc(fn, args)
  if (error) throw new Error(error.message || 'Erreur de connexion au serveur')
  return data as T
}

export type ActResponse<T> = { result: T; state: GameState }
const act = <T,>(token: string, action: string, args: Record<string, unknown> = {}) =>
  call<ActResponse<T>>('jm_act', { p_token: token, p_action: action, ...args })

/** Partie publique de l'état, envoyée par le temps réel à chaque coup */
export type PublicState = Omit<GameState, 'me' | 'drawn_card' | 'playable'>

export const api = {
  createRoom: (name: string) => call<Session>('jm_create_room', { p_name: name }),
  joinRoom: (code: string, name: string) => call<Session>('jm_join_room', { p_code: code, p_name: name }),
  state: (token: string) => call<GameState>('jm_get_state', { p_token: token }),
  // Toutes les actions passent par jm_act : l'action ET le nouvel état en un seul aller-retour réseau
  start: (token: string, first: string | null) => act<null>(token, 'start', { p_target: first }),
  play: (token: string, card: string) => act<null>(token, 'play', { p_card: card }),
  draw: (token: string) => act<{ card: string | null; playable: boolean }>(token, 'draw'),
  pass: (token: string) => act<null>(token, 'pass'),
  playQuestion: (token: string, card: string, target: string) => act<null>(token, 'question', { p_card: card, p_target: target }),
  answerQuestion: (token: string, choice: number) => act<{ correct: boolean; answer: string }>(token, 'answer', { p_choice: choice }),
  questionPick: (token: string, victim: string) => act<null>(token, 'pick', { p_target: victim }),
  backToLobby: (token: string) => act<null>(token, 'lobby'),
  leave: (token: string) => call<void>('jm_leave_room', { p_token: token }),
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
export function subscribeRoom(code: string, onUpdate: (pub: PublicState | null) => void) {
  const channel = supabase
    .channel('juramatch:' + code)
    .on('broadcast', { event: 'update' }, (msg) => {
      const p = msg.payload as PublicState | undefined
      onUpdate(p && typeof p.version === 'number' && p.code ? p : null)
    })
    .subscribe()
  return () => { supabase.removeChannel(channel) }
}

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { api, sessionStore, subscribeRoom, type ActResponse, type GameState, type PublicState, type Session } from './api'
import { BACKS, CARDS, iconImg, iconLabel, isNeutralSpecial, isPlus2, isQuestion, matchReasons } from './cards'
import { QuestionPanel, TargetPicker } from './Question'
import { RulesModal } from './Rules'
import { CardZoom } from './CardZoom'
import { describeEvent } from './log'

const NAME_KEY = 'juramatch:name'
let preloaded = false
function preloadCards() {
  if (preloaded) return
  preloaded = true
  const urls = [...new Set(Object.values(CARDS).map((c) => c.img)), ...BACKS]
  let i = 0
  const next = () => {
    // 4 images à la fois, sans gêner le jeu
    for (let k = 0; k < 4 && i < urls.length; k++, i++) { const img = new Image(); img.decoding = 'async'; img.src = urls[i] }
    if (i < urls.length) window.setTimeout(next, 150)
  }
  next()
}

/** États fusionnés depuis le temps réel (main pas encore relue) */
const partial = new WeakSet<GameState>()

function readName() {
  try { return localStorage.getItem(NAME_KEY) ?? '' } catch { return '' }
}
function saveName(n: string) {
  try { localStorage.setItem(NAME_KEY, n) } catch { /* rien */ }
}

export default function App() {
  const [session, setSession] = useState<Session | null>(() => sessionStore.get())
  const [state, setState] = useState<GameState | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [showRules, setShowRules] = useState(false)
  const loading = useRef(false)
  const pending = useRef(false)

  // N'accepte un état que s'il est plus récent : évite les retours en arrière et les re-rendus inutiles
  // (« partial » = état fusionné depuis le temps réel, dont la main n'est pas encore relue)
  const optimistic = useRef(false)
  const versionRef = useRef(0)
  const apply = useCallback((s: GameState) => {
    const force = optimistic.current
    optimistic.current = false
    setState((prev) => {
      if (!force && prev && !partial.has(prev) && prev.version >= s.version && prev.status === s.status) return prev
      versionRef.current = s.version
      return s
    })
  }, [])

  const refresh = useCallback(async () => {
    if (!session) return
    if (loading.current) { pending.current = true; return }
    loading.current = true
    try {
      const s = await api.state(session.token)
      apply(s)
    } catch (e) {
      const msg = (e as Error).message
      if (msg.includes('introuvable')) {
        sessionStore.clear()
        setSession(null)
        setState(null)
      }
    } finally {
      loading.current = false
      if (pending.current) { pending.current = false; void refresh() }
    }
  }, [session, apply])

  // Temps réel : l'état public arrive directement dans la notification et s'affiche tout de suite ;
  // la main du joueur est relue ensuite (en arrière-plan, regroupé). Interrogation lente en secours.
  const refreshTimer = useRef<number | undefined>(undefined)
  const scheduleRefresh = useCallback(() => {
    window.clearTimeout(refreshTimer.current)
    refreshTimer.current = window.setTimeout(() => void refresh(), 120)
  }, [refresh])

  const onBroadcast = useCallback((pub: PublicState | null) => {
    if (!pub) { scheduleRefresh(); return }
    if (pub.version <= versionRef.current) return // déjà à jour (souvent : notre propre coup)
    versionRef.current = pub.version
    scheduleRefresh()
    setState((prev) => {
      if (!prev) return prev
      if (pub.status !== prev.status) return prev // changement d'écran : on attend l'état complet
      const myTurn = pub.status === 'playing' && pub.current_seat === prev.me.seat && !pub.question && pub.phase === 'play'
      // Cartes jouables calculées localement en attendant la réponse du serveur
      const playable = myTurn
        ? prev.me.hand.filter((h) => matchReasons(h, pub.top_commune, pub.forbidden).ok)
        : []
      const merged = { ...prev, ...pub, playable, drawn_card: myTurn ? null : prev.drawn_card }
      partial.add(merged)
      return merged
    })
  }, [scheduleRefresh])

  useEffect(() => {
    if (!session) return
    void refresh()
    const unsub = subscribeRoom(session.code, onBroadcast)
    const timer = window.setInterval(() => { if (!document.hidden) void refresh() }, 8000)
    const onVis = () => { if (!document.hidden) void refresh() }
    document.addEventListener('visibilitychange', onVis)
    return () => { unsub(); window.clearInterval(timer); document.removeEventListener('visibilitychange', onVis) }
  }, [session, refresh, onBroadcast])

  const enter = (s: Session) => {
    sessionStore.set(s)
    setSession(s)
    const url = new URL(window.location.href)
    url.searchParams.delete('code')
    window.history.replaceState(null, '', url.toString())
  }

  const leave = async () => {
    if (session) { try { await api.leave(session.token) } catch { /* déjà parti */ } }
    sessionStore.clear()
    setSession(null)
    setState(null)
  }

  /**
   * Exécute une action : l'écran peut être mis à jour tout de suite (optimiste),
   * puis le serveur renvoie le vrai nouvel état dans la même réponse.
   */
  const act = useCallback(async <T,>(fn: () => Promise<ActResponse<T>>, guess?: (s: GameState) => GameState): Promise<T | undefined> => {
    setError(null)
    if (guess) { optimistic.current = true; setState((prev) => (prev ? guess(prev) : prev)) }
    try {
      const out = await fn()
      optimistic.current = true // l'état renvoyé par l'action fait foi
      apply(out.state)
      return out.result
    } catch (e) {
      setError((e as Error).message)
      optimistic.current = true
      await refresh()
      return undefined
    }
  }, [refresh, apply])

  let screen
  if (!session) {
    screen = <Home onEnter={enter} onRules={() => setShowRules(true)} />
  } else if (!state) {
    screen = <div className="loading">Connexion à la partie {session.code}…</div>
  } else if (state.status === 'lobby') {
    screen = <Lobby state={state} token={session.token} act={act} onLeave={leave} onRules={() => setShowRules(true)} />
  } else {
    screen = <Game state={state} token={session.token} act={act} onLeave={leave} onRules={() => setShowRules(true)} />
  }

  return (
    <>
      {screen}
      {error && (
        <div className="toast toast-error" role="alert" onClick={() => setError(null)}>
          {error}
        </div>
      )}
      {showRules && <RulesModal onClose={() => setShowRules(false)} />}
    </>
  )
}

/* ------------------------------------------------------------------ */
/* Accueil                                                             */
/* ------------------------------------------------------------------ */

function Home({ onEnter, onRules }: { onEnter: (s: Session) => void; onRules: () => void }) {
  const urlCode = useMemo(() => new URLSearchParams(window.location.search).get('code')?.toUpperCase() ?? '', [])
  const [name, setName] = useState(readName)
  const [code, setCode] = useState(urlCode)
  const [busy, setBusy] = useState<'create' | 'join' | null>(null)
  const [err, setErr] = useState<string | null>(null)
  const [last, setLast] = useState<Session | null>(() => sessionStore.last())

  const resume = async () => {
    if (!last) return
    try {
      const s = await api.state(last.token)
      if (s.status === 'finished' && !s.players.some((p) => p.active && p.id === s.me.id)) throw new Error()
      onEnter(last)
    } catch {
      sessionStore.forgetLast()
      setLast(null)
      setErr('Cette partie n’existe plus.')
    }
  }

  const run = async (kind: 'create' | 'join') => {
    setErr(null)
    if (!name.trim()) { setErr('Choisis d’abord un pseudo.'); return }
    if (kind === 'join' && code.trim().length !== 5) { setErr('Le code de partie fait 5 caractères.'); return }
    setBusy(kind)
    saveName(name.trim())
    try {
      const s = kind === 'create' ? await api.createRoom(name) : await api.joinRoom(code, name)
      onEnter(s)
    } catch (e) {
      setErr((e as Error).message)
    } finally {
      setBusy(null)
    }
  }

  return (
    <main className="home">
      <div className="home-flag" aria-hidden="true">
        <img src={BACKS[0]} alt="" />
      </div>
      <section className="home-panel">
        <h1 className="wordmark">JuraMatch</h1>
        <p className="home-lede">
          Le jeu des communes jurassiennes. Pose une commune du même district ou qui partage un symbole,
          bloque tes adversaires avec les cartes Interdiction, et vide ta main le premier.
        </p>

        {last && (
          <div className="resume">
            <span>Tu étais dans la partie <strong>{last.code}</strong>.</span>
            <button className="btn btn-primary" onClick={resume}>Reprendre ma partie</button>
          </div>
        )}

        <label className="field">
          <span>Ton pseudo</span>
          <input
            value={name}
            maxLength={20}
            autoComplete="nickname"
            placeholder="ex. Kilian"
            onChange={(e) => setName(e.target.value)}
          />
        </label>

        <div className="home-actions">
          <div className="home-block">
            <h2>Nouvelle partie</h2>
            <p>Tu reçois un code à donner aux autres joueurs.</p>
            <button className="btn btn-primary" disabled={busy !== null} onClick={() => run('create')}>
              {busy === 'create' ? 'Création…' : 'Créer une partie'}
            </button>
          </div>
          <form
            className="home-block"
            onSubmit={(e) => { e.preventDefault(); void run('join') }}
          >
            <h2>Rejoindre</h2>
            <label className="field">
              <span>Code de la partie</span>
              <input
                className="code-input"
                value={code}
                maxLength={5}
                autoCapitalize="characters"
                autoComplete="off"
                spellCheck={false}
                placeholder="A7K2Q"
                onChange={(e) => setCode(e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, ''))}
                autoFocus={!!urlCode}
              />
            </label>
            <button className="btn" type="submit" disabled={busy !== null}>
              {busy === 'join' ? 'Connexion…' : 'Rejoindre la partie'}
            </button>
          </form>
        </div>
        {err && <p className="form-error" role="alert">{err}</p>}
        <button className="link" onClick={onRules}>Lire les règles</button>
      </section>
    </main>
  )
}

/* ------------------------------------------------------------------ */
/* Salon d'attente                                                     */
/* ------------------------------------------------------------------ */

type Act = <T>(fn: () => Promise<ActResponse<T>>, guess?: (s: GameState) => GameState) => Promise<T | undefined>

function Lobby({ state, token, act, onLeave, onRules }: {
  state: GameState; token: string; act: Act; onLeave: () => void; onRules: () => void
}) {
  const isHost = state.host_id === state.me.id
  const [first, setFirst] = useState<string>('random')
  const [copied, setCopied] = useState<string | null>(null)
  const players = state.players.filter((p) => p.active)
  const host = players.find((p) => p.id === state.host_id)
  const link = `${window.location.origin}${window.location.pathname}?code=${state.code}`

  const copy = async (text: string, what: string) => {
    try {
      await navigator.clipboard.writeText(text)
      setCopied(what)
      window.setTimeout(() => setCopied(null), 1800)
    } catch {
      setCopied(null)
    }
  }

  return (
    <main className="lobby">
      <header className="bar">
        <span className="bar-logo">JuraMatch</span>
        <div className="bar-actions">
          <button className="btn btn-ghost" onClick={onRules}>Règles</button>
          <button className="btn btn-ghost" onClick={onLeave}>Quitter</button>
        </div>
      </header>

      <section className="code-hero">
        <p>Donne ce code aux autres joueurs</p>
        <div className="code-tiles" aria-label={`Code ${state.code.split('').join(' ')}`}>
          {state.code.split('').map((ch, i) => <span key={i}>{ch}</span>)}
        </div>
        <div className="code-copy">
          <button className="btn btn-light" onClick={() => copy(state.code, 'code')}>
            {copied === 'code' ? 'Code copié' : 'Copier le code'}
          </button>
          <button className="btn btn-light" onClick={() => copy(link, 'link')}>
            {copied === 'link' ? 'Lien copié' : 'Copier le lien d’invitation'}
          </button>
        </div>
      </section>

      <section className="lobby-body">
        <h2>Joueurs ({players.length}/6)</h2>
        <ol className="seats">
          {Array.from({ length: 6 }).map((_, i) => {
            const p = players[i]
            return (
              <li key={i} className={p ? 'seat' : 'seat seat-empty'}>
                <img src={BACKS[i % 4]} alt="" />
                {p ? (
                  <span>
                    {p.name}
                    {p.id === state.host_id && <em> hôte</em>}
                    {p.id === state.me.id && <em> toi</em>}
                  </span>
                ) : (
                  <span>Place libre</span>
                )}
              </li>
            )
          })}
        </ol>
        <p className="muted">
          {players.length <= 4 ? '8 cartes par joueur' : '6 cartes par joueur'} — la partie se joue de 2 à 6.
        </p>

        {isHost ? (
          <div className="start-box">
            <label className="field">
              <span>Le plus jeune commence. Qui est-ce ?</span>
              <select value={first} onChange={(e) => setFirst(e.target.value)}>
                <option value="random">Tirer au sort</option>
                {players.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
              </select>
            </label>
            <button
              className="btn btn-primary btn-big"
              disabled={players.length < 2}
              onClick={() => act(() => api.start(token, first === 'random' ? null : first))}
            >
              {players.length < 2 ? 'En attente d’un 2e joueur' : 'Lancer la partie'}
            </button>
          </div>
        ) : (
          <p className="waiting">En attente que {host?.name ?? 'l’hôte'} lance la partie…</p>
        )}
      </section>
    </main>
  )
}

/* ------------------------------------------------------------------ */
/* Partie                                                              */
/* ------------------------------------------------------------------ */

function Game({ state, token, act, onLeave, onRules }: {
  state: GameState; token: string; act: Act; onLeave: () => void; onRules: () => void
}) {
  const [selected, setSelected] = useState<string | null>(null)
  const [zoom, setZoom] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [logOpen, setLogOpen] = useState(false)
  const [askWith, setAskWith] = useState<string | null>(null)
  const handRef = useRef<HTMLElement>(null)
  const [handH, setHandH] = useState(180)

  // Hauteur de la main : la carte agrandie s'affiche juste au-dessus
  useEffect(() => {
    const el = handRef.current
    if (!el) return
    const ro = new ResizeObserver(() => setHandH(el.offsetHeight))
    ro.observe(el)
    return () => ro.disconnect()
  }, [])

  const me = state.me
  const myTurn = state.status === 'playing' && state.current_seat === me.seat && me.active && !state.question
  const current = state.players.find((p) => p.seat === state.current_seat)
  const isHost = state.host_id === me.id
  const playable = new Set(state.playable)
  const others = state.players.filter((p) => p.id !== me.id)
  const deckEmpty = state.deck_count === 0

  // Précharge toutes les images de cartes en arrière-plan : une carte posée s'affiche sans attente
  useEffect(() => { preloadCards() }, [])

  // Onglet du navigateur : signale quand c'est ton tour
  useEffect(() => {
    document.title = myTurn ? '● À toi de jouer — JuraMatch' : 'JuraMatch'
    return () => { document.title = 'JuraMatch' }
  }, [myTurn])

  useEffect(() => { if (selected && !me.hand.includes(selected)) setSelected(null) }, [me.hand, selected])
  useEffect(() => {
    if (!selected) return
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') setSelected(null) }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [selected])
  useEffect(() => { if (!notice) return; const t = window.setTimeout(() => setNotice(null), 4500); return () => window.clearTimeout(t) }, [notice])

  const play = async (id: string) => {
    if (isQuestion(CARDS[id])) { setAskWith(id); return }
    setBusy(true)
    setSelected(null)
    const c = CARDS[id]
    // Affichage immédiat : la carte quitte la main et arrive sur sa pile
    await act(() => api.play(token, id), (s) => ({
      ...s,
      me: { ...s.me, hand: s.me.hand.filter((h) => h !== id) },
      top_commune: c?.kind === 'commune' ? id : s.top_commune,
      top_special: c?.kind === 'special' ? id : s.top_special,
      forbidden: c?.kind === 'special' ? (c.icons[0] ?? null) : s.forbidden,
      playable: [],
      drawn_card: null,
    }))
    setBusy(false)
  }
  const draw = async () => {
    setBusy(true)
    const r = await act(() => api.draw(token))
    if (r) {
      if (!r.card) setNotice('La pioche est vide : tu passes ton tour.')
      else if (!r.playable) setNotice(`Tu as pioché ${CARDS[r.card]?.name}. Elle ne peut pas être posée : ton tour est fini.`)
      else setSelected(r.card)
    }
    setBusy(false)
  }
  const ask = async (target: string) => {
    if (!askWith) return
    setBusy(true)
    await act(() => api.playQuestion(token, askWith, target))
    setAskWith(null)
    setSelected(null)
    setBusy(false)
  }
  const answer = async (choice: number) => {
    setBusy(true)
    const r = await act(() => api.answerQuestion(token, choice))
    setBusy(false)
    return r
  }
  const pickVictim = async (id: string) => {
    setBusy(true)
    await act(() => api.questionPick(token, id))
    setBusy(false)
  }
  const keep = async () => {
    setBusy(true)
    await act(() => api.pass(token))
    setBusy(false)
  }

  const top = state.top_commune ? CARDS[state.top_commune] : null
  const special = state.top_special ? CARDS[state.top_special] : null
  const sel = selected ? CARDS[selected] : null
  const selReasons = selected ? matchReasons(selected, state.top_commune, state.forbidden) : null

  const recent = state.log.slice(-3)
  const myPenalty = [...recent].reverse().find((e) => e.k === 'penalty' && e.p === me.name && state.log.indexOf(e) >= state.log.length - 2)
  const lastAnswer = !state.question ? [...recent].reverse().find((e) => e.k === 'answer') : undefined

  let status: string
  if (state.status === 'finished') status = 'Partie terminée'
  else if (!me.active) status = 'Tu as quitté cette partie.'
  else if (state.question) status = state.question.target === me.id
    ? 'Une question pour toi !'
    : `${state.question.target_name} répond à une question…`
  else if (myTurn && state.phase === 'drawn') status = 'Ta carte piochée peut être posée tout de suite. Pose-la ou garde-la.'
  else if (myTurn) status = playable.size > 0
    ? 'À toi ! Pose une carte en surbrillance ou pioche.'
    : 'À toi ! Aucune carte ne peut être posée : pioche.'
  else status = `${current?.name ?? '…'} réfléchit…`

  return (
    <main className={`game ${myTurn ? 'is-my-turn' : ''}`} style={{ ['--hand-h' as string]: `${handH}px` }}>
      <header className="bar">
        <span className="bar-logo">JuraMatch</span>
        <span className="bar-code">Partie {state.code}</span>
        <div className="bar-actions">
          <button className="btn btn-ghost" onClick={() => setLogOpen((v) => !v)} aria-expanded={logOpen}>Journal</button>
          <button className="btn btn-ghost" onClick={onRules}>Règles</button>
          <button className="btn btn-ghost" onClick={() => { if (window.confirm('Quitter la partie ? Tes cartes retournent dans la pioche.')) void onLeave() }}>Quitter</button>
        </div>
      </header>

      <section className="opponents" aria-label="Adversaires">
        {others.map((p) => (
          <div key={p.id} className={`opp ${p.seat === state.current_seat && state.status === 'playing' ? 'opp-turn' : ''} ${!p.active ? 'opp-gone' : ''}`}>
            <div className="opp-fan" aria-hidden="true">
              {Array.from({ length: Math.min(p.count, 8) }).map((_, i) => (
                <img key={i} src={BACKS[p.seat % 4]} alt="" style={{ ['--i' as string]: i, ['--n' as string]: Math.min(p.count, 8) }} />
              ))}
            </div>
            <div className="opp-name">{p.name}</div>
            <div className="opp-count">{p.active ? `${p.count} carte${p.count > 1 ? 's' : ''}` : 'a quitté'}</div>
          </div>
        ))}
      </section>

      <section className="table" aria-label="Table">
        <div className="pile">
          <button
            className="deck"
            disabled={!myTurn || state.phase !== 'play' || busy}
            onClick={draw}
            aria-label={deckEmpty ? 'Pioche vide : passer le tour' : `Piocher une carte (${state.deck_count} restantes)`}
          >
            {state.deck_count > 0 ? (
              <>
                {state.deck_count > 2 && <img className="deck-under2" src={BACKS[0]} alt="" />}
                {state.deck_count > 1 && <img className="deck-under" src={BACKS[0]} alt="" />}
                <img src={BACKS[0]} alt="" />
              </>
            ) : <span className="slot">Vide</span>}
          </button>
          <span className="pile-label">Pioche<small>{state.deck_count} carte{state.deck_count > 1 ? 's' : ''}</small></span>
        </div>

        <div className="pile pile-main">
          {top ? (
            <button className="card-btn" onClick={() => setZoom(top.id)} aria-label={`Défausse : ${top.name}, voir la carte`}>
              <img key={top.id} className="card-img drop-in" src={top.img} alt={top.name} />
            </button>
          ) : <span className="slot">Défausse</span>}
          <span className="pile-label">Défausse<small>{state.discard_count} posée{state.discard_count > 1 ? 's' : ''}</small></span>
        </div>

        <div className="pile">
          {special ? (
            <button className="card-btn" onClick={() => setZoom(special.id)} aria-label={isNeutralSpecial(special) ? `${special.name} sur la pile spéciale` : `Interdiction active : ${iconLabel(special.icons[0])}`}>
              <img key={special.id} className="card-img card-special drop-in" src={special.img} alt={special.name} />
            </button>
          ) : <span className="slot slot-special">Aucune interdiction</span>}
          <span className="pile-label">
            {special && !isNeutralSpecial(special) ? <>Interdiction active<small>{iconLabel(special.icons[0])}</small></>
              : <>Spéciales<small>{special ? 'aucune interdiction' : 'pile vide'}</small></>}
          </span>
        </div>
      </section>

      <section className="turn-bar" aria-live="polite">
        <p className="turn-status">{status}</p>
        {myTurn && state.phase === 'drawn' && state.drawn_card && (
          <div className="turn-buttons">
            <button className="btn btn-primary" disabled={busy} onClick={() => play(state.drawn_card!)}>
              Poser {CARDS[state.drawn_card]?.name}
            </button>
            <button className="btn" disabled={busy} onClick={keep}>Garder et finir mon tour</button>
          </div>
        )}
        {myTurn && state.phase === 'play' && (
          <div className="turn-buttons">
            <button className="btn" disabled={busy} onClick={draw}>{deckEmpty ? 'Passer (pioche vide)' : 'Piocher'}</button>
          </div>
        )}
        {lastAnswer && (
          <p className={`notice ${lastAnswer.ok ? 'notice-good' : 'notice-chef'}`}>
            {lastAnswer.ok
              ? <>{lastAnswer.p === me.name ? 'Tu as' : `${lastAnswer.p} a`} bien répondu : {lastAnswer.a}.</>
              : <>{lastAnswer.p === me.name ? 'Tu as répondu' : `${lastAnswer.p} a répondu`} {lastAnswer.g}, mais la bonne réponse était {lastAnswer.a}.</>}
          </p>
        )}
        {myPenalty && (
          <p className="notice notice-chef">
            {isQuestion(CARDS[myPenalty.c ?? ''])
              ? (myPenalty.by ? `${myPenalty.by} t’a choisi` : 'Mauvaise réponse')
              : isPlus2(CARDS[myPenalty.c ?? '']) ? 'Une carte +2 t’oblige à piocher' : `${CARDS[myPenalty.c ?? '']?.name ?? 'Un chef-lieu'} t’oblige à piocher`}
            {' '}: tu as reçu {myPenalty.n} carte{(myPenalty.n ?? 0) > 1 ? 's' : ''}.
          </p>
        )}
        {notice && <p className="notice">{notice}</p>}
      </section>

      {sel && selReasons && (
        <div className="focus" role="dialog" aria-label={`Carte ${sel.name}`}>
          <button
            key={sel.id}
            className="focus-card"
            onClick={() => { if (playable.has(sel.id) && !busy) void play(sel.id) }}
            aria-label={playable.has(sel.id) ? `Poser ${sel.name}` : sel.name}
            style={{ cursor: playable.has(sel.id) ? 'pointer' : 'default' }}
          >
            <img className="card-img" src={sel.img} alt={sel.name} />
          </button>
          <div className="focus-text">
            <h2>{sel.name}</h2>
            {top && sel.kind === 'commune' && (
              <div className="focus-vs">
                <img src={top.img} alt="" />
                <span>Sur la défausse : <strong>{top.name}</strong><br /><small>District de {top.district}</small></span>
              </div>
            )}
            <p>
              {isQuestion(sel)
                ? <>Pose-la et désigne un joueur : s’il répond juste à la question, il choisit qui pioche 2 cartes, sinon il pioche 2 cartes.</>
                : isPlus2(sel)
                ? <>Le joueur suivant pioche 2 cartes. Elle recouvre l’Interdiction active, qui ne compte plus.</>
                : sel.kind === 'special'
                ? <>Tant qu’elle est sur la pile spéciale, plus personne ne peut poser une commune avec le symbole <strong>{iconLabel(sel.icons[0])}</strong>.</>
                : selReasons.blockedBy
                  ? <>Bloquée : le symbole <strong>{iconLabel(selReasons.blockedBy)}</strong> est interdit.</>
                  : selReasons.ok
                    ? <>Elle peut être posée. En commun :</>
                    : <>Ne partage ni le district ni un symbole avec {top?.name}.</>}
            </p>
            {sel.kind === 'commune' && !selReasons.blockedBy && selReasons.ok && (
              <div className="chips">
                {selReasons.district && <span className="chip">même district</span>}
                {selReasons.icons.map((i) => <span key={i} className="chip"><img src={iconImg(i)} alt="" />{iconLabel(i)}</span>)}
              </div>
            )}
            {sel.chef_lieu && <p className="chef-note">Chef-lieu : le joueur suivant pioche 3 cartes.</p>}
            {!myTurn && <p className="muted">Ce n’est pas ton tour.</p>}
            {myTurn && state.phase === 'drawn' && sel.id !== state.drawn_card && (
              <p className="muted">Après avoir pioché, seule la carte piochée peut être posée.</p>
            )}
            <div className="focus-actions">
              {playable.has(sel.id) && (
                <button className="btn btn-primary" disabled={busy} onClick={() => play(sel.id)}>
                  {isQuestion(sel) ? 'Poser et choisir un joueur' : `Poser ${sel.name}`}
                </button>
              )}
              {myTurn && state.phase === 'drawn' && sel.id === state.drawn_card && (
                <button className="btn" disabled={busy} onClick={keep}>Garder et finir mon tour</button>
              )}
              <button className="btn btn-ghost-dark" onClick={() => setSelected(null)}>Fermer</button>
            </div>
          </div>
        </div>
      )}

      <section className="hand" aria-label="Ta main" ref={handRef}>
        <div className="hand-row">
          {me.hand.map((id) => {
            const c = CARDS[id]
            const can = playable.has(id)
            const isSel = selected === id
            return (
              <button
                key={id}
                className={`hand-card ${can ? 'can' : ''} ${myTurn && !can ? 'cannot' : ''} ${isSel ? 'sel' : ''} ${state.drawn_card === id ? 'drawn' : ''}`}
                onClick={() => {
                  // 1er clic : sélectionne la carte ; 2e clic sur une carte jouable : la pose
                  if (isSel && can && !busy) void play(id)
                  else setSelected(isSel ? null : id)
                  setZoom(null)
                }}
                aria-pressed={isSel}
                aria-label={`${c?.name}${can ? ', jouable' : ''}`}
              >
                <img className="card-img" src={c?.img} alt="" decoding="async" />
              </button>
            )
          })}
        </div>
        <p className="hand-help muted">Clique une carte pour l’agrandir, clique-la une 2e fois pour la poser.</p>
      </section>

      <aside className={`log ${logOpen ? 'log-open' : ''}`} aria-label="Journal de partie">
        <h2>Journal</h2>
        <ol>
          {[...state.log].reverse().map((e, i) => <li key={state.log.length - i}>{describeEvent(e)}</li>)}
        </ol>
      </aside>

      {state.status === 'finished' && (
        <EndScreen state={state} isHost={isHost} onAgain={() => act(() => api.backToLobby(token))} onLeave={onLeave} />
      )}
      {zoom && <CardZoom id={zoom} onClose={() => setZoom(null)} />}
      {askWith && (
        <TargetPicker
          players={state.players.filter((p) => p.active && p.id !== me.id)}
          busy={busy}
          onPick={ask}
          onCancel={() => setAskWith(null)}
        />
      )}
      {state.question && state.status === 'playing' && (
        <QuestionPanel key={state.question.text + state.question.target} state={state} busy={busy} onAnswer={answer} onPickVictim={pickVictim} />
      )}
    </main>
  )
}

function EndScreen({ state, isHost, onAgain, onLeave }: {
  state: GameState; isHost: boolean; onAgain: () => void; onLeave: () => void
}) {
  const winner = state.players.find((p) => p.id === state.winner_id)
  const ranking = [...state.players].filter((p) => p.active).sort((a, b) => a.count - b.count)
  const iWon = winner?.id === state.me.id
  return (
    <div className="overlay" role="dialog" aria-modal="true" aria-labelledby="end-title">
      <div className="end">
        <img className="end-back" src={BACKS[0]} alt="" />
        <h2 id="end-title">{iWon ? 'Tu as gagné !' : winner ? `${winner.name} a gagné` : 'Partie terminée'}</h2>
        <ol className="ranking">
          {ranking.map((p) => (
            <li key={p.id}>
              <span>{p.name}</span>
              <span>{p.count === 0 ? 'main vide' : `${p.count} carte${p.count > 1 ? 's' : ''}`}</span>
            </li>
          ))}
        </ol>
        <div className="end-actions">
          {isHost
            ? <button className="btn btn-primary" onClick={onAgain}>Rejouer avec les mêmes joueurs</button>
            : <p className="muted">L’hôte peut relancer une partie avec le même code.</p>}
          <button className="btn" onClick={onLeave}>Quitter</button>
        </div>
      </div>
    </div>
  )
}


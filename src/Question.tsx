import { useState } from 'react'
import type { GameState, Player } from './api'
import { CARDS } from './cards'

/** Fenêtre pour choisir à qui poser la question (joueur A). */
export function TargetPicker({ players, onPick, onCancel, busy }: {
  players: Player[]; onPick: (id: string) => void; onCancel: () => void; busy: boolean
}) {
  return (
    <div className="overlay" role="dialog" aria-modal="true" aria-labelledby="pick-title">
      <div className="qbox">
        <img className="qbox-card" src={CARDS['s-question-1'].img} alt="" />
        <h2 id="pick-title">Qui doit répondre ?</h2>
        <p className="muted">Ce joueur reçoit une question sur une commune, avec 3 réponses possibles.</p>
        <div className="qbox-players">
          {players.map((p) => (
            <button key={p.id} className="btn btn-primary" disabled={busy} onClick={() => onPick(p.id)}>
              {p.name}
            </button>
          ))}
        </div>
        <button className="btn btn-ghost-dark" onClick={onCancel}>Annuler</button>
      </div>
    </div>
  )
}

/** Question en cours : réponse (joueur B), choix de la victime, ou vue des autres joueurs. */
export function QuestionPanel({ state, onAnswer, onPickVictim, busy }: {
  state: GameState
  onAnswer: (choice: number) => Promise<{ correct: boolean; answer: string } | undefined>
  onPickVictim: (id: string) => void
  busy: boolean
}) {
  const q = state.question!
  const me = state.me
  const isTarget = q.target === me.id
  const [chosen, setChosen] = useState<number | null>(null)
  const victims = state.players.filter((p) => p.active && p.id !== me.id)

  if (q.stage === 'pick') {
    return (
      <div className="overlay" role="dialog" aria-modal="true" aria-labelledby="q-title">
        <div className="qbox">
          {isTarget ? (
            <>
              <h2 id="q-title" className="q-good">Bonne réponse !</h2>
              <p>Choisis le joueur qui pioche 2 cartes.</p>
              <div className="qbox-players">
                {victims.map((p) => (
                  <button key={p.id} className="btn btn-primary" disabled={busy} onClick={() => onPickVictim(p.id)}>
                    {p.name} <small>({p.count})</small>
                  </button>
                ))}
              </div>
            </>
          ) : (
            <>
              <h2 id="q-title" className="q-good">{q.target_name} a bien répondu</h2>
              <p>{q.target_name} choisit qui pioche 2 cartes…</p>
            </>
          )}
        </div>
      </div>
    )
  }

  return (
    <div className="overlay" role="dialog" aria-modal="true" aria-labelledby="q-title">
      <div className="qbox">
        <p className="q-who">
          {isTarget ? <>{q.by_name} te pose une question</> : <>{q.by_name} pose une question à {q.target_name}</>}
        </p>
        <h2 id="q-title" className="q-text">{q.text}</h2>
        <div className="q-choices">
          {q.choices.map((c, i) => (
            <button
              key={i}
              className={`q-choice ${chosen === i ? 'q-chosen' : ''}`}
              disabled={!isTarget || busy || chosen !== null}
              onClick={async () => { setChosen(i); const r = await onAnswer(i); if (!r) setChosen(null) }}
            >
              {c}
            </button>
          ))}
        </div>
        <p className="muted">
          {isTarget
            ? 'Bonne réponse : tu choisis qui pioche 2 cartes. Mauvaise réponse : tu pioches 2 cartes.'
            : `En attente de la réponse de ${q.target_name}…`}
        </p>
      </div>
    </div>
  )
}

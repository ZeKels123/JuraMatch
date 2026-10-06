import { useEffect } from 'react'
import { CARDS, iconImg, iconLabel, isPlus2 } from './cards'

export function CardZoom({ id, onClose }: { id: string; onClose: () => void }) {
  const c = CARDS[id]
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])
  if (!c) return null
  return (
    <div className="overlay" role="dialog" aria-modal="true" aria-label={c.name} onClick={onClose}>
      <div className="zoom" onClick={(e) => e.stopPropagation()}>
        <img className="card-img zoom-img" src={c.img} alt={c.name} />
        <div className="zoom-text">
          <h2>{c.name}</h2>
          {c.kind === 'commune' ? (
            <>
              <p className="muted">District de {c.district}</p>
              <ul className="zoom-icons">
                {c.icons.map((i) => <li key={i}><img src={iconImg(i)} alt="" />{iconLabel(i)}</li>)}
              </ul>
              {c.chef_lieu && <p className="chef-note">Chef-lieu : quand cette carte est posée, le joueur suivant pioche 3 cartes.</p>}
              <p>{c.description}</p>
            </>
          ) : isPlus2(c) ? (
            <p>
              Carte +2. Quand elle est posée sur la pile spéciale, le joueur suivant pioche 2 cartes. Elle recouvre
              l’Interdiction active, qui ne compte donc plus.
            </p>
          ) : (
            <p>
              Carte Interdiction. Tant qu’elle est au sommet de la pile spéciale, aucune commune portant le symbole
              <strong> {iconLabel(c.icons[0])}</strong> ne peut être posée. Une autre carte spéciale la remplace.
            </p>
          )}
          <button className="btn" onClick={onClose} autoFocus>Fermer</button>
        </div>
      </div>
    </div>
  )
}

import { useEffect } from 'react'
import { ICONS, iconImg } from './cards'

export function RulesModal({ onClose }: { onClose: () => void }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])
  return (
    <div className="overlay" role="dialog" aria-modal="true" aria-labelledby="rules-title" onClick={onClose}>
      <article className="rules" onClick={(e) => e.stopPropagation()}>
        <h2 id="rules-title">Règles de JuraMatch</h2>

        <h3>Matériel</h3>
        <p>80 cartes : 51 communes jurassiennes (district, altitude, habitants et trois symboles) et 29 cartes spéciales Interdiction.</p>

        <h3>Mise en place</h3>
        <p>De 2 à 4 joueurs, chacun reçoit 8 cartes ; à 5 ou 6 joueurs, 6 cartes. La première carte de la pioche est retournée pour former la défausse — si c’est une carte spéciale, elle repart au milieu du paquet. Le plus jeune commence, puis on tourne dans l’ordre des places.</p>

        <h3>À ton tour, une seule action</h3>
        <ol>
          <li><strong>Poser une commune</strong> sur la défausse si elle partage au moins un critère avec la commune du dessus : le même district, ou un même symbole.</li>
          <li><strong>Ou poser une carte spéciale</strong> sur la deuxième pile. Elle reste active tant qu’une autre spéciale n’est pas posée par-dessus.</li>
          <li><strong>Ou piocher</strong> une carte. Si elle peut être posée tout de suite, tu peux la poser ; sinon ton tour s’arrête.</li>
        </ol>

        <h3>Cartes Interdiction</h3>
        <p>Tant qu’une Interdiction est active, aucune commune portant ce symbole ne peut être posée, même si elle partage autre chose avec la défausse.</p>

        <h3>Fin de partie</h3>
        <p>Le premier joueur qui pose toutes ses cartes gagne. Si la pioche est vide, la défausse et la pile spéciale (sauf leurs cartes du dessus) sont remélangées.</p>

        <h3>Les 14 symboles</h3>
        <ul className="legend">
          {ICONS.map((i) => <li key={i.id}><img src={iconImg(i.id)} alt="" />{i.label}</li>)}
        </ul>

        <button className="btn btn-primary" onClick={onClose} autoFocus>J’ai compris</button>
      </article>
    </div>
  )
}

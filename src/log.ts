import type { LogEvent } from './api'
import { CARDS, iconLabel, isPlus2 } from './cards'

export function describeEvent(e: LogEvent): string {
  const card = e.c ? CARDS[e.c] : null
  switch (e.k) {
    case 'create': return `${e.p} a créé la partie.`
    case 'join': return `${e.p} a rejoint la partie.`
    case 'start': return `Distribution : ${e.n} cartes chacun. ${e.p} commence.`
    case 'play':
      if (!card) return `${e.p} a posé une carte.`
      if (isPlus2(card)) return `${e.p} a posé une carte +2${e.left !== undefined ? ` (reste ${e.left})` : ''}.`
      return card.kind === 'special'
        ? `${e.p} interdit le symbole ${iconLabel(card.icons[0])}.`
        : `${e.p} a posé ${card.name}${e.left !== undefined ? ` (reste ${e.left})` : ''}.`
    case 'draw': return e.playable ? `${e.p} a pioché une carte jouable.` : `${e.p} a pioché.`
    case 'keep': return `${e.p} garde sa carte piochée.`
    case 'reshuffle': return `Pioche vide : ${e.n} cartes remélangées.`
    case 'empty': return `${e.p} passe : plus aucune carte à piocher.`
    case 'leave': return `${e.p} a quitté la partie.`
    case 'win': return `${e.p} a posé sa dernière carte et gagne !`
    case 'penalty': return `${isPlus2(card) ? '+2' : card?.name ?? 'Chef-lieu'} : ${e.p} pioche ${e.n} carte${(e.n ?? 0) > 1 ? 's' : ''}.`
    case 'lobby': return 'Retour au salon.'
    default: return ''
  }
}

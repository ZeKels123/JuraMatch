import data from './data/cards.json'

export type Card = {
  id: string
  kind: 'commune' | 'special'
  name: string
  district?: string
  altitude?: number
  habitants?: number
  icons: string[]
  chef_lieu?: boolean
  description?: string
  img: string
}

export const ICONS: { id: string; label: string }[] = data.icons
export const CARDS: Record<string, Card> = Object.fromEntries(
  (data.cards as Card[]).map((c) => [c.id, c]),
)

export const iconLabel = (id: string) => ICONS.find((i) => i.id === id)?.label ?? id
export const iconImg = (id: string) => `cards/icons/${id}.webp`
export const BACKS = ['cards/backs/back-1.webp', 'cards/backs/back-2.webp', 'cards/backs/back-3.webp', 'cards/backs/back-4.webp']

/** Pourquoi une carte de la main peut (ou non) aller sur la défausse — pour l'aide au joueur. */
export function matchReasons(cardId: string, topId: string | null, forbidden: string | null) {
  const c = CARDS[cardId]
  if (!c) return { ok: false, district: false, icons: [] as string[], blockedBy: null as string | null }
  if (c.kind === 'special') return { ok: true, district: false, icons: [], blockedBy: null }
  if (forbidden && c.icons.includes(forbidden)) return { ok: false, district: false, icons: [], blockedBy: forbidden }
  const top = topId ? CARDS[topId] : null
  if (!top) return { ok: true, district: false, icons: [], blockedBy: null }
  const district = c.district === top.district
  const icons = c.icons.filter((i) => top.icons.includes(i))
  return { ok: district || icons.length > 0, district, icons, blockedBy: null }
}

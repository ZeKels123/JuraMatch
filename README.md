# JuraMatch en ligne

Version informatisée du jeu de cartes **JuraMatch** : 51 communes jurassiennes et 29 cartes Interdiction, jouable à 2–6 joueurs depuis un navigateur, chacun sur son appareil.

**Jouer :** https://zekels123.github.io/JuraMatch/

## Comment jouer à plusieurs

1. Un joueur clique sur **Créer une partie** : il reçoit un code de 5 caractères (ex. `K7Q2M`).
2. Les autres saisissent ce code dans **Rejoindre** (ou ouvrent le lien d’invitation copié depuis le salon).
3. L’hôte choisit qui est le plus jeune (il commence) puis lance la partie.

Si on ferme l’onglet, on retrouve sa partie en revenant sur le site avec le même navigateur.

## Règles appliquées

- Distribution : 8 cartes de 2 à 4 joueurs, 6 cartes à 5–6 joueurs. La première carte de la défausse est toujours une commune (une spéciale retourne au milieu du paquet).
- À son tour, une seule action :
  - poser une **commune** qui partage le **même district** ou **au moins un symbole** avec la commune du dessus ;
  - ou poser une **carte Interdiction** sur la pile spéciale ;
  - ou **piocher** : si la carte piochée est jouable, on peut la poser tout de suite (ou la garder), sinon le tour s’arrête.
- Une Interdiction reste active jusqu’à ce qu’une autre spéciale la recouvre : aucune commune portant le symbole interdit ne peut être posée.
- Le premier qui vide sa main gagne. Pioche vide : défausse et pile spéciale (sauf leurs cartes du dessus) sont remélangées.

## Technique

- **Site** : React + TypeScript + Vite (`src/`), images des cartes extraites des PDF d’impression (`public/cards/`), données des cartes dans `src/data/cards.json`.
- **Serveur** : Supabase. Toute la logique (distribution, tour de jeu, validité des coups, mains cachées) tourne dans des fonctions PostgreSQL (`supabase/migrations/`). Les tables ne sont pas lisibles depuis le site : chaque joueur ne reçoit que sa propre main via `jm_get_state`.
- **Temps réel** : chaque action envoie une notification Supabase Realtime sur le canal `juramatch:<code>` ; le site interroge aussi le serveur toutes les 4 s en secours.
- **Déploiement** : chaque push sur `main` reconstruit le site et le publie sur la branche `gh-pages` (`.github/workflows/deploy.yml`).

```bash
npm install
npm run dev      # http://localhost:5173
npm run build
```

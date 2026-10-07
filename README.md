# JuraMatch en ligne

Version informatisée du jeu de cartes **JuraMatch** : 80 cartes : 51 communes jurassiennes (1 à 5 symboles, dont 4 chefs-lieux), 14 cartes Interdiction, 9 cartes +2 et 6 cartes Question, jouable à 2–6 joueurs depuis un navigateur, chacun sur son appareil.

**Jouer :** https://zekels123.github.io/JuraMatch/

## Comment jouer à plusieurs

1. Un joueur clique sur **Créer une partie** : il reçoit un code de 5 caractères (ex. `K7Q2M`).
2. Les autres saisissent ce code dans **Rejoindre** (ou ouvrent le lien d’invitation copié depuis le salon).
3. L’hôte choisit qui est le plus jeune (il commence) puis lance la partie.

Si on ferme l’onglet, le bouton « Reprendre ma partie » de l’accueil permet de revenir dans la partie (même navigateur). Chaque onglet est un joueur distinct : on peut tester à plusieurs sur un seul ordinateur.

## Règles appliquées

- Distribution : 8 cartes de 2 à 4 joueurs, 6 cartes à 5–6 joueurs. La première carte de la défausse est toujours une commune (une spéciale retourne au milieu du paquet).
- À son tour, une seule action :
  - poser une **commune** qui partage le **même district** ou **au moins un symbole** avec la commune du dessus ;
  - ou poser une **carte Interdiction** sur la pile spéciale ;
  - ou **piocher** : si la carte piochée est jouable, on peut la poser tout de suite (ou la garder), sinon le tour s’arrête.
- Une Interdiction reste active jusqu’à ce qu’une autre spéciale la recouvre : aucune commune portant le symbole interdit ne peut être posée.
- **Cartes +2** (pile spéciale) : le joueur suivant pioche 2 cartes puis joue normalement ; elles recouvrent l’Interdiction active.
- **Cartes Question** : on désigne un joueur qui répond à une question sur une commune (3 choix). Juste : il choisit qui pioche 2 cartes. Faux : il pioche 2 cartes. Les 51 questions sont dans `supabase/questions.py`.
- **Chefs-lieux** (Delémont, Porrentruy, Saignelégier, Moutier) : quand l’un d’eux est posé, le joueur suivant pioche 3 cartes puis joue normalement.
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

# Bilan trading

Un journal de trading complet en une seule page, en français, pensé pour le téléphone (barre d'onglets en bas) et utilisable aussi sur ordinateur.

## Les onglets

- **Bilan** : résultat net, courbe du résultat cumulé, objectif du mois, alertes du jour (perte max, trades max, pertes de suite), 20 chiffres clés (réussite, profit factor, espérance, résultat moyen en R, drawdown, jours gagnants…), calendrier des jours gagnants et perdants, et une analyse détaillée par mois, actif, setup, sens, jour de la semaine, heure, émotion, plan suivi, erreurs et ratio gain/risque.
- **Trades** : la liste des trades, avec recherche. Chaque trade contient le compte, la date et l'heure, l'actif, le sens, l'entrée, le stop loss, l'objectif, la sortie, la quantité, les frais, le résultat (calculé tout seul), le setup, l'émotion, le plan suivi ou non, les erreurs, une note et des captures d'écran.
- **Journal** : le journal de bord (humeur, déroulé de la séance, leçon, objectif pour la prochaine fois).
- **Conseils** : des conseils automatiques tirés de vos chiffres, l'avis de Claude sur votre bilan (et sur chaque trade) et les règles d'or du trader.
- **Défis** : des défis à deux avec les autres utilisateurs de l'appli, sur la même période. On choisit l'adversaire, son compte, ce qui fait gagner (le plus gros gain, le meilleur rendement %, le plus de R, la meilleure réussite ou la meilleure discipline), les dates et un enjeu. L'autre accepte ou refuse, les scores se mettent à jour tout seuls et le gagnant s'affiche à la fin, avec un bouton Revanche. Seuls les scores sont partagés, pas les trades.
- **Partage** : rendre ses comptes visibles par les autres utilisateurs de l'appli (en lecture seule), ou rester privé. On y voit aussi les comptes que les autres ont rendus visibles.
- **Réglages** : comptes (Réel, Démo, et d'autres si besoin), devise, capital, objectif mensuel, limites, ajout à l'écran d'accueil, export et import CSV, aperçu avec des trades fictifs.

## Où sont gardées les données

- Ouvert depuis Claude : dans le compte Claude de chaque personne, privé. Seuls les comptes rendus visibles dans l'onglet Partage sont lisibles par les autres, et personne ne peut les modifier.
- Ouvert ailleurs (le fichier `index.html` dans un navigateur) : dans ce navigateur uniquement. Le partage, les captures d'écran et l'avis de Claude ne fonctionnent alors pas.

## Deux versions

- **Version Claude** : `index.html`, publiée comme page dans Claude.
- **Version web indépendante** : le dossier `docs/`, mise en ligne avec GitHub Pages. Elle utilise Supabase pour la connexion par e-mail, les données, le partage, les défis et les captures. L'avis de Claude y est remplacé par un bouton « Copier pour Claude ».

`docs/index.html` est généré à partir de `index.html` : après une modification, lancez `python3 tools/build_web.py`. Le script de base de données à coller dans Supabase est `tools/supabase.sql`, et l'adresse et la clé publique du projet sont dans `docs/config.js`.

## Fichiers

- `index.html` : tout l'outil (page, style et code dans un seul fichier, sans installation).
- `docs/` : la version web (appli installable sur l'écran d'accueil).
- `tools/` : le script de construction de la version web et le script SQL pour Supabase.

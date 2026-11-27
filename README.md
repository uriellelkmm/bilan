# Bilan trading

Un journal de trading complet en une seule page, en français, pensé pour le téléphone (barre d'onglets en bas) et utilisable aussi sur ordinateur.

## Les onglets

- **Bilan** : résultat net, graphique au choix (linéaire, courbe remplie, barres, donut ou aire), objectif du mois, alertes du jour (perte max, trades max, pertes de suite), 20 chiffres clés (réussite, profit factor, espérance, résultat moyen en R, drawdown, jours gagnants…), calendrier des jours gagnants et perdants, et une analyse détaillée par mois, actif, setup, sens, jour de la semaine, heure, émotion, plan suivi, erreurs et ratio gain/risque.
- **Trades** : la liste des trades, avec recherche. Chaque trade contient le compte, la date et l'heure, l'actif, le sens, l'entrée, le stop loss, l'objectif, la sortie, la quantité, les lots, la somme risquée, les frais, le résultat (calculé tout seul), le setup, l'émotion, le plan suivi ou non, les erreurs, les défis pour lesquels il compte, une note et des captures d'écran. Un calculateur propose la taille de position (lots) selon le capital, le risque et le stop.
- **Journal** : le journal de bord (humeur, déroulé de la séance, leçon, objectif pour la prochaine fois).
- **Conseils** : des conseils automatiques tirés de vos chiffres, le calculateur de lots, l'avis de Claude sur votre bilan (et sur chaque trade) et les règles d'or du trader.
- **Défis** : des défis à deux, tous contre tous (classement) ou équipe contre équipe (moyenne des membres), sur la même période. On choisit les participants, son compte, ce qui fait gagner (le plus gros gain, le meilleur rendement %, le plus de R, la meilleure réussite ou la meilleure discipline), les dates et un enjeu. L'autre accepte ou refuse, les scores se mettent à jour tout seuls et le gagnant s'affiche à la fin, avec un bouton Revanche. Seuls les scores sont partagés, pas les trades. Dans la version web, chaque défi a sa discussion de groupe.
- **Partage** (version Claude) / **Réseau** (version web) : rendre ses comptes visibles par les autres (en lecture seule), ou rester privé. Dans la version web : un fil avec photos, bilan de la semaine en 1 clic, stratégie, évolution, stories de 24 heures, j'aime, commentaires, la liste des membres et une page profil (photo, présentation, comptes visibles, publications).
- **Réglages** : thème de couleurs (classique, lavande, bordeaux, bleu nuit, vert forêt, ocre doré ; clair ou sombre), comptes (Réel, Démo, et d'autres si besoin), devise, capital, objectif mensuel, limites, ajout à l'écran d'accueil, export et import CSV, aperçu avec des trades fictifs. Dans la version web : connexion MetaTrader 5 et, pour l'administratrice, la liste des membres inscrits avec la possibilité d'en retirer ou d'en bloquer.

## Où sont gardées les données

- Ouvert depuis Claude : dans le compte Claude de chaque personne, privé. Seuls les comptes rendus visibles dans l'onglet Partage sont lisibles par les autres, et personne ne peut les modifier.
- Ouvert ailleurs (le fichier `index.html` dans un navigateur) : dans ce navigateur uniquement. Le partage, les captures d'écran et l'avis de Claude ne fonctionnent alors pas.

## Deux versions

- **Version Claude** : `index.html`, publiée comme page dans Claude.
- **Version web indépendante** : le dossier `docs/`, mise en ligne avec GitHub Pages. Elle utilise Supabase pour la connexion par e-mail, les données, le partage, les défis et les captures. L'avis de Claude y est remplacé par un bouton « Copier pour Claude ».

`docs/index.html` est généré à partir de `index.html` : après une modification, lancez `python3 tools/build_web.py`. Les scripts de base de données à coller dans Supabase sont `tools/supabase.sql` puis `tools/supabase-v2.sql` (réseau, discussions, MT5, administration ; le premier compte créé devient administrateur), et l'adresse et la clé publique du projet sont dans `docs/config.js`.

## Connexion MetaTrader 5

`docs/mt5/BilanTrading.mq5` est un robot (Expert Advisor) qui ne passe aucun ordre : il lit les trades fermés du compte MT5 et les envoie dans l'appli avec une clé personnelle créée dans Réglages. Il tourne dans MetaTrader 5 sur ordinateur (Windows ou Mac) ; les trades passés depuis le téléphone arrivent aussi, dès que MetaTrader tourne sur l'ordinateur.

## Fichiers

- `index.html` : tout l'outil (page, style et code dans un seul fichier, sans installation).
- `docs/` : la version web (appli installable sur l'écran d'accueil).
- `tools/` : le script de construction de la version web et le script SQL pour Supabase.

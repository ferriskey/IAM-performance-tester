# FerrisKey contre Keycloak : résultats du 31 octobre 2026

Ce bench compare FerrisKey (`main` au commit `ace8c1a`, qui inclut le travail sur le refresh token de la PR ferriskey/ferriskey#1875) et Keycloak 26.8.1. Les deux tournent sur le même cluster, avec les mêmes ressources, la même base PostgreSQL et les mêmes 1 000 utilisateurs. Six endpoints sont mesurés à débit croissant.

## En bref

- FerrisKey tient le même palier maximal que Keycloak sur les six endpoints testés.
- Il consomme moins de CPU que Keycloak presque partout, souvent deux fois moins à débit égal. La seule exception est userinfo à partir de 3 200 req/s.
- Sur le refresh, FerrisKey est maintenant devant : à 800 req/s, sa p95 est de 5,7 ms contre 14,5 ms, avec 40 % de CPU en moins.
- Keycloak garde une queue de latence (p99) plus basse sur client_credentials dès 800 req/s, sur password, et sur introspect et userinfo à partir de 3 200 req/s.
- FerrisKey occupe moins de mémoire : 618 Mio au maximum, contre 823 Mio pour Keycloak.

## Vue d'ensemble

Le débit maximal tenu est le palier le plus haut où moins de 1 % des requêtes échouent, où au moins 95 % du débit demandé est servi, et où la p95 reste sous 250 ms. La latence et le CPU sont relevés à 800 req/s, sauf pour password (80 req/s), car le hachage Argon2id coûte cher par nature.

| Endpoint | Débit max tenu FerrisKey | Débit max tenu Keycloak | p95 FerrisKey | p95 Keycloak | CPU FerrisKey | CPU Keycloak |
|---|---|---|---|---|---|---|
| client_credentials | 3 200 req/s | 3 200 req/s | 2,7 ms | 2,0 ms | 0,66 cœur | 0,94 cœur |
| password (80 req/s) | 160 req/s (palier le plus haut testé) | 160 req/s | 29,2 ms | 20,9 ms | 1,26 cœur | 1,46 cœur |
| refresh | 1 600 req/s (palier le plus haut testé) | 1 600 req/s | 5,7 ms | 14,5 ms | 1,47 cœur | 2,47 cœurs |
| introspect | 6 400 req/s | 6 400 req/s | 1,6 ms | 2,7 ms | 0,28 cœur | 0,57 cœur |
| userinfo | 6 400 req/s | 6 400 req/s | 1,7 ms | 2,6 ms | 0,21 cœur | 0,51 cœur |
| jwks | 6 400 req/s | 6 400 req/s | 1,1 ms | 1,9 ms | 0,15 cœur | 0,40 cœur |

Le CPU est celui du serveur IAM seul, en cœurs, moyenné sur la minute mesurée.

## Mémoire

| Système | Minimum | Maximum |
|---|---|---|
| FerrisKey | 62 Mio | 618 Mio |
| Keycloak | 533 Mio | 823 Mio |

Il s'agit du working set du pod sur l'ensemble des paliers. FerrisKey démarre bas et monte au fil des scénarios. Keycloak ne descend jamais sous 530 Mio.

## Endpoint par endpoint

Chaque tableau donne la latence (p50 / p95 / p99) et le CPU du serveur IAM à chaque palier. « Non testé » veut dire que l'échelle de ce système s'arrêtait plus bas.

### client_credentials

Un client s'authentifie avec son secret et reçoit un access token. FerrisKey a une médiane plus basse et consomme moins de CPU à tous les paliers. Sa queue est en revanche plus longue dès 800 req/s : p99 de 65,6 ms à 800 req/s et de 25,6 ms à 1 600 req/s, contre moins de 7 ms pour Keycloak. À 3 200 req/s, FerrisKey sert encore 3 181 req/s, mais avec 0,56 % d'erreurs et une p95 de 54 ms, alors que Keycloak reste à 10 ms.

| Débit demandé (req/s) | FerrisKey p50 / p95 / p99 | Keycloak p50 / p95 / p99 | CPU FerrisKey (cœurs) | CPU Keycloak (cœurs) |
|---|---|---|---|---|
| 50 | 2,4 / 5,4 / 7,2 ms | 5,0 / 8,0 / 9,1 ms | 0,11 | 0,29 |
| 100 | 1,4 / 3,9 / 10,3 ms | 3,4 / 6,7 / 7,5 ms | 0,17 | 0,34 |
| 200 | 1,2 / 2,8 / 3,6 ms | 2,5 / 3,6 / 5,5 ms | 0,25 | 0,29 |
| 400 | 1,1 / 2,2 / 3,3 ms | 1,7 / 2,6 / 3,9 ms | 0,41 | 0,60 |
| 800 | 1,1 / 2,7 / 65,6 ms | 1,4 / 2,0 / 3,5 ms | 0,66 | 0,94 |
| 1 600 | 1,1 / 4,0 / 25,6 ms | 1,5 / 3,7 / 6,7 ms | 1,51 | 2,02 |
| 3 200 | 2,3 / 53,6 / 92,6 ms, 0,56 % d'erreurs | 3,2 / 10,5 / 22,5 ms | 2,64 | 3,63 |

### password

Un utilisateur se connecte avec son mot de passe. Les deux systèmes hachent avec Argon2id (m=7168, t=5, p=1), ce qui fixe la latence autour de 20 ms. Keycloak a une queue plus courte : à 160 req/s, sa p95 est de 32 ms contre 87 ms. Keycloak sature vers 155 req/s. FerrisKey n'a pas été testé au-delà de 160 req/s.

| Débit demandé (req/s) | FerrisKey p50 / p95 / p99 | Keycloak p50 / p95 / p99 | CPU FerrisKey (cœurs) | CPU Keycloak (cœurs) |
|---|---|---|---|---|
| 10 | 20,6 / 28,5 / 47,3 ms | 27,6 / 32,6 / 36,5 ms | 0,16 | 0,30 |
| 20 | 19,7 / 24,1 / 30,4 ms | 18,6 / 21,5 / 23,6 ms | 0,26 | 0,31 |
| 40 | 20,0 / 33,7 / 70,6 ms | 18,0 / 20,1 / 22,7 ms | 0,64 | 0,72 |
| 80 | 22,2 / 29,2 / 46,0 ms | 18,4 / 20,9 / 26,7 ms | 1,26 | 1,46 |
| 160 | 30,9 / 87,4 / 170 ms | 21,5 / 32,3 / 40,9 ms | 3,14 | 3,29 |
| 320 | non testé | 2018 / 2216 / 2266 ms, 152 req/s servies | – | 3,52 |
| 640 | non testé | 1992 / 2077 / 2124 ms, 155 req/s servies | – | 3,40 |

### refresh

Un client échange son refresh token contre un nouveau jeu de tokens. Des deux côtés, l'ancien refresh token est invalidé à chaque échange (rotation activée sur Keycloak). FerrisKey a une médiane plus basse à tous les paliers et consomme environ 40 % de CPU en moins. Sa p95 est meilleure à 800 et 1 600 req/s. À 400 req/s, un pic isolé fait monter sa p99 à 206 ms, alors que les paliers voisins restent sous 13 ms. Keycloak plafonne à 1 766 req/s. FerrisKey n'a pas été testé au-delà de 1 600 req/s.

| Débit demandé (req/s) | FerrisKey p50 / p95 / p99 | Keycloak p50 / p95 / p99 | CPU FerrisKey (cœurs) | CPU Keycloak (cœurs) |
|---|---|---|---|---|
| 50 | 4,2 / 9,2 / 18,4 ms | 5,3 / 7,8 / 12,5 ms | 0,17 | 0,37 |
| 100 | 3,4 / 5,6 / 7,6 ms | 4,3 / 6,0 / 11,5 ms | 0,25 | 0,43 |
| 200 | 2,5 / 4,4 / 7,5 ms | 4,0 / 6,2 / 13,4 ms | 0,43 | 0,74 |
| 400 | 2,8 / 38,1 / 206 ms | 3,8 / 7,7 / 17,9 ms | 0,90 | 1,35 |
| 800 | 2,6 / 5,7 / 12,1 ms | 4,0 / 14,5 / 34,0 ms | 1,47 | 2,47 |
| 1 600 | 6,4 / 93,2 / 187 ms | 15,3 / 139 / 216 ms | 2,97 | 4,63 |
| 3 200 | non testé | 162 / 232 / 274 ms, 1766 req/s servies | – | 5,27 |

### introspect

Un service demande si un access token est encore valide. De 200 à 3 200 req/s, les deux répondent en moins d'une milliseconde en médiane. FerrisKey consomme moins de CPU à tous les paliers, jusqu'à trois fois moins. À partir de 3 200 req/s, Keycloak a une p95 et une p99 plus basses.

| Débit demandé (req/s) | FerrisKey p50 / p95 / p99 | Keycloak p50 / p95 / p99 | CPU FerrisKey (cœurs) | CPU Keycloak (cœurs) |
|---|---|---|---|---|
| 50 | 1,6 / 4,5 / 7,1 ms | 3,6 / 6,1 / 11,8 ms | 0,06 | 0,18 |
| 100 | 1,2 / 3,4 / 5,6 ms | 2,9 / 4,8 / 6,4 ms | 0,09 | 0,25 |
| 200 | 0,9 / 2,4 / 3,6 ms | 1,5 / 3,3 / 4,3 ms | 0,13 | 0,25 |
| 400 | 0,7 / 1,9 / 3,4 ms | 0,8 / 2,9 / 3,8 ms | 0,19 | 0,37 |
| 800 | 0,6 / 1,6 / 2,7 ms | 0,7 / 2,7 / 4,5 ms | 0,28 | 0,57 |
| 1 600 | 0,7 / 1,9 / 4,8 ms | 0,7 / 2,4 / 5,2 ms | 0,45 | 0,63 |
| 3 200 | 0,7 / 2,6 / 8,4 ms | 0,5 / 1,4 / 4,1 ms | 0,59 | 1,03 |
| 6 400 | 1,1 / 6,0 / 19,8 ms | 0,7 / 3,5 / 7,8 ms | 1,33 | 1,55 |

### userinfo

Un client lit le profil de l'utilisateur avec son access token. Jusqu'à 1 600 req/s, FerrisKey a une médiane plus basse et consomme moins de CPU. Au-delà, Keycloak reprend l'avantage : à 6 400 req/s, sa p99 est de 3,7 ms contre 12,1 ms, et il consomme 1,29 cœur contre 1,55.

| Débit demandé (req/s) | FerrisKey p50 / p95 / p99 | Keycloak p50 / p95 / p99 | CPU FerrisKey (cœurs) | CPU Keycloak (cœurs) |
|---|---|---|---|---|
| 50 | 1,9 / 5,6 / 9,4 ms | 3,3 / 5,4 / 6,7 ms | 0,08 | 0,16 |
| 100 | 1,3 / 3,8 / 5,6 ms | 2,8 / 4,5 / 5,6 ms | 0,09 | 0,24 |
| 200 | 0,8 / 2,6 / 6,0 ms | 1,6 / 3,2 / 3,9 ms | 0,12 | 0,29 |
| 400 | 0,5 / 1,8 / 3,3 ms | 0,7 / 2,7 / 3,6 ms | 0,13 | 0,33 |
| 800 | 0,5 / 1,7 / 3,1 ms | 0,6 / 2,6 / 3,8 ms | 0,21 | 0,51 |
| 1 600 | 0,6 / 1,7 / 3,4 ms | 0,6 / 2,8 / 4,7 ms | 0,42 | 0,74 |
| 3 200 | 0,8 / 2,3 / 4,6 ms | 0,5 / 1,2 / 2,6 ms | 0,88 | 0,75 |
| 6 400 | 1,0 / 4,3 / 12,1 ms | 0,6 / 1,7 / 3,7 ms | 1,55 | 1,29 |

### jwks

Un client récupère les clés publiques du realm pour vérifier les signatures. C'est l'endpoint le plus léger. FerrisKey consomme 1,7 à 6 fois moins de CPU que Keycloak. La p99 reste sous 5,2 ms des deux côtés.

| Débit demandé (req/s) | FerrisKey p50 / p95 / p99 | Keycloak p50 / p95 / p99 | CPU FerrisKey (cœurs) | CPU Keycloak (cœurs) |
|---|---|---|---|---|
| 100 | 0,4 / 1,2 / 2,0 ms | 2,2 / 3,9 / 5,1 ms | 0,03 | 0,19 |
| 200 | 0,4 / 1,1 / 1,8 ms | 1,5 / 2,9 / 4,0 ms | 0,05 | 0,25 |
| 400 | 0,3 / 1,1 / 1,9 ms | 1,0 / 2,3 / 3,2 ms | 0,09 | 0,33 |
| 800 | 0,3 / 1,1 / 2,1 ms | 0,6 / 1,9 / 3,0 ms | 0,15 | 0,40 |
| 1 600 | 0,4 / 1,3 / 2,5 ms | 0,5 / 2,2 / 3,8 ms | 0,20 | 0,56 |
| 3 200 | 0,4 / 1,5 / 3,2 ms | 0,4 / 1,2 / 3,1 ms | 0,30 | 0,64 |
| 6 400 | 0,6 / 2,0 / 3,4 ms | 0,5 / 1,4 / 3,4 ms | 0,59 | 1,00 |

## Conditions de mesure

- **Cluster** : k3d sur OrbStack, sur un Mac, avec 8 vCPU partagés entre le générateur de charge, le serveur IAM et PostgreSQL. Chaque rôle a son nœud k3d, mais les cœurs physiques sont communs.
- **Serveur IAM** : 1 réplica, 3 CPU demandés, sans limite CPU, 1 536 Mio de mémoire. Keycloak tourne en mode production (`start`) avec `-XX:ActiveProcessorCount=3`.
- **Base** : PostgreSQL 17 (CloudNativePG), une par système, 1 CPU demandé, 3 Gio, `max_connections` à 400, sur son propre nœud.
- **Charge** : k6 en débit constant (modèle ouvert), 1 000 utilisateurs, 15 s de chauffe puis 60 s mesurées par palier.
- **FerrisKey** : image construite depuis `main` (`ace8c1a`), avec `REFRESH_TOKEN_FORMAT=opaque` et `REFRESH_TOKEN_COMMIT=async`. Mesuré le 31 octobre 2026, avec 300 VUs pré-allouées dans k6.
- **Keycloak** : image `quay.io/keycloak/keycloak:26.8.1`, realm avec `revokeRefreshToken=true` et `refreshTokenMaxReuse=0`. Refresh mesuré le 31 octobre 2026 avec 300 VUs pré-allouées. Les cinq autres endpoints ont été mesurés le 26 octobre 2026, avec le nombre de VUs pré-allouées par défaut de k6.

## Données brutes

Les passages bruts (JSON de chaque palier et `REPORT.md`) restent en local dans `results/k8s/`, hors du dépôt :

- FerrisKey : `results/k8s/2026-10-31_14-32-52_final-ace8c1a-kc2681/`
- Keycloak, refresh : `results/k8s/2026-10-31_15-43-44_final-kc2681-refresh-rotation/`
- Keycloak, autres endpoints : `results/k8s/2026-10-26_21-22-42_k3d-nolimit-fk3x-kc3cpu-d73af3e/`

Pour reproduire : `k8s/README.md`.

# Matrice de vérification

Renseigner une ligne par cible et par capacité importante.

| Cible | Composant | Disponible | Installé | Activé | Connecté | Test réel | Preuve |
| --- | --- | --- | --- | --- | --- | --- | --- |
| local ou cloud | package ou service | oui ou non | version | application | identité | résultat | identifiant du run ou contrôle |

## Preuves minimales

- Identité : instance, organisation, application, utilisateur et rôle confirmés dans l'interface utilisée.
- Package : identifiant canonique, version et fichiers attendus relus après import.
- Intégration : outils requis visibles, scopes minimaux et connexion du bon compte.
- Agent : dépendances résolues, entrée représentative, état terminal, sortie métier et logs inspectés.
- Parité : mêmes contrôles exécutés séparément sur local et cloud.

Un élément non testé reste « configuré » ou « à vérifier », jamais « fonctionnel ».

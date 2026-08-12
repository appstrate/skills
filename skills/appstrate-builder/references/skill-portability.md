# Portabilité des skills

Une skill portable contient un `SKILL.md` avec un nom non scopé et une description de déclenchement.
Ses liens relatifs restent dans son dossier. Elle ne suppose ni un scope d'organisation, ni un
identifiant d'application, ni une opération expérimentale.

## Dans un agent de coding

Installer le dossier complet dans le catalogue de skills reconnu par l'agent. Les fichiers de
référence et scripts restent relatifs au `SKILL.md`. Vérifier la détection avec une requête de
déclenchement représentative.

## Dans Appstrate

Créer une archive par skill avec `SKILL.md` à la racine. Importer l'archive dans l'organisation cible,
puis relever l'identifiant `@scope/name` attribué. Affecter la skill aux agents ou applications qui en
ont besoin selon les opérations exposées par l'instance.

## Entre organisations

Partager les sources ou archives sans secret, jeton, identifiant interne ni configuration propre à
une entreprise. Chaque organisation importe sous son propre scope et recrée ses connexions. Une skill
peut décrire un besoin d'accès, mais ne transporte pas les identifiants OAuth ni les autorisations.

## Skills compagnes

Une référence à une autre skill utilise son nom non scopé. Au runtime, résoudre la candidate réellement
accessible et conserver son identifiant canonique. L'absence d'une skill compagne est une dépendance
à installer, pas une autorisation d'en inventer le contenu.

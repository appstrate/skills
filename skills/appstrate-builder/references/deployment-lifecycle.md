# Cycle de déploiement Appstrate

## Cadrage

Définir le sponsor, les architectes IA, les équipes cibles, les données autorisées et un résultat
mesurable. Choisir un cas d'usage assez fréquent pour produire un signal, mais assez borné pour être
testé sans risque.

## Pilote

Créer une application limitée à un petit groupe. Installer les intégrations et skills nécessaires,
assembler l'agent, puis tester avec des données représentatives. Documenter les permissions, les
limites et le propriétaire de chaque composant.

## Préproduction

Tester les erreurs d'accès, les données manquantes, les volumes réalistes et les reprises. Vérifier
les journaux, les coûts, les effets externes et la procédure de retrait. Obtenir l'accord humain avant
toute écriture autonome ou planification récurrente.

## Déploiement

Affecter l'application aux équipes prévues, former les utilisateurs sur le résultat attendu et le
chemin d'escalade, puis surveiller les premiers runs. Conserver les versions exactes déployées.

## Exploitation

Réviser périodiquement les connexions, permissions, erreurs, coûts et usages. Corriger la méthode
partagée lorsqu'une règle est réutilisable. Corriger l'agent lorsqu'un paramètre appartient seulement
à son déploiement.

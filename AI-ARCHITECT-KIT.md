# Kit Appstrate AI Architect

Ce kit s'adresse aux personnes qui conçoivent, configurent et déploient Appstrate dans une entreprise.
Il contient sept skills autonomes et portables.

## Contenu

1. `skill-authoring`, avec ses 14 méthodes de référence intégrées
2. `connector-choice`
3. `web-search`
4. `appstrate-google-workspace`
5. `agent-authoring`
6. `copilot`
7. `appstrate-builder`

Cet ordre est recommandé pour l'import afin que les guides spécialisés soient déjà disponibles quand
les orchestrateurs les recherchent. Il ne constitue pas une dépendance technique de package.

## Pourquoi les méthodes restent des références

Les méthodes couvrent la revue de code, la rédaction, le CRM, la recherche client, l'analyse de
données, l'extraction documentaire, les emails, les digests, les réunions, la réponse sourcée, la
recherche web, les rapports de sprint et le triage.

Elles sont des points de départ pour créer une méthode propre à une organisation. Les livrer comme 14
skills autonomes chargerait des capacités génériques même lorsqu'elles ne correspondent pas aux
processus, accès et critères de l'entreprise. `skill-authoring` lit uniquement la référence pertinente,
l'adapte, puis crée une skill appartenant à l'organisation si aucune méthode existante ne convient.

## Importer dans Appstrate

Construire l'archive globale :

```bash
bash scripts/build-ai-architect-kit.sh
```

Décompresser le ZIP global. Dans son dossier `packages`, importer chaque ZIP séparément depuis
l'interface, le MCP Appstrate ou la CLI, selon les opérations exposées par l'instance. Confirmer la
cible avant chaque mutation et relever le scope attribué par l'organisation.

Le ZIP global sert au partage. Il ne doit pas être envoyé directement à l'importeur d'une skill,
puisqu'il contient plusieurs skills. Les ZIP du dossier `packages` sont les archives importables.

## Installer dans un agent de coding

Copier chaque dossier souhaité depuis `skills` vers le catalogue de skills de l'agent. Conserver le
dossier complet pour préserver les références, scripts, licences et notices.

## Résolution entre skills

Les guides se référencent par nom non scopé. Dans Appstrate, l'agent recherche la skill accessible
correspondante et conserve ensuite son identifiant canonique `@scope/name`. Dans un agent de coding,
il utilise le catalogue local. Aucun guide ne présume que le scope `@appstrate` existe.

## Compatibilité

Les skills utilisent le format standard `SKILL.md`. Elles découvrent les contrats vivants depuis le
MCP Appstrate ou la CLI et son accès API. Elles ne dépendent pas du marqueur expérimental
`assistant-skill.enabled`, ni d'une distinction entre skills système et skills ordinaires.

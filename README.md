# Appstrate Skills

Ce dépôt distribue un kit de skills portables pour les architectes IA qui configurent Appstrate dans
leur entreprise. Les mêmes sources peuvent être utilisées depuis un agent de coding ou importées dans
une organisation Appstrate.

Ces skills sont optionnelles. Elles ne sont pas supposées être livrées par défaut sur une instance.
Chaque organisation les installe sous son propre scope.

## Kit Appstrate AI Architect

| Skill | Rôle |
| --- | --- |
| [`appstrate-builder`](skills/appstrate-builder/) | Auditer, concevoir, déployer et valider une implantation Appstrate |
| [`copilot`](skills/copilot/) | Découvrir des automatisations avec les utilisateurs et choisir leur forme |
| [`connector-choice`](skills/connector-choice/) | Choisir le meilleur mode d'accès à un service |
| [`agent-authoring`](skills/agent-authoring/) | Créer, modifier et prouver un agent Appstrate |
| [`skill-authoring`](skills/skill-authoring/) | Créer ou améliorer une méthode réutilisable |
| [`web-search`](skills/web-search/) | Effectuer une recherche web sourcée depuis Appstrate |
| [`appstrate-google-workspace`](skills/appstrate-google-workspace/) | Configurer et diagnostiquer Google Workspace MCP |

Les 14 méthodes métier du kit sont des références internes de `skill-authoring`. Elles servent de
matériau de création quand une organisation a besoin d'une méthode. Elles ne sont pas distribuées
comme skills autonomes.

Voir [`AI-ARCHITECT-KIT.md`](AI-ARCHITECT-KIT.md) pour l'installation et la construction du ZIP.

## Installation dans un agent de coding

Le script installe une skill à la fois :

```bash
curl -fsSL https://raw.githubusercontent.com/appstrate/skills/main/install.sh \
  | bash -s appstrate-builder
```

Des options existent pour Codex, Claude Code, Cursor, Google Antigravity et un chemin universel. Consulter
`bash install.sh --help` dans une copie locale du dépôt.

## Installation dans Appstrate

Construire le kit, puis importer chaque ZIP contenu dans son dossier `packages`. Chaque archive place
le `SKILL.md` à sa racine et peut être importée séparément dans l'organisation cible.

```bash
bash scripts/build-ai-architect-kit.sh
```

## Skills communautaires

Une liste de skills compatibles avec Appstrate est maintenue dans [`COMMUNITY.md`](COMMUNITY.md).

## Contribution

Consulter [`CONTRIBUTING.md`](CONTRIBUTING.md) pour proposer une skill first-party ou référencer une
skill communautaire.

Les skills first-party sont distribuées sous licence Apache 2.0. Les composants adaptés de sources
externes conservent les notices présentes dans leur dossier.

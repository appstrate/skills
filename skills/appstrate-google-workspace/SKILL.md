---
name: appstrate-google-workspace
description: Configurer, auditer, connecter et diagnostiquer les serveurs MCP Google Workspace dans Appstrate avec gcloud, le MCP local gcloud, le MCP Appstrate ou la CLI Appstrate. Utiliser pour Gmail MCP, Drive MCP, Docs, Sheets, Slides, Calendar, People ou Chat, pour les problèmes OAuth, scopes, utilisateurs test, IAM mcp.toolUser, services désactivés, Developer Preview, installation locale ou cloud, et pour valider les intégrations sans modifier les données Google.
---

# Google Workspace MCP dans Appstrate

Orchestrer le parcours automatisable avec les CLI, puis guider l’utilisateur uniquement aux points où Google exige une action humaine.

## Distinguer les trois couches

1. `@google-cloud/gcloud-mcp` est un serveur MCP local d’administration. Il exécute la CLI `gcloud` avec les permissions du compte actif.
2. Les serveurs MCP Google Workspace sont des services distants séparés pour Gmail, Drive, Docs, Sheets, Slides, Calendar, People et Chat.
3. Le MCP Appstrate et la CLI Appstrate administrent l’instance. Ce sont deux interfaces vers la même plateforme, avec des mécanismes de connexion distincts.
4. Les intégrations Appstrate décrivent les endpoints, scopes, politiques d’outils et connexions OAuth utilisées par les agents.

Une couche fonctionnelle ne prouve pas que les deux autres sont correctement configurées.

## Charger la référence

Lire [references/google-workspace-mcp.md](references/google-workspace-mcp.md) avant une installation, une activation, une migration de manifeste ou un diagnostic. Elle contient les services, endpoints, tests et erreurs connues.

## Parcours

### 1. Fixer la cible

Obtenir explicitement :

- le `PROJECT_ID` et son `PROJECT_NUMBER` ;
- le compte Google Workspace à connecter ;
- l’instance, l’organisation et l’application Appstrate ;
- l’interface Appstrate disponible, MCP, CLI ou les deux ;
- les produits Google à activer ;
- le mode demandé : audit, configuration ou diagnostic.

Ne jamais déduire le projet d’une configuration implicite pour une opération qui modifie Google Cloud. Utiliser `--project` sur chaque commande concernée. Pour Appstrate, confirmer la cible avec le MCP ou utiliser un profil CLI explicite.

### 2. Vérifier les identités avant toute modification

Exécuter :

```bash
gcloud config list --format='text(core.account,core.project)'
gcloud projects describe PROJECT_ID \
  --format='text(projectId,projectNumber,lifecycleState)'
```

Si le compte ou le projet ne correspond pas à la cible, arrêter les mutations et corriger la connexion.

Pour un audit complet, exécuter `scripts/audit-google-workspace-mcp.sh PROJECT_ID WORKSPACE_EMAIL`. Le script est en lecture seule.

### 3. Séparer automatisation et points humains

Déléguer au CLI : activation des services, lecture et attribution IAM autorisée, diagnostics, import des packages Appstrate, activation des intégrations et tests.

Guider l’utilisateur dans le navigateur pour :

- accepter les conditions et soumettre la candidature Developer Preview ;
- configurer Branding, Audience, Data Access et les utilisateurs test ;
- créer ou modifier le client OAuth Web Google Auth Platform ;
- configurer l’application Google Chat ;
- effectuer le consentement OAuth de chaque compte.

Google interdit la création et la modification programmatiques des clients OAuth Google classiques. Ne pas présenter `gcloud iam oauth-clients` comme un remplacement, car ces clients IAM ne couvrent pas les scopes Workspace requis.

### 4. Activer uniquement ce qui est demandé

Activer l’API produit et le service MCP correspondant. People utilise seulement `people.googleapis.com` pour les deux fonctions.

Traiter une modification IAM ou l’activation d’un service comme autorisée uniquement si la demande de l’utilisateur couvre cette configuration. Vérifier la cible juste avant l’appel.

### 5. Choisir l’interface Appstrate

Préférer le MCP Appstrate lorsqu’il est déjà connecté à la bonne organisation et expose l’opération requise. Appeler d’abord `get_me` pour confirmer l’identité, l’organisation, le rôle et les intégrations déjà connectées. Rechercher ensuite l’intention avec `search_operations`, utiliser son `best_match` si le contrat correspond, sinon appeler `describe_operation`, puis `invoke_operation`. Utiliser `run_and_wait` pour lancer un test et attendre directement son état terminal.

L’endpoint MCP Appstrate est propre à une organisation. Il n’existe aucun changement d’organisation pendant une session. Connecter un endpoint distinct pour chaque organisation et vérifier l’application effective avant une mutation.

Utiliser la CLI Appstrate quand le MCP n’est pas connecté, quand l’opération requiert un fichier local que le contrat MCP courant ne sait pas transporter, ou quand l’utilisateur demande explicitement la CLI. Lire l’aide de la version installée, choisir un profil explicite et utiliser `appstrate api` lorsque l’opération REST n’a pas de commande dédiée.

Ne pas mélanger les preuves : une lecture par MCP confirme la cible MCP, tandis qu’une lecture avec `appstrate -p PROFILE` confirme la cible CLI. Vérifier de nouveau la cible dans l’interface qui exécutera la mutation.

### 6. Configurer Appstrate sans exposer les secrets

Ne jamais afficher un client secret, un code de vérification, un jeton d’accès ou un jeton de rafraîchissement dans les sorties.

Réutiliser un secret présent dans un fichier d’environnement protégé sans le recopier dans le chat, Git, un manifeste ou un document. Utiliser un fichier temporaire protégé ou une variable en mémoire, puis effacer son contenu.

Utiliser le namespace propre à l’organisation cible pour les packages portables, par exemple `@acme/gmail-mcp`. Réserver `@appstrate/*` aux packages système distribués avec le produit. Ne jamais reprendre le namespace d’une autre entreprise comme convention générique.

Configurer chaque intégration avec :

- l’endpoint distant officiel ;
- `openid`, `email` et les scopes minimaux requis par ses outils ;
- l’équivalence de `https://www.googleapis.com/auth/userinfo.email` vers `email` ;
- le client OAuth Web Appstrate et sa callback exacte ;
- une connexion OAuth distincte par compte utilisateur.

### 7. Tester sans écriture

Commencer par les outils de lecture indiqués dans la référence. Ne créer, modifier, envoyer, déplacer ou supprimer aucune donnée pendant un test de connexion.

Pour un run Appstrate, vérifier les deux niveaux :

```text
status = success
output.success = true
```

Un run terminé techniquement peut contenir un échec fonctionnel dans sa sortie. Conserver l’identifiant du run et un résumé non sensible du résultat.

### 8. Diagnostiquer par couche

Classifier chaque erreur avant de corriger : service désactivé, programme Preview, IAM, OAuth, scope, configuration Chat, package Appstrate ou outil distant. Lire l’erreur amont et ne pas compenser une couche avec une permission sur une autre.

Après correction, relancer d’abord un seul outil de lecture. Étendre ensuite la validation aux autres produits et instances.

## Critères de fin

Terminer seulement lorsque :

- le compte et le projet cibles sont confirmés ;
- les services demandés sont activés ;
- l’accès IAM est vérifié ;
- les connexions OAuth sont établies avec les scopes attendus ;
- chaque produit demandé passe un test en lecture seule avec les deux statuts de succès ;
- les étapes encore humaines ou les changements système non déployés sont signalés clairement.

---
name: appstrate-builder
description: Concevoir, auditer, configurer, déployer et valider une implantation Appstrate pour une organisation et ses équipes. Utiliser pour installer ou reprendre une instance locale ou cloud, configurer organisations, applications, modèles, intégrations, connexions et skills, créer des agents, préparer le déploiement aux équipes et vérifier la mise en service avec le MCP ou la CLI Appstrate.
---

# Déployer Appstrate dans une organisation

Construis une implantation exploitable par les architectes IA et les équipes, depuis l'inventaire de
l'instance jusqu'aux premiers usages prouvés. Appuie chaque décision sur le contrat vivant de
l'instance ciblée. Ne présume ni des packages installés, ni des opérations disponibles.

## 1. Confirmer la cible et l'interface

Fixe l'instance, l'organisation, l'application, l'utilisateur et son rôle avant toute mutation.

Préfère le MCP Appstrate lorsqu'il est déjà connecté à la bonne organisation. Appelle `get_me`, puis
découvre l'opération requise avec la recherche et la description d'opérations disponibles. Utilise la
CLI si le MCP manque, si un fichier local doit être transmis ou si l'utilisateur la demande. Dans ce
cas, lis l'aide installée et confirme le profil avec `appstrate -p PROFILE whoami`.

Une preuve MCP ne confirme pas une cible CLI, et inversement. Vérifie de nouveau la cible dans
l'interface qui exécutera une modification.

## 2. Inventorier l'implantation réelle

Relève les éléments utiles au besoin : organisations, applications, utilisateurs, rôles, modèles,
intégrations, connexions, skills, agents et exécutions. Pour chaque capacité, distingue quatre états :

1. disponible dans le catalogue ;
2. installée dans l'organisation ;
3. activée pour l'application ;
4. connectée et testée pour l'utilisateur concerné.

Consigne les écarts entre local et cloud sans considérer l'un comme une copie implicite de l'autre.
Lis [references/verification-matrix.md](references/verification-matrix.md) pour structurer l'audit.

## 3. Concevoir le déploiement

Définis les équipes, leurs cas d'usage, les applications Appstrate nécessaires, les accès et les
responsables opérationnels. Commence par un parcours représentatif et mesurable. Étends ensuite le
déploiement lorsque le premier parcours est prouvé.

Sépare les responsabilités :

- une intégration fournit l'accès à un service ;
- une skill porte une méthode réutilisable ;
- un agent assemble une méthode, des accès et une configuration propre à un usage ;
- une application distribue cet ensemble à un groupe d'utilisateurs.

Lis [references/deployment-lifecycle.md](references/deployment-lifecycle.md) pour le passage du pilote
à l'exploitation.

## 4. Charger la bonne skill compagne

Ce kit utilise des skills autonomes qui peuvent être installées ensemble ou séparément :

| Besoin | Skill à charger |
| --- | --- |
| Découvrir et prioriser des automatisations avec un utilisateur | `copilot` |
| Choisir entre plusieurs intégrations ou modes d'accès | `connector-choice` |
| Créer, modifier ou valider un agent Appstrate | `agent-authoring` |
| Créer ou améliorer une méthode réutilisable | `skill-authoring` |
| Effectuer une recherche web depuis Appstrate | `web-search` |
| Configurer les MCP Google Workspace et leurs accès Google Cloud | `appstrate-google-workspace` |

Dans Appstrate, cherche la skill accessible dont le nom non scopé correspond, puis résous son
identifiant canonique `@scope/name` avant de la lire. Dans un agent de coding, utilise le catalogue de
skills local par son nom. Si la skill manque, signale la dépendance à installer. N'invente ni son
contenu, ni un scope `@appstrate`.

## 5. Installer et distribuer les skills

Conserve une source portable avec un `SKILL.md` standard et ses ressources relatives. Pour Appstrate,
importe chaque archive de skill séparément afin que le fichier `SKILL.md` soit à la racine de
l'archive. L'organisation cible attribue son scope lors de l'import.

Pour un agent de coding, installe le dossier complet selon le répertoire de skills pris en charge par
l'outil. Pour Appstrate, affecte ensuite les skills pertinentes aux applications ou agents qui les
consomment. La visibilité et les mécanismes d'activation peuvent évoluer. Découvre les capacités de
l'instance au lieu de dépendre d'un marqueur expérimental.

Lis [references/skill-portability.md](references/skill-portability.md) avant de partager le kit entre
plusieurs organisations ou environnements.

## 6. Configurer, puis prouver

Valide chaque artefact contre le schéma courant avant de le persister. Accorde uniquement les
permissions nécessaires au scénario. Garde les secrets dans les surfaces de connexion prévues.

Teste en trois temps :

1. une lecture sans effet externe ;
2. un run réel avec une entrée représentative ;
3. la relecture de l'état persisté, du résultat et des logs.

Un statut technique réussi ne suffit pas si la sortie métier contient un échec. Une configuration
locale ne prouve pas le cloud. Lorsque les deux cibles sont demandées, répète les contrôles sur chacune.

## 7. Livrer le dossier de déploiement

Restitue les cibles vérifiées, les packages et versions installés, les connexions testées, les agents
prouvés, les utilisateurs ou applications couverts, les décisions humaines restantes et les risques.
N'annonce une capacité comme fonctionnelle que si son test observable a réussi sur la cible annoncée.

Le travail est terminé lorsque l'organisation peut reproduire l'installation, identifier le
propriétaire de chaque composant et exécuter au moins un parcours représentatif de bout en bout.

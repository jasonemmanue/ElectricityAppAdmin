# Alertes admin — sonnerie et heures calmes

Comment une alerte admin (nouveau RDV, nouveau message, nouveau devis) décide de
sonner ou non, et comment la tester.

## Où se règle quoi

Onglet **Réglages** de l'app admin :

| Réglage | Effet |
|---|---|
| **Alertes urgentes (plein écran)** | Interrupteur maître. Coupé → plus rien ne sonne, jamais. |
| **Heures calmes** | Active la fenêtre nocturne. Par défaut **22:00 → 07:00**. |
| **Début** / **Fin** | Les bornes de cette fenêtre, à l'heure du téléphone. |

Pendant les heures calmes, **les alertes arrivent quand même** — elles ne font
simplement aucun bruit.

## Qui décide

La décision est prise **par les Cloud Functions, avant l'envoi du push** — pas
par l'app.

Elle était prise en local, dans le handler FCM Dart. Ça ne marchait que tant que
l'app était vivante : dès qu'elle est en arrière-plan ou fermée, Android affiche
le push lui-même à partir du canal indiqué dans le message et **aucun code Dart
ne s'exécute**. Une alerte à 3 h du matin sonnait donc malgré les heures calmes.

L'app fait deux choses :

1. **Elle synchronise sa politique** vers son document `admin_tokens/{token}`
   (via la fonction `updateAdminAlertPolicy`) — au démarrage, après chaque
   changement dans Réglages, et à chaque renouvellement du token FCM.
   Elle y joint le **décalage UTC du téléphone**
   (`DateTime.now().timeZoneOffset`), ce qui permet au serveur de savoir quelle
   heure il est *sur cet appareil précis*.
2. **Elle obéit au verdict du serveur.** Le push porte `ringDecision: "server"`
   dans ses données ; l'app ne recalcule pas, sinon elle risquerait de
   contredire ce que la barre de notifications a déjà fait en arrière-plan.

Côté serveur, `sendToAdmins` évalue chaque appareil séparément puis envoie deux
multicasts :

| Verdict | Canal Android | Rendu |
|---|---|---|
| sonne | `admin_channel_id_01` | son personnalisé, plein écran, priorité max |
| silencieux | `admin_channel_quiet_01` | arrive normalement, **sans son** |

Deux canaux sont nécessaires : Android fige l'importance et le son d'un canal à
sa création, donc couper le son du canal bruyant au moment de l'envoi est ignoré.

Détail complet et format stocké : [`functions/README.md`](../ElectricityApp/functions/README.md)
dans le dépôt de l'app client.

## Tester

### La logique horaire (sans téléphone)

```bash
cd ../ElectricityApp/functions
npm run build && npm test
```

Couvre le passage de minuit (22:00 → 07:00), les bornes inclusive/exclusive, les
fuseaux (UTC+1 silencieux pendant qu'UTC-5 sonne au même instant) et le parsing.

### De bout en bout, sur le téléphone

1. Dans **Réglages**, mets la fenêtre calme autour de l'heure actuelle
   (ex. début = maintenant − 1 min, fin = maintenant + 15 min).
2. Vérifie dans les logs de la fonction que la politique est bien montée :
   ```bash
   firebase functions:log --only updateAdminAlertPolicy
   ```
   Tu dois voir `Alert policy updated for uid=… urgent=true quiet=true 1320→420 offset=60min`.
3. **Ferme l'app admin** (c'est tout l'intérêt — en avant-plan le bug d'origine
   ne se voyait pas).
4. Depuis l'app client, crée un RDV.
5. Attendu : la notification arrive **sans son ni plein écran**.
   ```bash
   firebase functions:log --only onAppointmentCreated
   ```
   doit afficher `sendToAdmins "🔔 Nouveau RDV — …": 0 ringing, 1 quiet`.
6. Remets la fenêtre calme hors de l'heure actuelle et recommence : cette fois
   `1 ringing, 0 quiet`, avec son et écran d'alarme.

Si les logs annoncent `1 device(s) with no synced policy → ring`, c'est que
l'appareil n'a jamais synchronisé — ouvre l'app admin une fois en étant connecté.

## Les rappels programmés : ils sonnent toujours

Un **rappel de RDV** (Clients → un client → un rendez-vous) est une notification
**locale, côté administrateur** : l'admin la programme lui-même, sur son propre
téléphone, à une heure qu'il choisit. Aucun push, aucune Cloud Function, aucun
autre appareil.

Ne pas confondre avec les notifications de RDV envoyées **au client** (accepté,
en route, terminé…) : celles-là partent de `onAppointmentStatusChanged`, c'est un
tout autre chemin.

**Un rappel sonne quelle que soit l'heure**, heures calmes actives ou non. C'est
délibéré : les heures calmes existent pour amortir les alertes **entrantes**,
subies, dont personne n'a choisi l'horaire. Un rappel, c'est l'inverse — une
alarme réglée exprès pour cet instant précis.

Mais on prévient. Au moment où le rappel est programmé, si l'heure choisie tombe
dans la fenêtre calme (ou si les alertes urgentes sont coupées), la confirmation
le dit explicitement :

> Rappel programmé pour 12/08/2026 03:00. Il sonnera malgré vos heures calmes
> (22:00 → 07:00).

L'admin garde la main, il sait simplement à quoi s'attendre. Le message est en
orange et reste affiché plus longtemps que la confirmation normale.

### Prérequis : l'app doit être exemptée d'optimisation batterie

**C'est la cause n°1 d'un rappel qui ne sonne pas**, et ça ne se voit pas dans le
code.

Quand l'alarme se déclenche avec l'app fermée, le système doit démarrer le
processus pour exécuter `ScheduledNotificationReceiver`. Sur Samsung, il refuse
si l'app n'est pas exemptée. Constaté sur l'appareil : le broadcast arrivait
à `18:57:00.009` pile, **aucun `Start proc` derrière**, aucune notification
postée. Le rappel ne fonctionnait que si l'app était encore chaude.

L'app demande l'exemption au démarrage
(`Permission.ignoreBatteryOptimizations`), mais sur Samsung il faut souvent
aussi le faire à la main :

1. **Paramètres → Applications → SOS Electricity Admin → Batterie**
   → choisir **« Sans restriction »**
2. **Paramètres → Batterie → Limites d'utilisation en arrière-plan**
   → **« Applications en veille profonde »** : vérifier que l'app **n'y est pas**
   → idem pour **« Applications mises en veille »**

Vérification en ligne de commande :

```bash
adb shell dumpsys deviceidle whitelist | grep electricity
adb shell am get-standby-bucket com.example.electricity_app_admin   # 10 = ACTIVE
```

La première commande doit renvoyer une ligne. Si elle ne renvoie rien, l'app
n'est pas exemptée et les rappels ne partiront pas app fermée.

### Le rappel est joué sur le flux *alarme*

Un rappel utilise son propre canal, `admin_channel_alarm_01`, déclaré avec
`AudioAttributesUsage.alarm`.

Ce n'est pas cosmétique. Le canal des alertes, `admin_channel_id_01`, est en
`USAGE_NOTIFICATION` : son son passe par le flux « notification ». Un rappel
programmé y était posté **en silence** — vérifié sur l'appareil : l'alarme
système se déclenchait à la seconde près, la notification était bien postée
(`numPostedByApp=1`), mais elle n'alertait jamais (`numInterrupt=0`), alors que
le mode Ne pas déranger, le mode silencieux, l'importance du canal et les
permissions étaient tous hors de cause.

`USAGE_ALARM` la place sur le flux alarme, celui qui ne dépend pas du volume des
notifications. Il faut un canal distinct : Android fige les attributs audio d'un
canal à sa création, donc les modifier après coup est ignoré sans erreur — même
contrainte que pour le canal des heures calmes.

Pour vérifier sur un appareil branché :

```bash
adb shell dumpsys notification --noredact | grep admin_channel_alarm_01
```

Tu dois y lire `mImportance=5` et `usage=USAGE_ALARM`. Après le déclenchement
d'un rappel, `numInterrupt` doit avoir augmenté :

```bash
adb shell dumpsys notification --noredact | grep -A20 "key='com.example.electricity_app_admin'" | grep numInterrupt
```

Corollaire pour les tests : **ne teste pas les heures calmes via un rappel de
RDV**, ce chemin ne consulte pas la politique serveur. Utilise le parcours de la
section précédente.

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

## Limite connue

Les **rappels de RDV** programmés à la main (Clients → un client → un rendez-vous)
passent par `NotificationService.scheduleNotification`, une notification locale
qui ne consulte **ni** cette politique **ni** le serveur : elle force le canal
bruyant et le plein écran. Un rappel fixé à 3 h du matin sonnera donc même avec
les heures calmes actives. C'est discutable dans les deux sens — l'heure a été
choisie explicitement par l'admin — donc c'est laissé tel quel pour l'instant.

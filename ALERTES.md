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

## La sonnerie

`android/app/src/main/res/raw/notification_sound.mp3` — « Urgent simple tone
loop » (Mixkit, licence Mixkit : usage commercial libre, sans attribution),
recoupé à **exactement 7,000 s** avec un fondu de sortie de 150 ms, en 48 kHz
stéréo 128 kbps.

Deux contraintes si tu la remplaces :

- **Garde le nom de fichier.** Les canaux existants sur le téléphone de l'admin
  pointent vers `android.resource://<pkg>/raw/notification_sound`. Renommer le
  fichier casserait ce lien sans erreur — le canal jouerait le son par défaut.
- **Garde la durée à 7 s.** Elle est délibérée : assez longue pour réveiller,
  assez courte pour ne pas s'imposer (elle était à 60 s au départ).

```bash
ffmpeg -i source.mp3 -t 7 -af "afade=t=out:st=6.85:d=0.15" \
  -ar 48000 -ac 2 -b:a 128k android/app/src/main/res/raw/notification_sound.mp3
```

Le son n'est audible qu'après réinstallation de l'app : Android met en cache
l'URI du canal, pas le fichier, donc les nouveaux octets sont bien repris — mais
seulement au prochain démarrage du processus.

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

### Le receiver doit être déclaré dans le manifeste

**C'est ce qui empêchait tout rappel de se déclencher**, et l'échec est
totalement silencieux.

`flutter_local_notifications` ne déclare **aucun receiver** dans son propre
manifeste — uniquement des permissions. C'est donc à l'app de déclarer
`ScheduledNotificationReceiver`, faute de quoi : AlarmManager se déclenche à
l'heure pile, diffuse vers ce composant explicite, Android n'arrive pas à le
résoudre, et **le broadcast est jeté**. Aucun démarrage de processus, aucune
notification, aucune erreur dans logcat. Rien à quoi se raccrocher.

```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
```

Le boot receiver (`ScheduledNotificationBootReceiver`, qui reprogramme les
rappels après un redémarrage) doit être déclaré à part — il l'était déjà, ce qui
brouillait la piste : un receiver du plugin fonctionnait, l'autre non.

Vérifier dans l'APK réellement installé :

```bash
adb pull $(adb shell pm path com.example.electricity_app_admin | sed 's/package://') /tmp/a.apk
aapt2 dump xmltree /tmp/a.apk --file AndroidManifest.xml | grep ScheduledNotification
```

Les **deux** doivent apparaître.

### Recommandé : exempter l'app d'optimisation batterie

Secondaire, mais utile : quand l'alarme se déclenche app fermée depuis
longtemps, le système doit démarrer le processus pour exécuter le receiver, et
les gestions agressives d'arrière-plan peuvent le refuser.

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
n'est pas exemptée — à corriger avant de conclure quoi que ce soit sur un rappel
qui n'est pas parti alors que l'app était fermée depuis longtemps.

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

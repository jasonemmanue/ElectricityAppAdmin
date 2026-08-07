# Configuration du compte admin — SOS Electricity

Ce guide explique comment activer les privilèges administrateur sur un compte Firebase, pour que l'application `ElectricityAppAdmin` puisse s'y connecter.

L'application admin, à l'ouverture, effectue automatiquement un `signInWithEmailAndPassword` avec les valeurs du fichier local **`lib/config/admin_credentials.dart`** (gitignoré, jamais poussé). Après connexion, elle vérifie que le token contient un **custom claim** `admin: true`. Sans ce claim, l'app rejette la session et affiche « Ce compte n'a pas de privilèges admin ».

Il y a donc **deux choses à faire une seule fois** :

1. Créer le compte Firebase Auth (email + mot de passe)
2. Ajouter le custom claim `admin: true` sur son UID

---

## 1. Créer les identifiants locaux dans l'app

Le fichier `lib/config/admin_credentials.dart` **n'existe pas dans le repo** (il est gitignoré). Créez-le en copiant le template :

```bash
cp lib/config/admin_credentials.example.dart lib/config/admin_credentials.dart
```

Puis éditez `lib/config/admin_credentials.dart` et remplacez la valeur `REPLACE_ME` par le mot de passe que vous allez définir dans Firebase Console à l'étape suivante.

⚠️ **Ne jamais committer ce fichier** — il est déjà listé dans `.gitignore`.

---

## 2. Créer le compte Firebase Auth

1. Ouvrir la [Firebase Console](https://console.firebase.google.com) → projet **SOS Electricity**
2. Menu de gauche → **Authentication** → onglet **Users**
3. Si l'utilisateur `kammeugnejulio41@gmail.com` n'existe pas encore :
   - Cliquer **Add user**
   - Email : `kammeugnejulio41@gmail.com`
   - Password : celui que vous avez mis dans `admin_credentials.dart`
   - **Add user**
4. S'il existe déjà mais que vous ne connaissez plus le mot de passe :
   - Cliquer sur l'icône ⋮ à droite de sa ligne → **Reset password**
   - Firebase envoie un email de reset. Ouvrez le lien, définissez le mot de passe, et mettez la même valeur dans `admin_credentials.dart`.

**Notez le UID** de ce compte (colonne User UID) — vous en aurez besoin à l'étape 3.

---

## 3. Activer le custom claim `admin: true`

Firebase Auth n'a pas d'interface visuelle pour setter des custom claims. Il faut un petit script Node.js à exécuter **une seule fois**.

### 3.1 Récupérer une clé de service

1. Firebase Console → ⚙ (Project settings) → **Service accounts**
2. Cliquer **Generate new private key** → confirmer → un JSON est téléchargé
3. Renommer le fichier téléchargé en `serviceAccountKey.json` et le placer dans un dossier local hors du repo (jamais committer cette clé — elle donne les pleins pouvoirs sur le projet Firebase)

### 3.2 Écrire le script

Créer un fichier `set-admin-claim.js` dans le même dossier que la clé :

```javascript
// set-admin-claim.js — one-time script to grant admin custom claim
// Utilise l'API modulaire firebase-admin (v12+). L'ancien style
// `admin.credential.cert(...)` a été retiré dans les versions récentes.
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount),
});

// Remplacez cette valeur par l'UID récupéré à l'étape 2
const ADMIN_UID = 'COLLEZ_L_UID_ICI';

getAuth().setCustomUserClaims(ADMIN_UID, { admin: true })
  .then(() => {
    console.log(`OK — custom claim admin=true set on ${ADMIN_UID}`);
    return getAuth().getUser(ADMIN_UID);
  })
  .then((userRecord) => {
    console.log('User claims:', userRecord.customClaims);
    process.exit(0);
  })
  .catch((err) => {
    console.error('ERROR:', err);
    process.exit(1);
  });
```

### 3.3 Exécuter

```bash
npm init -y
npm install firebase-admin
node set-admin-claim.js
```

Sortie attendue :
```
OK — custom claim admin=true set on 4kNMwqM8Q2f...
User claims: { admin: true }
```

---

## 4. Vérifier depuis l'app admin

Le custom claim est stocké dans le token JWT du compte. Le token en cache doit être **rafraîchi** pour que le claim apparaisse :

- Dans l'app admin, si vous étiez déjà connecté avec ce compte : **se déconnecter puis se reconnecter**
- Sinon : lancer l'app admin directement — le code appelle `getIdTokenResult(true)` (le `true` force le refresh)

Vous devriez arriver directement sur le dashboard.

---

## 5. (Optionnel) Créer un document Firestore `users/{uid}`

Le code actuel ne le requiert pas (le contrôle est basé sur le custom claim), mais si vous voulez tracer l'admin dans Firestore :

1. Firebase Console → **Firestore Database**
2. Collection `users` → sous-collection avec le UID récupéré à l'étape 2
3. Ajouter les champs :
   - `email` (string) — `kammeugnejulio41@gmail.com`
   - `fullName` (string) — `Julio Kammeugne`
   - `role` (string) — `admin`
   - `createdAt` (timestamp) — maintenant

---

## Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| App admin affiche « Email ou mot de passe incorrect » | Password dans `admin_credentials.dart` ne correspond pas au Firebase Auth | Reset password dans la Console + resynchroniser le fichier local |
| App admin affiche « Ce compte n'a pas de privilèges admin » | Le custom claim n'est pas setté OU le token n'a pas été rafraîchi | Refaire l'étape 3, puis se déconnecter/reconnecter dans l'app |
| Le script `node set-admin-claim.js` erreur `PERMISSION_DENIED` | Le service account n'a pas les droits sur Firebase Auth | Régénérer la clé, ou vérifier le rôle IAM `Firebase Authentication Admin` |
| Le script erreur `Cannot find module 'firebase-admin'` | `npm install firebase-admin` n'a pas été exécuté | Le lancer dans le même dossier que le script |
| Le script erreur `TypeError: Cannot read properties of undefined (reading 'cert')` | Ancien style `admin.credential.cert()` retiré dans firebase-admin v13+ | Utiliser la version modulaire du script ci-dessus (`require('firebase-admin/app')`) |

---

## Sécurité

- Le fichier `serviceAccountKey.json` donne accès **root** au projet Firebase. Ne jamais le committer, ne jamais le partager en clair. Après avoir setté le claim, vous pouvez le supprimer ; il suffit d'en régénérer une nouvelle si besoin.
- Le fichier `lib/config/admin_credentials.dart` est gitignoré mais présent sur votre machine. Si vous partagez votre poste, verrouillez-le ou utilisez un password manager.
- Pour révoquer un admin : `admin.auth().setCustomUserClaims(uid, { admin: false })` puis se déconnecter/reconnecter de l'app.

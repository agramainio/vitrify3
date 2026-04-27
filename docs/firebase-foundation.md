# Firebase foundation notes

## Emulator import/export

Use emulator export data when you want staging-like test data to survive emulator restarts:

```sh
firebase emulators:start --only auth,firestore,storage,hosting --import .firebase/emulator-data --export-on-exit .firebase/emulator-data
```

To export the current emulator state manually:

```sh
firebase emulators:export .firebase/emulator-data
```

The emulator export is local test data. Do not treat it as production backup data.

## Firestore rules deployment

Deploy Firestore rules before pointing a staging or production build at real Firestore:

```sh
firebase deploy --only firestore:rules,firestore:indexes
```

This keeps atelier data protected by the owner-scoped rules before the hosted app can write real data.

## Storage rules deployment

Do not deploy Storage rules until the Firebase project has a real Storage bucket. Some Firebase projects cannot create a no-cost bucket in the selected region; deploying Storage rules before a bucket exists can fail or create confusion during staging setup.

The Storage emulator still uses `storage.rules`, so local/emulator validation can continue before the real bucket exists. Once a real bucket is enabled, deploy:

```sh
firebase deploy --only storage
```

Until Storage is enabled in staging, uploaded mold image files fail gracefully and the mold is saved without storing file bytes in Firestore. External image URLs remain supported and are stored as Firestore metadata.

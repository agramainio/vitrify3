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

## Anonymous staging identity

Staging currently uses Firebase anonymous Auth as the temporary identity source. Data is scoped to:

```text
origin + anonymous Firebase user + activeAtelierId
```

This means data created on a preview URL is not expected to appear automatically on `https://vitrify3.web.app`, because browser auth/local storage is origin-scoped. Data created on `https://vitrify3.web.app` should survive refresh in the same browser profile. If it does not, check whether the anonymous UID changed after refresh; a changed UID creates or loads a different atelier and the previous data will still exist in Firestore under the earlier atelier.

## Storage rules deployment

Do not deploy Storage rules until the Firebase project has a real Storage bucket. Some Firebase projects cannot create a no-cost bucket in the selected region; deploying Storage rules before a bucket exists can fail or create confusion during staging setup.

The Storage emulator still uses `storage.rules`, so local/emulator validation can continue before the real bucket exists. Once a real bucket is enabled, deploy:

```sh
firebase deploy --only storage
```

Until Storage is enabled in staging, uploaded mold image files fail gracefully and the mold is saved without storing file bytes in Firestore. External image URLs remain supported and are stored as Firestore metadata.

In staging preview builds without a working Storage bucket, the browser console may show a request similar to:

```text
POST https://firebasestorage.googleapis.com/... 403 (Forbidden)
```

That console error is expected during the temporary no-bucket staging period. The acceptance behavior is:

- The app starts normally.
- Mold creation is not blocked by the failed upload.
- The mold document persists after refresh.
- Firestore does not store base64 image bytes.
- External image URLs still work.

After a real Storage bucket exists and `storage.rules` has been deployed, this `403` should be treated as a real configuration or rules issue.

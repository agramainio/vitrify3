import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'app_environment.dart';
import 'firebase_studio_repository.dart';
import 'models.dart';
import 'studio_repository.dart';
import 'web_plugin_safety.dart';

class FirebaseAtelierSession {
  const FirebaseAtelierSession({
    required this.repository,
    required this.currentUser,
    required this.activeAtelier,
  });

  final StudioRepository repository;
  final StudioUser currentUser;
  final Atelier activeAtelier;
}

class FirebaseAtelierBootstrap {
  const FirebaseAtelierBootstrap._();

  static bool _servicesConfigured = false;

  static Future<FirebaseAtelierSession> start(
    VitrifyEnvironment environment,
  ) async {
    final session = await loadSessionForCurrentUser(environment);
    if (session == null) {
      throw StateError('No authenticated Firebase user is available.');
    }
    return session;
  }

  static Future<void> prepare(VitrifyEnvironment environment) async {
    if (!environment.usesFirebase) {
      throw StateError('Firebase bootstrap cannot run in demo mode.');
    }

    ensureWebPluginsRegistered();

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    final storage = FirebaseStorage.instance;

    if (!_servicesConfigured) {
      if (environment == VitrifyEnvironment.emulator) {
        await _connectEmulators(auth, firestore, storage);
      } else {
        firestore.settings = const Settings(persistenceEnabled: true);
      }
      _servicesConfigured = true;
    }

    if (kIsWeb) {
      await auth.setPersistence(Persistence.LOCAL);
    }
  }

  static Future<User?> restoreCurrentUser(
    VitrifyEnvironment environment,
  ) async {
    await prepare(environment);
    final auth = FirebaseAuth.instance;
    return auth.currentUser ??
        await auth.authStateChanges().first.timeout(
          const Duration(seconds: 2),
          onTimeout: () => auth.currentUser,
        );
  }

  static Future<UserCredential> createAccount({
    required VitrifyEnvironment environment,
    required String email,
    required String password,
  }) async {
    await prepare(environment);
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
    final user = credential.user;
    if (user != null) {
      await _ensureUserProfile(FirebaseFirestore.instance, user);
    }
    return credential;
  }

  static Future<UserCredential> signInWithEmail({
    required VitrifyEnvironment environment,
    required String email,
    required String password,
  }) async {
    await prepare(environment);
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user != null) {
      await _ensureUserProfile(FirebaseFirestore.instance, user);
    }
    return credential;
  }

  static Future<void> sendPasswordResetEmail({
    required VitrifyEnvironment environment,
    required String email,
  }) async {
    await prepare(environment);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') {
        return;
      }
      rethrow;
    }
  }

  static Future<UserCredential> signInAnonymouslyForTesting(
    VitrifyEnvironment environment,
  ) async {
    await prepare(environment);
    final credential = await FirebaseAuth.instance.signInAnonymously();
    final user = credential.user;
    if (user != null) {
      await _ensureUserProfile(FirebaseFirestore.instance, user);
    }
    return credential;
  }

  static Future<void> signOut(VitrifyEnvironment environment) async {
    await prepare(environment);
    await clearLocalBootstrapStateForCurrentUser(environment);
    await FirebaseAuth.instance.signOut();
  }

  static Future<FirebaseAtelierSession?> loadSessionForCurrentUser(
    VitrifyEnvironment environment, {
    bool createTemporaryAtelierIfMissing = false,
  }) async {
    await prepare(environment);
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    final storage = FirebaseStorage.instance;
    final firebaseUser =
        auth.currentUser ?? await restoreCurrentUser(environment);
    if (firebaseUser == null) {
      return null;
    }

    await _ensureUserProfile(firestore, firebaseUser);

    var activeAtelier = await _loadActiveAtelier(
      firestore: firestore,
      uid: firebaseUser.uid,
      environment: environment,
    );
    if (activeAtelier == null && createTemporaryAtelierIfMissing) {
      activeAtelier = await _createDefaultTestingAtelier(
        firestore: firestore,
        uid: firebaseUser.uid,
        environment: environment,
      );
      await _setActiveAtelierForUser(
        firestore: firestore,
        uid: firebaseUser.uid,
        environment: environment,
        atelierId: activeAtelier.atelierId,
      );
    }

    if (activeAtelier == null) {
      return null;
    }

    final currentUser = StudioUser(
      id: firebaseUser.uid,
      name: _displayNameFor(firebaseUser),
    );
    final repository = await FirebaseStudioRepository.create(
      firestore: firestore,
      storage: storage,
      atelier: activeAtelier,
      currentUser: currentUser,
      environment: environment,
    );

    return FirebaseAtelierSession(
      repository: repository,
      currentUser: currentUser,
      activeAtelier: activeAtelier,
    );
  }

  static Future<Atelier> createAtelierForCurrentUser({
    required VitrifyEnvironment environment,
    required String name,
    required String alias,
  }) async {
    await prepare(environment);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You must be signed in before creating an atelier.');
    }

    final firestore = FirebaseFirestore.instance;
    final normalizedAlias = normalizeAlias(alias);
    if (normalizedAlias.isEmpty) {
      throw StateError('Atelier alias is required.');
    }

    final ateliers = firestore.collection('ateliers');
    final aliases = firestore.collection('atelierAliases');
    final atelierRef = ateliers.doc();
    final aliasRef = aliases.doc(normalizedAlias);
    final now = DateTime.now();
    final status = environment == VitrifyEnvironment.production
        ? AtelierStatus.active
        : AtelierStatus.testing;

    try {
      await firestore.runTransaction((transaction) async {
        final aliasSnapshot = await transaction.get(aliasRef);
        if (aliasSnapshot.exists) {
          throw const _AliasReserved();
        }

        transaction.set(atelierRef, {
          'atelierId': atelierRef.id,
          'name': name.trim(),
          'alias': normalizedAlias,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'createdByUid': user.uid,
          'ownerUid': user.uid,
          'status': status.id,
        });
        transaction.set(aliasRef, {
          'alias': normalizedAlias,
          'atelierId': atelierRef.id,
          'ownerUid': user.uid,
          'createdAt': Timestamp.fromDate(now),
        });
      });
    } on _AliasReserved {
      throw StateError('This atelier alias is already taken.');
    }

    await atelierRef.collection('members').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'role': 'owner',
      'status': 'active',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    await _setActiveAtelierForUser(
      firestore: firestore,
      uid: user.uid,
      environment: environment,
      atelierId: atelierRef.id,
    );

    return Atelier(
      atelierId: atelierRef.id,
      name: name.trim(),
      alias: normalizedAlias,
      createdAt: now,
      updatedAt: now,
      createdByUid: user.uid,
      ownerUid: user.uid,
      status: status,
    );
  }

  static Future<void> clearLocalBootstrapStateForCurrentUser(
    VitrifyEnvironment environment,
  ) async {
    ensureWebPluginsRegistered();

    String? uid;
    try {
      if (Firebase.apps.isNotEmpty) {
        uid = FirebaseAuth.instance.currentUser?.uid;
      }
    } catch (_) {
      uid = null;
    }

    await clearLocalBootstrapState(environment, uid: uid);
  }

  static Future<void> clearLocalBootstrapState(
    VitrifyEnvironment environment, {
    String? uid,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final prefix = _activeAtelierPreferencePrefix(environment);
    final exactKey = uid == null || uid.isEmpty ? null : '$prefix$uid';

    for (final key in preferences.getKeys()) {
      if (key == exactKey || key.startsWith(prefix)) {
        await preferences.remove(key);
      }
    }
  }

  static Future<void> _connectEmulators(
    FirebaseAuth auth,
    FirebaseFirestore firestore,
    FirebaseStorage storage,
  ) async {
    const host = 'localhost';
    await auth.useAuthEmulator(host, 9099);
    firestore.useFirestoreEmulator(host, 8080);
    firestore.settings = const Settings(
      persistenceEnabled: false,
      sslEnabled: false,
    );
    storage.useStorageEmulator(host, 9199);
  }

  static String _displayNameFor(User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }

    return user.isAnonymous ? 'Temporary test user' : 'Atelier user';
  }

  static Future<Atelier?> _loadActiveAtelier({
    required FirebaseFirestore firestore,
    required String uid,
    required VitrifyEnvironment environment,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final preferenceKey = _activeAtelierPreferenceKey(environment, uid);
    final savedAtelierId = preferences.getString(preferenceKey);
    if (savedAtelierId != null && savedAtelierId.isNotEmpty) {
      try {
        final saved = await firestore
            .collection('ateliers')
            .doc(savedAtelierId)
            .get();
        if (saved.exists && _canUseAtelier(saved, uid)) {
          return _atelierFromSnapshot(saved);
        }
        await preferences.remove(preferenceKey);
      } on FirebaseException catch (error, stackTrace) {
        await preferences.remove(preferenceKey);
        _logFirebaseException(
          'Could not read saved activeAtelierId "$savedAtelierId"; clearing local state and continuing.',
          error,
          stackTrace,
        );
      }
    }

    final userSnapshot = await firestore.collection('users').doc(uid).get();
    final profileAtelierId = userSnapshot.data()?['activeAtelierId'];
    if (profileAtelierId is String && profileAtelierId.isNotEmpty) {
      try {
        final saved = await firestore
            .collection('ateliers')
            .doc(profileAtelierId)
            .get();
        if (saved.exists && _canUseAtelier(saved, uid)) {
          await preferences.setString(preferenceKey, profileAtelierId);
          return _atelierFromSnapshot(saved);
        }
      } on FirebaseException catch (error, stackTrace) {
        _logFirebaseException(
          'Could not read users/$uid.activeAtelierId "$profileAtelierId".',
          error,
          stackTrace,
        );
      }
    }

    final owned = await firestore
        .collection('ateliers')
        .where('ownerUid', isEqualTo: uid)
        .limit(1)
        .get();
    if (owned.docs.isNotEmpty) {
      final atelier = _atelierFromSnapshot(owned.docs.first);
      await _setActiveAtelierForUser(
        firestore: firestore,
        uid: uid,
        environment: environment,
        atelierId: atelier.atelierId,
      );
      return atelier;
    }

    try {
      final membership = await firestore
          .collectionGroup('members')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (membership.docs.isNotEmpty) {
        final atelierRef = membership.docs.first.reference.parent.parent;
        if (atelierRef != null) {
          final atelierSnapshot = await atelierRef.get();
          if (atelierSnapshot.exists) {
            final atelier = _atelierFromSnapshot(atelierSnapshot);
            await _setActiveAtelierForUser(
              firestore: firestore,
              uid: uid,
              environment: environment,
              atelierId: atelier.atelierId,
            );
            return atelier;
          }
        }
      }
    } on FirebaseException catch (error, stackTrace) {
      _logFirebaseException(
        'Could not query atelier memberships for user "$uid".',
        error,
        stackTrace,
      );
    }

    return null;
  }

  static bool _canUseAtelier(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String uid,
  ) {
    final data = snapshot.data();
    return data != null && data['ownerUid'] == uid;
  }

  static String _activeAtelierPreferencePrefix(VitrifyEnvironment environment) {
    return 'vitrify_active_atelier_${environment.name}_';
  }

  static String _activeAtelierPreferenceKey(
    VitrifyEnvironment environment,
    String uid,
  ) {
    return '${_activeAtelierPreferencePrefix(environment)}$uid';
  }

  static Future<void> _setActiveAtelierForUser({
    required FirebaseFirestore firestore,
    required String uid,
    required VitrifyEnvironment environment,
    required String atelierId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _activeAtelierPreferenceKey(environment, uid),
      atelierId,
    );
    await firestore.collection('users').doc(uid).set({
      'activeAtelierId': atelierId,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  static Future<void> _ensureUserProfile(
    FirebaseFirestore firestore,
    User user,
  ) async {
    final doc = firestore.collection('users').doc(user.uid);
    final snapshot = await doc.get();
    final now = DateTime.now();
    await doc.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'status': user.isAnonymous ? 'temporary' : 'active',
      if (!snapshot.exists) 'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));
  }

  static void _logFirebaseException(
    String context,
    FirebaseException error,
    StackTrace stackTrace,
  ) {
    debugPrint(
      '$context FirebaseException(${error.plugin}/${error.code}): ${error.message}',
    );
    debugPrintStack(stackTrace: stackTrace);
  }

  static Future<Atelier> _createDefaultTestingAtelier({
    required FirebaseFirestore firestore,
    required String uid,
    required VitrifyEnvironment environment,
  }) async {
    final ateliers = firestore.collection('ateliers');
    final aliases = firestore.collection('atelierAliases');
    final atelierRef = ateliers.doc();
    final now = DateTime.now();
    final uidPrefix = uid.substring(0, uid.length < 6 ? uid.length : 6);
    final baseAlias = normalizeAlias('testing-$uidPrefix');

    for (var attempt = 0; attempt < 30; attempt += 1) {
      final alias = attempt == 0 ? baseAlias : '$baseAlias-$attempt';
      final aliasRef = aliases.doc(alias);

      try {
        await firestore.runTransaction((transaction) async {
          final aliasSnapshot = await transaction.get(aliasRef);
          if (aliasSnapshot.exists) {
            throw const _AliasReserved();
          }

          transaction.set(atelierRef, {
            'atelierId': atelierRef.id,
            'name': 'Temporary testing atelier',
            'alias': alias,
            'createdAt': Timestamp.fromDate(now),
            'updatedAt': Timestamp.fromDate(now),
            'createdByUid': uid,
            'ownerUid': uid,
            'status': AtelierStatus.testing.id,
          });
          transaction.set(aliasRef, {
            'alias': alias,
            'atelierId': atelierRef.id,
            'ownerUid': uid,
            'createdAt': Timestamp.fromDate(now),
          });
        });

        await atelierRef.collection('members').doc(uid).set({
          'uid': uid,
          'role': 'owner',
          'status': 'temporary',
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));

        return Atelier(
          atelierId: atelierRef.id,
          name: 'Temporary testing atelier',
          alias: alias,
          createdAt: now,
          updatedAt: now,
          createdByUid: uid,
          ownerUid: uid,
          status: AtelierStatus.testing,
        );
      } on _AliasReserved {
        continue;
      }
    }

    throw StateError('Could not reserve a unique atelier alias.');
  }

  static Atelier _atelierFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Atelier document ${snapshot.id} is empty.');
    }

    return Atelier(
      atelierId: data._stringValue('atelierId', fallback: snapshot.id),
      name: data._stringValue('name', fallback: 'Atelier'),
      alias: data._stringValue('alias', fallback: snapshot.id),
      createdAt: data._dateValue('createdAt'),
      updatedAt: data._dateValue('updatedAt'),
      createdByUid: data._stringValue('createdByUid'),
      ownerUid: data._stringValue('ownerUid'),
      status: _atelierStatusFromId(data._stringValue('status')),
    );
  }
}

class _AliasReserved implements Exception {
  const _AliasReserved();
}

extension _AtelierDataRead on Map<String, dynamic> {
  String _stringValue(String key, {String fallback = ''}) {
    final value = this[key];
    return value is String && value.isNotEmpty ? value : fallback;
  }

  DateTime _dateValue(String key) {
    final value = this[key];
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }
}

AtelierStatus _atelierStatusFromId(String id) {
  for (final value in AtelierStatus.values) {
    if (value.id == id) {
      return value;
    }
  }
  return AtelierStatus.testing;
}

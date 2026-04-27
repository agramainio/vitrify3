import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'app_environment.dart';
import 'firebase_studio_repository.dart';
import 'models.dart';
import 'studio_repository.dart';

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

  static Future<FirebaseAtelierSession> start(
    VitrifyEnvironment environment,
  ) async {
    if (!environment.usesFirebase) {
      throw StateError('Firebase bootstrap cannot run in demo mode.');
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    final storage = FirebaseStorage.instance;

    if (environment == VitrifyEnvironment.emulator) {
      await _connectEmulators(auth, firestore, storage);
    } else {
      firestore.settings = const Settings(persistenceEnabled: true);
    }

    final firebaseUser = await _ensureSignedIn(auth);
    final currentUser = StudioUser(
      id: firebaseUser.uid,
      name: _displayNameFor(firebaseUser),
    );
    final activeAtelier = await _ensureActiveAtelier(
      firestore: firestore,
      uid: firebaseUser.uid,
      environment: environment,
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

  static Future<User> _ensureSignedIn(FirebaseAuth auth) async {
    final existing = auth.currentUser;
    if (existing != null) {
      return existing;
    }

    final credential = await auth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase Auth did not return a signed-in user.');
    }
    return user;
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

    return 'Testing user';
  }

  static Future<Atelier> _ensureActiveAtelier({
    required FirebaseFirestore firestore,
    required String uid,
    required VitrifyEnvironment environment,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final preferenceKey = 'vitrify_active_atelier_${environment.name}_$uid';
    final savedAtelierId = preferences.getString(preferenceKey);
    if (savedAtelierId != null && savedAtelierId.isNotEmpty) {
      final saved = await firestore
          .collection('ateliers')
          .doc(savedAtelierId)
          .get();
      if (saved.exists && saved.data()?['ownerUid'] == uid) {
        return _atelierFromSnapshot(saved);
      }
    }

    final owned = await firestore
        .collection('ateliers')
        .where('ownerUid', isEqualTo: uid)
        .limit(1)
        .get();
    if (owned.docs.isNotEmpty) {
      final atelier = _atelierFromSnapshot(owned.docs.first);
      await preferences.setString(preferenceKey, atelier.atelierId);
      return atelier;
    }

    final created = await _createDefaultTestingAtelier(
      firestore: firestore,
      uid: uid,
      environment: environment,
    );
    await preferences.setString(preferenceKey, created.atelierId);
    return created;
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
            'name': environment == VitrifyEnvironment.production
                ? 'Atelier'
                : 'Testing atelier',
            'alias': alias,
            'createdAt': Timestamp.fromDate(now),
            'updatedAt': Timestamp.fromDate(now),
            'createdByUid': uid,
            'ownerUid': uid,
            'status': environment == VitrifyEnvironment.production
                ? AtelierStatus.active.id
                : AtelierStatus.testing.id,
          });
          transaction.set(aliasRef, {
            'alias': alias,
            'atelierId': atelierRef.id,
            'ownerUid': uid,
            'createdAt': Timestamp.fromDate(now),
          });
        });

        return Atelier(
          atelierId: atelierRef.id,
          name: environment == VitrifyEnvironment.production
              ? 'Atelier'
              : 'Testing atelier',
          alias: alias,
          createdAt: now,
          updatedAt: now,
          createdByUid: uid,
          ownerUid: uid,
          status: environment == VitrifyEnvironment.production
              ? AtelierStatus.active
              : AtelierStatus.testing,
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

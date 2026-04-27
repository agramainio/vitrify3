import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'app_environment.dart';
import 'models.dart';
import 'studio_repository.dart';

class FirebaseStudioRepository extends ChangeNotifier
    implements StudioRepository {
  FirebaseStudioRepository._({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
    required Atelier atelier,
    required StudioUser currentUser,
    required VitrifyEnvironment environment,
  }) : _firestore = firestore,
       _storage = storage,
       _atelier = atelier,
       _currentUser = currentUser,
       _environment = environment;

  static Future<FirebaseStudioRepository> create({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
    required Atelier atelier,
    required StudioUser currentUser,
    required VitrifyEnvironment environment,
  }) async {
    final repository = FirebaseStudioRepository._(
      firestore: firestore,
      storage: storage,
      atelier: atelier,
      currentUser: currentUser,
      environment: environment,
    );
    await repository._loadInitialData();
    repository._startListeners();
    return repository;
  }

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final Atelier _atelier;
  final StudioUser _currentUser;
  final VitrifyEnvironment _environment;
  final Random _random = Random();
  final Set<String> _reservedGeneratedPieceIds = <String>{};
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _subscriptions = [];

  List<Mold> _molds = <Mold>[];
  List<StudioColor> _colors = <StudioColor>[];
  List<LinkedRecord> _linkedRecords = <LinkedRecord>[];
  List<Piece> _pieces = <Piece>[];
  String? _lastWarning;

  @override
  String? consumeLastWarning() {
    final warning = _lastWarning;
    _lastWarning = null;
    return warning;
  }

  void _recordWarning(String warning) {
    _lastWarning = warning;
    notifyListeners();
  }

  DocumentReference<Map<String, dynamic>> get _atelierDoc {
    return _firestore.collection('ateliers').doc(_atelier.atelierId);
  }

  CollectionReference<Map<String, dynamic>> _atelierCollection(String name) {
    return _atelierDoc.collection(name);
  }

  CollectionReference<Map<String, dynamic>> get _moldsCollection {
    return _atelierCollection('molds');
  }

  CollectionReference<Map<String, dynamic>> get _colorsCollection {
    return _atelierCollection('colors');
  }

  CollectionReference<Map<String, dynamic>> get _piecesCollection {
    return _atelierCollection('pieces');
  }

  CollectionReference<Map<String, dynamic>> _linkedCollection(
    PieceDestination destination,
  ) {
    return _atelierCollection(
      destination == PieceDestination.order ? 'orders' : 'workshops',
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final results = await Future.wait([
      _moldsCollection.get(),
      _colorsCollection.get(),
      _linkedCollection(PieceDestination.order).get(),
      _linkedCollection(PieceDestination.workshop).get(),
      _piecesCollection.get(),
    ]);

    _molds = results[0].docs.map(_moldFromDoc).toList(growable: false);
    _colors = results[1].docs.map(_colorFromDoc).toList(growable: false);
    _linkedRecords = [
      ...results[2].docs.map(
        (doc) => _linkedRecordFromDoc(doc, PieceDestination.order),
      ),
      ...results[3].docs.map(
        (doc) => _linkedRecordFromDoc(doc, PieceDestination.workshop),
      ),
    ];
    _pieces = results[4].docs.map(_pieceFromDoc).toList(growable: false);
  }

  void _startListeners() {
    _subscriptions.addAll([
      _moldsCollection.snapshots().listen((snapshot) {
        _molds = snapshot.docs.map(_moldFromDoc).toList(growable: false);
        notifyListeners();
      }),
      _colorsCollection.snapshots().listen((snapshot) {
        _colors = snapshot.docs.map(_colorFromDoc).toList(growable: false);
        notifyListeners();
      }),
      _linkedCollection(PieceDestination.order).snapshots().listen((snapshot) {
        _replaceLinkedRecords(
          PieceDestination.order,
          snapshot.docs.map(
            (doc) => _linkedRecordFromDoc(doc, PieceDestination.order),
          ),
        );
      }),
      _linkedCollection(PieceDestination.workshop).snapshots().listen((
        snapshot,
      ) {
        _replaceLinkedRecords(
          PieceDestination.workshop,
          snapshot.docs.map(
            (doc) => _linkedRecordFromDoc(doc, PieceDestination.workshop),
          ),
        );
      }),
      _piecesCollection.snapshots().listen((snapshot) {
        _pieces = snapshot.docs.map(_pieceFromDoc).toList(growable: false);
        notifyListeners();
      }),
    ]);
  }

  void _replaceLinkedRecords(
    PieceDestination destination,
    Iterable<LinkedRecord> records,
  ) {
    _linkedRecords = [
      ..._linkedRecords.where((record) => record.destination != destination),
      ...records,
    ];
    notifyListeners();
  }

  @override
  List<Mold> suggestMolds(String query, {int limit = 8}) {
    return _sortByStartsWith(
      items: _molds.where((mold) => mold.active).toList(growable: false),
      query: query,
      normalizedValueOf: (mold) => mold.normalizedName,
      labelOf: (mold) => mold.name,
      limit: limit,
    );
  }

  @override
  Mold? findExactMold(String query) {
    return _findExact(
      items: _molds.where((mold) => mold.active),
      query: query,
      normalizedValueOf: (mold) => mold.normalizedName,
    );
  }

  @override
  int matchingMoldCount(String query) {
    return _matchingCount(
      items: _molds.where((mold) => mold.active),
      query: query,
      normalizedValueOf: (mold) => mold.normalizedName,
    );
  }

  @override
  List<Mold> allMolds({bool includeInactive = false}) {
    final molds = includeInactive
        ? _molds
        : _molds.where((mold) => mold.active).toList(growable: false);
    final sorted = molds.toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    return List<Mold>.unmodifiable(sorted);
  }

  @override
  Future<Mold> createMold({
    required String name,
    String? description,
    MoldSize? size,
    MoldImageReference? imageReference,
    int targetReadyStock = 0,
    double defaultPrice = 0,
  }) async {
    if (findExactMold(name) != null) {
      throw StateError('Mold names must be unique.');
    }

    final now = DateTime.now();
    final doc = _moldsCollection.doc(
      'mold_${now.microsecondsSinceEpoch}_${_randomSuffix()}',
    );
    final persistedImage = await _persistImageReference(
      imageReference,
      moldId: doc.id,
    );
    final mold = Mold(
      id: doc.id,
      name: name.trim(),
      normalizedName: normalizeSearch(name),
      description: _emptyToNull(description),
      size: size,
      imageReference: persistedImage,
      targetReadyStock: targetReadyStock,
      defaultPrice: defaultPrice,
      createdAt: now,
    );

    await doc.set(_moldToFirestore(mold, updatedAt: now));
    return mold;
  }

  @override
  Future<Mold> updateMold(Mold mold) async {
    final duplicate = _molds.any(
      (item) =>
          item.id != mold.id &&
          item.active &&
          item.normalizedName == mold.normalizedName,
    );
    if (duplicate) {
      throw StateError('Mold names must be unique.');
    }

    final now = DateTime.now();
    MoldImageReference? existingImage;
    for (final item in _molds) {
      if (item.id == mold.id) {
        existingImage = item.imageReference;
        break;
      }
    }
    final persistedImage = await _persistImageReference(
      mold.imageReference,
      moldId: mold.id,
      fallbackOnUploadFailure: existingImage,
    );
    final saved = mold.copyWith(imageReference: persistedImage);
    await _moldsCollection
        .doc(saved.id)
        .set(_moldToFirestore(saved, updatedAt: now), SetOptions(merge: true));
    await _updatePiecesForMold(saved);
    return saved;
  }

  @override
  Future<void> deleteMold(String moldId) async {
    await _moldsCollection.doc(moldId).set({
      'active': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  @override
  List<StudioColor> suggestColors(String query, {int limit = 8}) {
    return _sortByStartsWith(
      items: _colors.where((color) => color.active).toList(growable: false),
      query: query,
      normalizedValueOf: (color) => color.normalizedName,
      labelOf: (color) => color.name,
      limit: limit,
    );
  }

  @override
  StudioColor? findExactColor(String query) {
    return _findExact(
      items: _colors.where((color) => color.active),
      query: query,
      normalizedValueOf: (color) => color.normalizedName,
    );
  }

  @override
  int matchingColorCount(String query) {
    return _matchingCount(
      items: _colors.where((color) => color.active),
      query: query,
      normalizedValueOf: (color) => color.normalizedName,
    );
  }

  @override
  Future<StudioColor> createColor({required String name}) async {
    final existing = findExactColor(name);
    if (existing != null) {
      return existing;
    }

    final now = DateTime.now();
    final doc = _colorsCollection.doc('color_${_slugOrFallback(name)}');
    final color = StudioColor(
      id: doc.id,
      name: name.trim(),
      normalizedName: normalizeSearch(name),
      createdAt: now,
    );
    await doc.set(_colorToFirestore(color));
    return color;
  }

  @override
  List<LinkedRecord> suggestLinkedRecords(
    PieceDestination destination,
    String query, {
    int limit = 8,
  }) {
    return _sortByStartsWith(
      items: _linkedRecords
          .where((record) => record.destination == destination)
          .toList(growable: false),
      query: query,
      normalizedValueOf: (record) => record.normalizedLabel,
      labelOf: (record) => record.label,
      limit: limit,
    );
  }

  @override
  LinkedRecord? findExactLinkedRecord(
    PieceDestination destination,
    String query,
  ) {
    return _findExact(
      items: _linkedRecords.where(
        (record) => record.destination == destination,
      ),
      query: query,
      normalizedValueOf: (record) => record.normalizedLabel,
    );
  }

  @override
  Future<LinkedRecord> createLinkedRecord({
    required PieceDestination destination,
    required String label,
  }) async {
    final existing = findExactLinkedRecord(destination, label);
    if (existing != null) {
      return existing;
    }

    final now = DateTime.now();
    final prefix = destination == PieceDestination.order ? 'order' : 'workshop';
    final doc = _linkedCollection(
      destination,
    ).doc('${prefix}_${now.microsecondsSinceEpoch}_${_randomSuffix()}');
    final record = LinkedRecord(
      id: doc.id,
      label: label.trim(),
      normalizedLabel: normalizeSearch(label),
      destination: destination,
      createdAt: now,
    );
    await doc.set(_linkedRecordToFirestore(record));
    return record;
  }

  @override
  Future<List<Piece>> createPieces({
    required Mold mold,
    required int quantity,
    required List<StudioColor> colors,
    required double price,
    required PieceDestination destination,
    required CommercialState commercialState,
    LinkedRecord? linkedRecord,
    StudioUser? createdBy,
  }) async {
    final now = DateTime.now();
    final groupId = quantity > 1
        ? 'piece_group_${now.microsecondsSinceEpoch}_${_randomSuffix()}'
        : null;
    final created = List<Piece>.generate(quantity, (index) {
      final timestamp = now.add(Duration(milliseconds: index));
      return Piece(
        id: _generatePieceId(mold: mold, colors: colors),
        mold: mold,
        stage: PieceStage.toFire,
        colors: List<StudioColor>.unmodifiable(colors),
        price: price,
        destination: destination,
        linkedRecord: linkedRecord,
        commercialState: commercialState,
        createdAt: timestamp,
        updatedAt: timestamp,
        creationGroupId: groupId,
        createdByUserId: createdBy?.id ?? _currentUser.id,
        createdByUserName: createdBy?.name ?? _currentUser.name,
      );
    });

    final batch = _firestore.batch();
    for (final piece in created) {
      batch.set(_piecesCollection.doc(piece.id), _pieceToFirestore(piece));
    }
    await batch.commit();
    return created;
  }

  @override
  Future<Piece> updatePiece(Piece piece) async {
    final index = _pieces.indexWhere((item) => item.id == piece.id);
    final existing = index == -1 ? null : _pieces[index];
    if (existing == null) {
      await _piecesCollection.doc(piece.id).set(_pieceToFirestore(piece));
      return piece;
    }

    final identityChanged =
        existing.mold.id != piece.mold.id ||
        !_sameColorIds(existing.colors, piece.colors);

    if (identityChanged) {
      final now = DateTime.now();
      final createdFromEdit = piece.copyWith(
        id: _generatePieceId(mold: piece.mold, colors: piece.colors),
        createdAt: now,
        updatedAt: now,
        creationGroupId: null,
      );
      await _piecesCollection
          .doc(createdFromEdit.id)
          .set(_pieceToFirestore(createdFromEdit));
      return createdFromEdit;
    }

    final saved = piece.copyWith(updatedAt: DateTime.now());
    await _piecesCollection
        .doc(saved.id)
        .set(_pieceToFirestore(saved), SetOptions(merge: true));
    return saved;
  }

  @override
  Future<List<Piece>> updatePieces(List<Piece> pieces) async {
    final updated = <Piece>[];
    for (final piece in pieces) {
      updated.add(await updatePiece(piece));
    }
    return updated;
  }

  @override
  Future<void> deletePiece(String pieceId) async {
    await _piecesCollection.doc(pieceId).delete();
  }

  @override
  Future<void> deletePieces(List<String> pieceIds) async {
    final batch = _firestore.batch();
    for (final pieceId in pieceIds) {
      batch.delete(_piecesCollection.doc(pieceId));
    }
    await batch.commit();
  }

  @override
  List<Piece> allPieces() {
    final sorted = _pieces.toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return List<Piece>.unmodifiable(sorted);
  }

  @override
  int countPiecesByStage(PieceStage stage) {
    return _pieces
        .where((piece) => piece.stage == stage && !piece.failed)
        .length;
  }

  @override
  List<Piece> recentPieces({int limit = 8}) {
    return allPieces().take(limit).toList(growable: false);
  }

  Future<MoldImageReference?> _persistImageReference(
    MoldImageReference? imageReference, {
    required String moldId,
    MoldImageReference? fallbackOnUploadFailure,
  }) async {
    if (imageReference == null) {
      return null;
    }

    final bytes = imageReference.bytes;
    if (bytes == null) {
      final hasStoragePath =
          imageReference.imageSource == 'storage' ||
          (imageReference.imagePath?.trim().isNotEmpty ?? false);
      if (hasStoragePath) {
        return imageReference.copyWith(bytes: null);
      }

      final externalUrl = imageReference.sourceUrl?.trim();
      if (externalUrl != null && externalUrl.isNotEmpty) {
        return imageReference.copyWith(
          bytes: null,
          imageSource: 'external_url',
          imagePath: null,
          imageUrl: externalUrl,
        );
      }

      return imageReference;
    }

    final contentType = imageReference.mimeType ?? 'image/jpeg';
    final extension = _imageExtension(imageReference.fileName, contentType);
    final path = 'ateliers/${_atelier.atelierId}/molds/$moldId/main.$extension';
    final reference = _storage.ref(path);
    String downloadUrl;
    try {
      await reference.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      downloadUrl = await reference.getDownloadURL();
    } on FirebaseException {
      if (_environment != VitrifyEnvironment.staging) {
        rethrow;
      }

      _recordWarning(
        'Image upload is unavailable in staging because Firebase Storage is not enabled. '
        'The mold was saved without the uploaded image. Paste an image URL to attach one for now.',
      );
      return fallbackOnUploadFailure;
    }
    final uploadedAt = DateTime.now();

    return imageReference.copyWith(
      bytes: null,
      sourceUrl: downloadUrl,
      imageSource: 'storage',
      imagePath: path,
      imageUrl: downloadUrl,
      uploadedAt: uploadedAt,
      uploadedByUid: _currentUser.id,
    );
  }

  Future<void> _updatePiecesForMold(Mold mold) async {
    final snapshot = await _piecesCollection
        .where('moldId', isEqualTo: mold.id)
        .get();
    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    final moldFields = _embeddedMoldToFirestore(mold);
    for (final doc in snapshot.docs) {
      batch.set(doc.reference, moldFields, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Map<String, dynamic> _moldToFirestore(
    Mold mold, {
    required DateTime updatedAt,
  }) {
    return {
      'atelierId': _atelier.atelierId,
      'name': mold.name,
      'normalizedName': mold.normalizedName,
      'description': mold.description,
      'size': mold.size?.id,
      'targetReadyStock': mold.targetReadyStock,
      'defaultPrice': mold.defaultPrice,
      'active': mold.active,
      'createdAt': Timestamp.fromDate(mold.createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdByUid': _currentUser.id,
      ..._imageToFirestore(mold.imageReference),
    };
  }

  Map<String, dynamic> _embeddedMoldToFirestore(Mold mold) {
    return {
      'moldId': mold.id,
      'moldName': mold.name,
      'moldNormalizedName': mold.normalizedName,
      'moldDescription': mold.description,
      'moldSize': mold.size?.id,
      'moldDefaultPrice': mold.defaultPrice,
      ..._imageToFirestore(mold.imageReference, prefix: 'mold'),
    };
  }

  Map<String, dynamic> _imageToFirestore(
    MoldImageReference? image, {
    String prefix = '',
  }) {
    String key(String value) {
      if (prefix.isEmpty) {
        return value;
      }
      return '$prefix${value[0].toUpperCase()}${value.substring(1)}';
    }

    return {
      key('imageSource'): image?.imageSource,
      key('imagePath'): image?.imagePath,
      key('imageUrl'): image?.imageUrl ?? image?.sourceUrl,
      key('imageFileName'): image?.fileName,
      key('imageMimeType'): image?.mimeType,
      key('imageSizeBytes'): image?.sizeBytes,
      key('imageUploadedAt'): image?.uploadedAt == null
          ? null
          : Timestamp.fromDate(image!.uploadedAt!),
      key('imageUploadedByUid'): image?.uploadedByUid,
    };
  }

  Map<String, dynamic> _colorToFirestore(StudioColor color) {
    return {
      'atelierId': _atelier.atelierId,
      'name': color.name,
      'normalizedName': color.normalizedName,
      'active': color.active,
      'createdAt': Timestamp.fromDate(color.createdAt),
      'createdByUid': _currentUser.id,
    };
  }

  Map<String, dynamic> _linkedRecordToFirestore(LinkedRecord record) {
    return {
      'atelierId': _atelier.atelierId,
      'label': record.label,
      'normalizedLabel': record.normalizedLabel,
      'destination': record.destination.id,
      'createdAt': Timestamp.fromDate(record.createdAt),
      'createdByUid': _currentUser.id,
    };
  }

  Map<String, dynamic> _pieceToFirestore(Piece piece) {
    return {
      'atelierId': _atelier.atelierId,
      'id': piece.id,
      ..._embeddedMoldToFirestore(piece.mold),
      'stage': piece.stage.id,
      'colors': piece.colors.map(_embeddedColorToFirestore).toList(),
      'colorIds': piece.colors.map((color) => color.id).toList(),
      'price': piece.price,
      'destination': piece.destination.id,
      'linkedRecord': piece.linkedRecord == null
          ? null
          : _linkedRecordToEmbeddedFirestore(piece.linkedRecord!),
      'failureRecord': piece.failureRecord == null
          ? null
          : _failureToFirestore(piece.failureRecord!),
      'commercialState': piece.commercialState.id,
      'createdAt': Timestamp.fromDate(piece.createdAt),
      'updatedAt': Timestamp.fromDate(piece.updatedAt),
      'creationGroupId': piece.creationGroupId,
      'createdByUserId': piece.createdByUserId,
      'createdByUserName': piece.createdByUserName,
      'createdByUid': piece.createdByUserId,
    };
  }

  Map<String, dynamic> _embeddedColorToFirestore(StudioColor color) {
    return {
      'id': color.id,
      'name': color.name,
      'normalizedName': color.normalizedName,
      'createdAt': Timestamp.fromDate(color.createdAt),
      'active': color.active,
    };
  }

  Map<String, dynamic> _linkedRecordToEmbeddedFirestore(LinkedRecord record) {
    return {
      'id': record.id,
      'label': record.label,
      'normalizedLabel': record.normalizedLabel,
      'destination': record.destination.id,
      'createdAt': Timestamp.fromDate(record.createdAt),
    };
  }

  Map<String, dynamic> _failureToFirestore(FailureRecord failure) {
    return {
      'reason': failure.reason,
      'notes': failure.notes,
      'recordedAt': Timestamp.fromDate(failure.recordedAt),
    };
  }

  Mold _moldFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Mold(
      id: doc.id,
      name: data.stringValue('name'),
      normalizedName: data.stringValue(
        'normalizedName',
        fallback: normalizeSearch(data.stringValue('name')),
      ),
      description: data.nullableString('description'),
      size: _moldSizeFromId(data.nullableString('size')),
      imageReference: _imageFromFirestore(data),
      targetReadyStock: data.intValue('targetReadyStock'),
      defaultPrice: data.doubleValue('defaultPrice'),
      active: data.boolValue('active', fallback: true),
      createdAt: data.dateValue('createdAt'),
    );
  }

  StudioColor _colorFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return StudioColor(
      id: doc.id,
      name: data.stringValue('name'),
      normalizedName: data.stringValue(
        'normalizedName',
        fallback: normalizeSearch(data.stringValue('name')),
      ),
      createdAt: data.dateValue('createdAt'),
      active: data.boolValue('active', fallback: true),
    );
  }

  LinkedRecord _linkedRecordFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    PieceDestination fallbackDestination,
  ) {
    final data = doc.data();
    return LinkedRecord(
      id: doc.id,
      label: data.stringValue('label'),
      normalizedLabel: data.stringValue(
        'normalizedLabel',
        fallback: normalizeSearch(data.stringValue('label')),
      ),
      destination:
          _destinationFromId(data.nullableString('destination')) ??
          fallbackDestination,
      createdAt: data.dateValue('createdAt'),
    );
  }

  Piece _pieceFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final mold = _embeddedMoldFromFirestore(data);
    return Piece(
      id: data.stringValue('id', fallback: doc.id),
      mold: mold,
      stage: _stageFromId(data.nullableString('stage')) ?? PieceStage.toFire,
      colors: data.embeddedColors(),
      price: data.doubleValue('price'),
      destination:
          _destinationFromId(data.nullableString('destination')) ??
          PieceDestination.stock,
      linkedRecord: data.embeddedLinkedRecord(),
      failureRecord: data.failureRecord(),
      commercialState:
          _commercialStateFromId(data.nullableString('commercialState')) ??
          CommercialState.available,
      createdAt: data.dateValue('createdAt'),
      updatedAt: data.dateValue('updatedAt'),
      creationGroupId: data.nullableString('creationGroupId'),
      createdByUserId: data.nullableString('createdByUserId'),
      createdByUserName: data.nullableString('createdByUserName'),
    );
  }

  Mold _embeddedMoldFromFirestore(Map<String, dynamic> data) {
    final moldName = data.stringValue('moldName');
    return Mold(
      id: data.stringValue('moldId'),
      name: moldName,
      normalizedName: data.stringValue(
        'moldNormalizedName',
        fallback: normalizeSearch(moldName),
      ),
      description: data.nullableString('moldDescription'),
      size: _moldSizeFromId(data.nullableString('moldSize')),
      imageReference: _imageFromFirestore(data, prefix: 'mold'),
      defaultPrice: data.doubleValue('moldDefaultPrice'),
      createdAt: data.dateValue('moldCreatedAt', fallback: DateTime.now()),
    );
  }

  MoldImageReference? _imageFromFirestore(
    Map<String, dynamic> data, {
    String prefix = '',
  }) {
    String key(String value) {
      if (prefix.isEmpty) {
        return value;
      }
      return '$prefix${value[0].toUpperCase()}${value.substring(1)}';
    }

    final imageUrl = data.nullableString(key('imageUrl'));
    final imagePath = data.nullableString(key('imagePath'));
    final fileName = data.nullableString(key('imageFileName')) ?? imageUrl;
    if (imageUrl == null && imagePath == null && fileName == null) {
      return null;
    }

    return MoldImageReference(
      fileName: fileName ?? imagePath ?? 'image',
      mimeType: data.nullableString(key('imageMimeType')),
      sizeBytes: data.intValue(key('imageSizeBytes')),
      sourceUrl: imageUrl,
      imageSource: data.nullableString(key('imageSource')),
      imagePath: imagePath,
      imageUrl: imageUrl,
      uploadedAt: data.nullableDate(key('imageUploadedAt')),
      uploadedByUid: data.nullableString(key('imageUploadedByUid')),
    );
  }

  T? _findExact<T>({
    required Iterable<T> items,
    required String query,
    required String Function(T item) normalizedValueOf,
  }) {
    final normalizedQuery = normalizeSearch(query);
    if (normalizedQuery.isEmpty) {
      return null;
    }

    for (final item in items) {
      if (normalizedValueOf(item) == normalizedQuery) {
        return item;
      }
    }

    return null;
  }

  int _matchingCount<T>({
    required Iterable<T> items,
    required String query,
    required String Function(T item) normalizedValueOf,
  }) {
    final normalizedQuery = normalizeSearch(query);
    if (normalizedQuery.isEmpty) {
      return 0;
    }

    return items
        .where((item) => normalizedValueOf(item).contains(normalizedQuery))
        .length;
  }

  List<T> _sortByStartsWith<T>({
    required List<T> items,
    required String query,
    required String Function(T item) normalizedValueOf,
    required String Function(T item) labelOf,
    required int limit,
  }) {
    final normalizedQuery = normalizeSearch(query);
    final filtered = normalizedQuery.isEmpty
        ? items
        : items
              .where(
                (item) => normalizedValueOf(item).contains(normalizedQuery),
              )
              .toList(growable: false);

    final sorted = filtered.toList()
      ..sort((left, right) {
        final leftStarts = normalizedValueOf(left).startsWith(normalizedQuery);
        final rightStarts = normalizedValueOf(
          right,
        ).startsWith(normalizedQuery);
        if (leftStarts != rightStarts) {
          return leftStarts ? -1 : 1;
        }
        return labelOf(left).compareTo(labelOf(right));
      });

    return sorted.take(limit).toList(growable: false);
  }

  bool _sameColorIds(List<StudioColor> left, List<StudioColor> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index += 1) {
      if (left[index].id != right[index].id) {
        return false;
      }
    }

    return true;
  }

  String _generatePieceId({
    required Mold mold,
    required List<StudioColor> colors,
  }) {
    for (;;) {
      final candidate = buildPieceId(
        mold: mold,
        colors: colors,
        suffix: _randomSuffix(),
      );
      final existsInCache = _pieces.any((piece) => piece.id == candidate);
      if (!existsInCache && !_reservedGeneratedPieceIds.contains(candidate)) {
        _reservedGeneratedPieceIds.add(candidate);
        return candidate;
      }
    }
  }

  String _randomSuffix() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List<String>.generate(
      4,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }

  String _slugOrFallback(String value) {
    final slug = pieceIdSegment(value);
    if (slug.isEmpty) {
      return '${DateTime.now().microsecondsSinceEpoch}_${_randomSuffix()}';
    }
    return slug;
  }

  String _imageExtension(String fileName, String contentType) {
    final lowerName = fileName.toLowerCase();
    final nameMatch = RegExp(r'\.([a-z0-9]+)$').firstMatch(lowerName);
    if (nameMatch != null) {
      return nameMatch.group(1)!;
    }
    if (contentType.contains('png')) {
      return 'png';
    }
    if (contentType.contains('webp')) {
      return 'webp';
    }
    return 'jpg';
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}

extension _FirestoreMapRead on Map<String, dynamic> {
  String stringValue(String key, {String fallback = ''}) {
    final value = this[key];
    return value is String && value.isNotEmpty ? value : fallback;
  }

  String? nullableString(String key) {
    final value = this[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  int intValue(String key, {int fallback = 0}) {
    final value = this[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return fallback;
  }

  double doubleValue(String key, {double fallback = 0}) {
    final value = this[key];
    if (value is num) {
      return value.toDouble();
    }
    return fallback;
  }

  bool boolValue(String key, {bool fallback = false}) {
    final value = this[key];
    return value is bool ? value : fallback;
  }

  DateTime dateValue(String key, {DateTime? fallback}) {
    return nullableDate(key) ?? fallback ?? DateTime.now();
  }

  DateTime? nullableDate(String key) {
    final value = this[key];
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  List<StudioColor> embeddedColors() {
    final values = this['colors'];
    if (values is! List) {
      return const <StudioColor>[];
    }

    return values
        .whereType<Map>()
        .map((raw) {
          final data = Map<String, dynamic>.from(raw);
          final name = data.stringValue('name');
          return StudioColor(
            id: data.stringValue('id'),
            name: name,
            normalizedName: data.stringValue(
              'normalizedName',
              fallback: normalizeSearch(name),
            ),
            createdAt: data.dateValue('createdAt'),
            active: data.boolValue('active', fallback: true),
          );
        })
        .toList(growable: false);
  }

  LinkedRecord? embeddedLinkedRecord() {
    final value = this['linkedRecord'];
    if (value is! Map) {
      return null;
    }
    final data = Map<String, dynamic>.from(value);
    final destination = _destinationFromId(data.nullableString('destination'));
    if (destination == null) {
      return null;
    }
    final label = data.stringValue('label');
    return LinkedRecord(
      id: data.stringValue('id'),
      label: label,
      normalizedLabel: data.stringValue(
        'normalizedLabel',
        fallback: normalizeSearch(label),
      ),
      destination: destination,
      createdAt: data.dateValue('createdAt'),
    );
  }

  FailureRecord? failureRecord() {
    final value = this['failureRecord'];
    if (value is! Map) {
      return null;
    }
    final data = Map<String, dynamic>.from(value);
    final reason = data.stringValue('reason');
    if (reason.isEmpty) {
      return null;
    }
    return FailureRecord(
      reason: reason,
      notes: data.nullableString('notes'),
      recordedAt: data.dateValue('recordedAt'),
    );
  }
}

MoldSize? _moldSizeFromId(String? id) {
  for (final value in MoldSize.values) {
    if (value.id == id) {
      return value;
    }
  }
  return null;
}

PieceStage? _stageFromId(String? id) {
  for (final value in PieceStage.values) {
    if (value.id == id) {
      return value;
    }
  }
  return null;
}

PieceDestination? _destinationFromId(String? id) {
  for (final value in PieceDestination.values) {
    if (value.id == id) {
      return value;
    }
  }
  return null;
}

CommercialState? _commercialStateFromId(String? id) {
  for (final value in CommercialState.values) {
    if (value.id == id) {
      return value;
    }
  }
  return null;
}

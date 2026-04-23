import 'dart:math';

import 'package:flutter/material.dart';

import 'models.dart';
import 'studio_repository.dart';

class DemoStudioRepository extends ChangeNotifier implements StudioRepository {
  DemoStudioRepository({
    List<Mold>? molds,
    List<StudioColor>? colors,
    List<LinkedRecord>? linkedRecords,
    List<Piece>? pieces,
  }) : _molds = molds ?? <Mold>[],
       _colors = colors ?? <StudioColor>[],
       _linkedRecords = linkedRecords ?? <LinkedRecord>[],
       _pieces = pieces ?? <Piece>[];

  factory DemoStudioRepository.seeded() {
    final now = DateTime.now();
    final molds = <Mold>[
      Mold(
        id: 'mold-cup-classic',
        name: 'Classic Cup',
        normalizedName: normalizeSearch('Classic Cup'),
        size: 'M',
        targetReadyStock: 10,
        defaultPrice: 28,
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      Mold(
        id: 'mold-ripple-bowl',
        name: 'Ripple Bowl',
        normalizedName: normalizeSearch('Ripple Bowl'),
        size: 'L',
        targetReadyStock: 8,
        defaultPrice: 42,
        createdAt: now.subtract(const Duration(days: 7)),
      ),
      Mold(
        id: 'mold-oval-plate',
        name: 'Oval Plate',
        normalizedName: normalizeSearch('Oval Plate'),
        size: 'XL',
        targetReadyStock: 6,
        defaultPrice: 38,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ];

    final colors = <StudioColor>[
      StudioColor(
        id: 'color-cloud-blue',
        name: 'Cloud Blue',
        normalizedName: normalizeSearch('Cloud Blue'),
        createdAt: now.subtract(const Duration(days: 21)),
      ),
      StudioColor(
        id: 'color-bone-white',
        name: 'Bone White',
        normalizedName: normalizeSearch('Bone White'),
        createdAt: now.subtract(const Duration(days: 18)),
      ),
      StudioColor(
        id: 'color-rust-line',
        name: 'Rust Line',
        normalizedName: normalizeSearch('Rust Line'),
        createdAt: now.subtract(const Duration(days: 12)),
      ),
    ];

    final linkedRecords = <LinkedRecord>[
      LinkedRecord(
        id: 'order-001',
        label: 'Order 001 - Martin',
        normalizedLabel: normalizeSearch('Order 001 - Martin'),
        destination: PieceDestination.order,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      LinkedRecord(
        id: 'order-002',
        label: 'Order 002 - Villa Pine',
        normalizedLabel: normalizeSearch('Order 002 - Villa Pine'),
        destination: PieceDestination.order,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      LinkedRecord(
        id: 'workshop-spring-pinch',
        label: 'Spring Pinch Workshop',
        normalizedLabel: normalizeSearch('Spring Pinch Workshop'),
        destination: PieceDestination.workshop,
        createdAt: now.subtract(const Duration(days: 4)),
      ),
    ];

    final pieces = <Piece>[
      Piece(
        id: buildPieceId(mold: molds[0], colors: [colors[0]], suffix: 'A1B2'),
        mold: molds[0],
        stage: PieceStage.toFire,
        colors: [colors[0]],
        price: 28,
        destination: PieceDestination.stock,
        commercialState: CommercialState.available,
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
      Piece(
        id: buildPieceId(
          mold: molds[1],
          colors: [colors[1], colors[2]],
          suffix: 'C3D4',
        ),
        mold: molds[1],
        stage: PieceStage.toFire,
        colors: [colors[1], colors[2]],
        price: 42,
        destination: PieceDestination.order,
        linkedRecord: linkedRecords[0],
        commercialState: CommercialState.reserved,
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      Piece(
        id: buildPieceId(mold: molds[1], colors: [colors[2]], suffix: 'E5F6'),
        mold: molds[1],
        stage: PieceStage.toGlaze,
        colors: [colors[2]],
        price: 42,
        destination: PieceDestination.workshop,
        linkedRecord: linkedRecords[2],
        commercialState: CommercialState.reserved,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 8)),
      ),
      Piece(
        id: buildPieceId(mold: molds[2], colors: [colors[1]], suffix: 'G7H8'),
        mold: molds[2],
        stage: PieceStage.ready,
        colors: [colors[1]],
        price: 38,
        destination: PieceDestination.stock,
        commercialState: CommercialState.available,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    return DemoStudioRepository(
      molds: molds,
      colors: colors,
      linkedRecords: linkedRecords,
      pieces: pieces,
    );
  }

  final List<Mold> _molds;
  final List<StudioColor> _colors;
  final List<LinkedRecord> _linkedRecords;
  final List<Piece> _pieces;
  final Random _random = Random();

  int _moldCounter = 100;
  int _colorCounter = 100;
  int _linkCounter = 100;

  @override
  List<Mold> suggestMolds(String query, {int limit = 8}) {
    return _sortByStartsWith(
      items: _molds.where((item) => item.active).toList(growable: false),
      query: query,
      normalizedValueOf: (item) => item.normalizedName,
      labelOf: (item) => item.name,
      limit: limit,
    );
  }

  @override
  Mold? findExactMold(String query) {
    return _findExact(
      items: _molds.where((item) => item.active),
      query: query,
      normalizedValueOf: (item) => item.normalizedName,
    );
  }

  @override
  int matchingMoldCount(String query) {
    return _matchingCount(
      items: _molds.where((item) => item.active),
      query: query,
      normalizedValueOf: (item) => item.normalizedName,
    );
  }

  @override
  Future<Mold> createMold({
    required String name,
    String? size,
    int targetReadyStock = 0,
    double defaultPrice = 0,
  }) async {
    final existing = findExactMold(name);
    if (existing != null) {
      return existing;
    }

    _moldCounter += 1;
    final mold = Mold(
      id: 'mold-$_moldCounter',
      name: name.trim(),
      normalizedName: normalizeSearch(name),
      size: size,
      targetReadyStock: targetReadyStock,
      defaultPrice: defaultPrice,
      createdAt: DateTime.now(),
    );
    _molds.add(mold);
    notifyListeners();
    return mold;
  }

  @override
  List<StudioColor> suggestColors(String query, {int limit = 8}) {
    return _sortByStartsWith(
      items: _colors.where((item) => item.active).toList(growable: false),
      query: query,
      normalizedValueOf: (item) => item.normalizedName,
      labelOf: (item) => item.name,
      limit: limit,
    );
  }

  @override
  StudioColor? findExactColor(String query) {
    return _findExact(
      items: _colors.where((item) => item.active),
      query: query,
      normalizedValueOf: (item) => item.normalizedName,
    );
  }

  @override
  int matchingColorCount(String query) {
    return _matchingCount(
      items: _colors.where((item) => item.active),
      query: query,
      normalizedValueOf: (item) => item.normalizedName,
    );
  }

  @override
  Future<StudioColor> createColor({required String name}) async {
    final existing = findExactColor(name);
    if (existing != null) {
      return existing;
    }

    _colorCounter += 1;
    final color = StudioColor(
      id: 'color-$_colorCounter',
      name: name.trim(),
      normalizedName: normalizeSearch(name),
      createdAt: DateTime.now(),
    );
    _colors.add(color);
    notifyListeners();
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
      normalizedValueOf: (item) => item.normalizedLabel,
      labelOf: (item) => item.label,
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
      normalizedValueOf: (item) => item.normalizedLabel,
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

    _linkCounter += 1;
    final prefix = destination == PieceDestination.order ? 'order' : 'workshop';
    final record = LinkedRecord(
      id: '$prefix-$_linkCounter',
      label: label.trim(),
      normalizedLabel: normalizeSearch(label),
      destination: destination,
      createdAt: DateTime.now(),
    );
    _linkedRecords.add(record);
    notifyListeners();
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
  }) async {
    final now = DateTime.now();
    final created = List<Piece>.generate(quantity, (index) {
      return Piece(
        id: _generatePieceId(mold: mold, colors: colors),
        mold: mold,
        stage: PieceStage.toFire,
        colors: List<StudioColor>.unmodifiable(colors),
        price: price,
        destination: destination,
        linkedRecord: linkedRecord,
        commercialState: commercialState,
        createdAt: now.add(Duration(milliseconds: index)),
        updatedAt: now.add(Duration(milliseconds: index)),
      );
    });

    _pieces.addAll(created);
    notifyListeners();
    return created;
  }

  @override
  Future<Piece> updatePiece(Piece piece) async {
    final index = _pieces.indexWhere((item) => item.id == piece.id);
    if (index == -1) {
      _pieces.insert(0, piece);
      notifyListeners();
      return piece;
    }

    final existing = _pieces[index];
    final identityChanged =
        existing.mold.id != piece.mold.id ||
        !_sameColorIds(existing.colors, piece.colors);

    if (identityChanged) {
      final now = DateTime.now();
      final createdFromEdit = piece.copyWith(
        id: _generatePieceId(mold: piece.mold, colors: piece.colors),
        createdAt: now,
        updatedAt: now,
      );
      _pieces.insert(0, createdFromEdit);
      notifyListeners();
      return createdFromEdit;
    }

    _pieces[index] = piece.copyWith(updatedAt: DateTime.now());
    notifyListeners();
    return _pieces[index];
  }

  @override
  Future<void> deletePiece(String pieceId) async {
    _pieces.removeWhere((piece) => piece.id == pieceId);
    notifyListeners();
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

    for (var index = 0; index < left.length; index++) {
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
      if (_pieces.every((piece) => piece.id != candidate)) {
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
}

import 'dart:typed_data';

enum AtelierStatus {
  active('active', 'Active'),
  inactive('inactive', 'Inactive'),
  testing('testing', 'Testing');

  const AtelierStatus(this.id, this.label);

  final String id;
  final String label;
}

enum PieceStage {
  toFire('to_fire', 'To fire'),
  toGlaze('bisque_fired', 'To glaze'),
  ready('ready', 'Ready');

  const PieceStage(this.id, this.label);

  final String id;
  final String label;
}

enum PieceDestination {
  stock('stock', 'Stock'),
  order('order', 'Order'),
  workshop('workshop', 'Workshop');

  const PieceDestination(this.id, this.label);

  final String id;
  final String label;
}

enum CommercialState {
  available('available', 'Available'),
  reserved('reserved', 'Reserved'),
  soldDelivered('sold_delivered', 'Sold / delivered');

  const CommercialState(this.id, this.label);

  final String id;
  final String label;
}

enum MoldSize {
  micro('micro', 'micro'),
  small('small', 'small'),
  medium('medium', 'medium'),
  large('large', 'large'),
  extraLarge('extra_large', 'extra large');

  const MoldSize(this.id, this.label);

  final String id;
  final String label;
}

class Atelier {
  const Atelier({
    required this.atelierId,
    required this.name,
    required this.alias,
    required this.createdAt,
    required this.updatedAt,
    required this.createdByUid,
    required this.ownerUid,
    required this.status,
  });

  final String atelierId;
  final String name;
  final String alias;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdByUid;
  final String ownerUid;
  final AtelierStatus status;
}

class Mold {
  const Mold({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.createdAt,
    required this.defaultPrice,
    this.description,
    this.size,
    this.imageReference,
    this.targetReadyStock = 0,
    this.active = true,
  });

  final String id;
  final String name;
  final String normalizedName;
  final DateTime createdAt;
  final double defaultPrice;
  final String? description;
  final MoldSize? size;
  final MoldImageReference? imageReference;
  final int targetReadyStock;
  final bool active;

  Mold copyWith({
    String? id,
    String? name,
    String? normalizedName,
    DateTime? createdAt,
    double? defaultPrice,
    Object? description = _moldSentinel,
    Object? size = _moldSentinel,
    Object? imageReference = _moldSentinel,
    int? targetReadyStock,
    bool? active,
  }) {
    return Mold(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      createdAt: createdAt ?? this.createdAt,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      description: identical(description, _moldSentinel)
          ? this.description
          : description as String?,
      size: identical(size, _moldSentinel) ? this.size : size as MoldSize?,
      imageReference: identical(imageReference, _moldSentinel)
          ? this.imageReference
          : imageReference as MoldImageReference?,
      targetReadyStock: targetReadyStock ?? this.targetReadyStock,
      active: active ?? this.active,
    );
  }
}

const Object _moldSentinel = Object();

class MoldImageReference {
  const MoldImageReference({
    required this.fileName,
    required this.sizeBytes,
    this.mimeType,
    this.bytes,
    this.sourceUrl,
    this.imageSource,
    this.imagePath,
    this.imageUrl,
    this.uploadedAt,
    this.uploadedByUid,
  });

  final String fileName;
  final String? mimeType;
  final int sizeBytes;
  final Uint8List? bytes;
  final String? sourceUrl;
  final String? imageSource;
  final String? imagePath;
  final String? imageUrl;
  final DateTime? uploadedAt;
  final String? uploadedByUid;

  MoldImageReference copyWith({
    String? fileName,
    String? mimeType,
    int? sizeBytes,
    Object? bytes = _imageSentinel,
    Object? sourceUrl = _imageSentinel,
    Object? imageSource = _imageSentinel,
    Object? imagePath = _imageSentinel,
    Object? imageUrl = _imageSentinel,
    Object? uploadedAt = _imageSentinel,
    Object? uploadedByUid = _imageSentinel,
  }) {
    return MoldImageReference(
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      bytes: identical(bytes, _imageSentinel)
          ? this.bytes
          : bytes as Uint8List?,
      sourceUrl: identical(sourceUrl, _imageSentinel)
          ? this.sourceUrl
          : sourceUrl as String?,
      imageSource: identical(imageSource, _imageSentinel)
          ? this.imageSource
          : imageSource as String?,
      imagePath: identical(imagePath, _imageSentinel)
          ? this.imagePath
          : imagePath as String?,
      imageUrl: identical(imageUrl, _imageSentinel)
          ? this.imageUrl
          : imageUrl as String?,
      uploadedAt: identical(uploadedAt, _imageSentinel)
          ? this.uploadedAt
          : uploadedAt as DateTime?,
      uploadedByUid: identical(uploadedByUid, _imageSentinel)
          ? this.uploadedByUid
          : uploadedByUid as String?,
    );
  }
}

const Object _imageSentinel = Object();

class StudioUser {
  const StudioUser({required this.id, required this.name});

  final String id;
  final String name;
}

class StudioColor {
  const StudioColor({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.createdAt,
    this.active = true,
  });

  final String id;
  final String name;
  final String normalizedName;
  final DateTime createdAt;
  final bool active;
}

class LinkedRecord {
  const LinkedRecord({
    required this.id,
    required this.label,
    required this.normalizedLabel,
    required this.destination,
    required this.createdAt,
  });

  final String id;
  final String label;
  final String normalizedLabel;
  final PieceDestination destination;
  final DateTime createdAt;
}

class FailureRecord {
  const FailureRecord({
    required this.reason,
    required this.recordedAt,
    this.notes,
  });

  final String reason;
  final String? notes;
  final DateTime recordedAt;

  FailureRecord copyWith({
    String? reason,
    String? notes,
    DateTime? recordedAt,
  }) {
    return FailureRecord(
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }
}

class Piece {
  const Piece({
    required this.id,
    required this.mold,
    required this.stage,
    required this.colors,
    required this.price,
    required this.destination,
    required this.commercialState,
    required this.createdAt,
    required this.updatedAt,
    this.creationGroupId,
    this.createdByUserId,
    this.createdByUserName,
    this.linkedRecord,
    this.failureRecord,
  });

  final String id;
  final Mold mold;
  final PieceStage stage;
  final List<StudioColor> colors;
  final double price;
  final PieceDestination destination;
  final LinkedRecord? linkedRecord;
  final FailureRecord? failureRecord;
  final CommercialState commercialState;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? creationGroupId;
  final String? createdByUserId;
  final String? createdByUserName;

  bool get failed => failureRecord != null;

  Piece copyWith({
    String? id,
    Mold? mold,
    PieceStage? stage,
    List<StudioColor>? colors,
    double? price,
    PieceDestination? destination,
    LinkedRecord? linkedRecord,
    Object? failureRecord = _pieceSentinel,
    CommercialState? commercialState,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? creationGroupId = _pieceSentinel,
    Object? createdByUserId = _pieceSentinel,
    Object? createdByUserName = _pieceSentinel,
  }) {
    return Piece(
      id: id ?? this.id,
      mold: mold ?? this.mold,
      stage: stage ?? this.stage,
      colors: colors ?? this.colors,
      price: price ?? this.price,
      destination: destination ?? this.destination,
      linkedRecord: linkedRecord ?? this.linkedRecord,
      failureRecord: identical(failureRecord, _pieceSentinel)
          ? this.failureRecord
          : failureRecord as FailureRecord?,
      commercialState: commercialState ?? this.commercialState,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      creationGroupId: identical(creationGroupId, _pieceSentinel)
          ? this.creationGroupId
          : creationGroupId as String?,
      createdByUserId: identical(createdByUserId, _pieceSentinel)
          ? this.createdByUserId
          : createdByUserId as String?,
      createdByUserName: identical(createdByUserName, _pieceSentinel)
          ? this.createdByUserName
          : createdByUserName as String?,
    );
  }
}

const Object _pieceSentinel = Object();

CommercialState defaultCommercialStateForDestination(
  PieceDestination destination,
) {
  switch (destination) {
    case PieceDestination.stock:
      return CommercialState.available;
    case PieceDestination.order:
    case PieceDestination.workshop:
      return CommercialState.reserved;
  }
}

String normalizeSearch(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String normalizeAlias(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return normalized.isEmpty ? 'atelier' : normalized;
}

String pieceIdSegment(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

String buildPieceId({
  required Mold mold,
  required List<StudioColor> colors,
  required String suffix,
}) {
  final colorSegments = colors.isEmpty
      ? const ['no_color']
      : colors
            .map((color) => pieceIdSegment(color.name))
            .where((segment) => segment.isNotEmpty);
  final segments = <String>[
    pieceIdSegment(mold.name),
    ...colorSegments,
    suffix.trim().toUpperCase(),
  ].where((segment) => segment.isNotEmpty);

  return segments.join('_');
}

String formatPrice(double value) {
  final rounded = value.toStringAsFixed(2);
  if (rounded.endsWith('.00')) {
    return rounded.substring(0, rounded.length - 3);
  }

  if (rounded.endsWith('0')) {
    return rounded.substring(0, rounded.length - 1);
  }

  return rounded;
}

String formatPriceEuro(double value) {
  return '${formatPrice(value)} €';
}

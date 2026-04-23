import 'package:flutter/foundation.dart';

import 'models.dart';

abstract class StudioRepository extends Listenable {
  List<Mold> suggestMolds(String query, {int limit = 8});

  Mold? findExactMold(String query);

  int matchingMoldCount(String query);

  Future<Mold> createMold({
    required String name,
    String? size,
    int targetReadyStock = 0,
    double defaultPrice = 0,
  });

  List<StudioColor> suggestColors(String query, {int limit = 8});

  StudioColor? findExactColor(String query);

  int matchingColorCount(String query);

  Future<StudioColor> createColor({required String name});

  List<LinkedRecord> suggestLinkedRecords(
    PieceDestination destination,
    String query, {
    int limit = 8,
  });

  LinkedRecord? findExactLinkedRecord(
    PieceDestination destination,
    String query,
  );

  Future<LinkedRecord> createLinkedRecord({
    required PieceDestination destination,
    required String label,
  });

  Future<List<Piece>> createPieces({
    required Mold mold,
    required int quantity,
    required List<StudioColor> colors,
    required double price,
    required PieceDestination destination,
    required CommercialState commercialState,
    LinkedRecord? linkedRecord,
  });

  Future<Piece> updatePiece(Piece piece);

  Future<void> deletePiece(String pieceId);

  List<Piece> allPieces();

  int countPiecesByStage(PieceStage stage);

  List<Piece> recentPieces({int limit = 8});
}

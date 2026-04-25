import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitrify3/src/app.dart';
import 'package:vitrify3/src/design_system.dart';
import 'package:vitrify3/src/demo_studio_repository.dart';
import 'package:vitrify3/src/models.dart';
import 'package:vitrify3/src/piece_editor_screen.dart';

const _testUser = StudioUser(id: 'user-test', name: 'Nora');

void main() {
  test(
    'repository creates readable IDs and preserves physical history',
    () async {
      final repository = DemoStudioRepository.seeded();
      final mold = repository.findExactMold('Classic Cup')!;
      final replacementMold = repository.findExactMold('Ripple Bowl')!;
      final color = repository.findExactColor('Bone White')!;
      final replacementColor = repository.findExactColor('Rust Line')!;

      final created = await repository.createPieces(
        mold: mold,
        quantity: 1,
        colors: <StudioColor>[color],
        price: 31.5,
        destination: PieceDestination.stock,
        commercialState: CommercialState.available,
      );

      final original = created.single;
      expect(
        original.id,
        matches(RegExp(r'^classiccup_bonewhite_[A-Z0-9]{4}$')),
      );

      final updatedWithoutIdentityChange = await repository.updatePiece(
        original.copyWith(price: 34, stage: PieceStage.toGlaze),
      );
      expect(updatedWithoutIdentityChange.id, original.id);
      expect(updatedWithoutIdentityChange.stage.id, 'bisque_fired');
      expect(updatedWithoutIdentityChange.stage.label, 'To glaze');

      final updatedWithIdentityChange = await repository.updatePiece(
        updatedWithoutIdentityChange.copyWith(
          mold: replacementMold,
          colors: <StudioColor>[replacementColor],
        ),
      );

      expect(updatedWithIdentityChange.id, isNot(original.id));
      expect(
        updatedWithIdentityChange.id,
        matches(RegExp(r'^ripplebowl_rustline_[A-Z0-9]{4}$')),
      );
      expect(
        repository.allPieces().where((piece) => piece.id == original.id),
        hasLength(1),
      );

      final grouped = await repository.createPieces(
        mold: mold,
        quantity: 2,
        colors: const <StudioColor>[],
        price: 31.5,
        destination: PieceDestination.stock,
        commercialState: CommercialState.available,
      );

      expect(grouped, hasLength(2));
      expect(grouped.first.creationGroupId, isNotNull);
      expect(grouped.first.creationGroupId, grouped.last.creationGroupId);
      expect(grouped.first.id, matches(RegExp(r'^classiccup_[A-Z0-9]{4}$')));
      expect(grouped.first.colors, isEmpty);
      expect(
        () => repository.createMold(name: 'Classic Cup'),
        throwsStateError,
      );
    },
  );

  testWidgets('design system uses Inter, new background, and card radius', (
    WidgetTester tester,
  ) async {
    expect(AppColors.appBackground, const Color(0xFFFAFAFA));
    expect(AppTypography.bodyFontFamily, 'Inter');
    expect(AppTypography.dateFontFamily, 'OCRB');
    expect(AppRadii.card, 6);
    expect(AppRadii.input, 4);
    expect(AppRadii.modal, 8);
  });

  testWidgets(
    'shell uses global header, compact bench state, and central create',
    (WidgetTester tester) async {
      final repository = DemoStudioRepository.seeded();
      _configureMobileViewport(tester);

      await _pumpVitrifyApp(tester, repository);

      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.byKey(const Key('global-search-input')), findsOneWidget);
      expect(find.text('To fire'), findsOneWidget);
      expect(find.text('To glaze'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.byKey(const Key('new-piece-button')), findsNothing);
      expect(find.text('Recent pieces'), findsNothing);
      expect(
        find.text(
          'Bench controls intake. New pieces start here, then move through production. Stock is only the ready count at the bottom.',
        ),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('nav-create')));
      await tester.pump();

      expect(find.byKey(const Key('new-piece-button')), findsOneWidget);
      expect(find.byKey(const Key('new-person-button')), findsOneWidget);
      expect(find.byKey(const Key('new-firing-batch-button')), findsOneWidget);
      expect(find.byKey(const Key('new-mold-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('new-mold-button')));
      await tester.pumpAndSettle();

      expect(find.text('New mold'), findsOneWidget);
      expect(find.text('New mold name'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('mold-name-input')),
        'Classic Cup',
      );
      await tester.pump();
      expect(find.text('Mold name already exists'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('mold-name-input')),
        'Tall Vase',
      );
      await tester.enterText(
        find.byKey(const Key('mold-description-input')),
        'Tall thrown form',
      );
      await tester.tap(find.byKey(const Key('mold-size-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('small').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pick-mold-image-button')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('mold-price-input')), '55');
      await tester.tap(find.byKey(const Key('save-mold-button')));
      await tester.pumpAndSettle();

      expect(find.text('Confirm mold'), findsOneWidget);
      expect(repository.findExactMold('Tall Vase'), isNull);

      await tester.tap(find.byKey(const Key('edit-mold-summary-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mold-description-input')), findsOneWidget);

      await tester.tap(find.byKey(const Key('save-mold-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-mold-button')));
      await tester.pumpAndSettle();

      final mold = repository.findExactMold('Tall Vase');
      expect(mold?.defaultPrice, 55);
      expect(mold?.description, 'Tall thrown form');
      expect(mold?.size, MoldSize.small);
      expect(mold?.imageReference, isNull);
      expect(mold?.id, matches(RegExp(r'^mold_[0-9]+_[A-Z0-9]{4}$')));
    },
  );

  testWidgets('first use captures a local user before the bench', (
    WidgetTester tester,
  ) async {
    final repository = DemoStudioRepository.seeded();
    _configureMobileViewport(tester);

    await tester.pumpWidget(
      VitrifyApp(repository: repository, persistUser: false),
    );
    await tester.pump();

    expect(find.text('What is your name?'), findsOneWidget);
    expect(find.byKey(const Key('global-search-input')), findsNothing);

    await tester.enterText(find.byKey(const Key('user-name-input')), 'Mira');
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-user-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('global-search-input')), findsOneWidget);
    expect(find.text('Bench'), findsWidgets);
  });

  testWidgets('bench KPI opens all pieces with matching stage filter', (
    WidgetTester tester,
  ) async {
    final repository = DemoStudioRepository.seeded();
    final bisquePiece = repository.allPieces().firstWhere(
      (piece) => piece.stage == PieceStage.toGlaze,
    );
    final readyPiece = repository.allPieces().firstWhere(
      (piece) => piece.stage == PieceStage.ready,
    );
    _configureMobileViewport(tester);

    await _pumpVitrifyApp(tester, repository);
    await tester.tap(find.text('To glaze'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stage-filter-To glaze')), findsOneWidget);
    expect(find.byKey(Key('piece-row-${bisquePiece.id}')), findsOneWidget);
    expect(find.byKey(Key('piece-row-${readyPiece.id}')), findsNothing);
  });

  testWidgets('plus create flow stays direct and collapses selected order', (
    WidgetTester tester,
  ) async {
    final repository = DemoStudioRepository.seeded();
    _configureMobileViewport(tester);

    await _pumpVitrifyApp(tester, repository);

    await tester.tap(find.byKey(const Key('nav-create')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('new-piece-button')));
    await tester.pumpAndSettle();

    expect(find.text('Classic Cup'), findsNothing);
    expect(find.byKey(const Key('create-inline-mold')), findsNothing);
    expect(find.byKey(const Key('add-color-button')), findsNothing);
    expect(find.text('Creation result'), findsNothing);
    expect(find.text('Available'), findsNothing);
    expect(find.text('Reserved'), findsNothing);
    expect(find.text('Sold / delivered'), findsNothing);

    final quantityField = tester.widget<TextField>(
      find.byKey(const Key('quantity-input')),
    );
    expect(quantityField.controller?.text, '1');

    await tester.enterText(find.byKey(const Key('mold-input')), 'Cup');
    await tester.pump();
    expect(
      find.byKey(const Key('mold-suggestion-Classic Cup')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('mold-suggestion-Classic Cup')));
    await tester.pump();
    expect(find.byKey(const Key('mold-suggestion-Classic Cup')), findsNothing);

    final priceField = tester.widget<TextField>(
      find.byKey(const Key('price-input')),
    );
    expect(priceField.controller?.text, '28');

    await tester.enterText(find.byKey(const Key('quantity-input')), '2');
    await tester.enterText(find.byKey(const Key('color-input')), 'Bone');
    await tester.pump();
    expect(
      find.byKey(const Key('color-suggestion-Bone White')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('color-suggestion-Bone White')));
    await tester.pump();
    expect(find.byKey(const Key('color-suggestion-Bone White')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('color-input')),
      'Sunset Copper',
    );
    await tester.pump();
    expect(find.byKey(const Key('create-inline-color')), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-inline-color')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('destination-Order')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('linked-record-input')),
      'Order 001',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('link-suggestion-Order 001 - Martin')),
    );
    await tester.pump();

    expect(find.byKey(const Key('linked-record-input')), findsNothing);
    expect(
      find.byKey(const Key('selected-linked-record-summary')),
      findsOneWidget,
    );

    tester.testTextInput.hide();
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('save-piece-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-piece-button')));
    await tester.pumpAndSettle();

    final created = repository.recentPieces(limit: 2);
    expect(created, hasLength(2));
    expect(repository.countPiecesByStage(PieceStage.toFire), 4);
    expect(
      created.first.id,
      matches(RegExp(r'^classiccup_bonewhite_sunsetcopper_[A-Z0-9]{4}$')),
    );
    expect(created.first.stage.label, 'To fire');
    expect(created.first.linkedRecord?.label, 'Order 001 - Martin');
  });

  testWidgets('order destination can be created without a linked order', (
    WidgetTester tester,
  ) async {
    final repository = DemoStudioRepository.seeded();
    _configureMobileViewport(tester);

    await _pumpVitrifyApp(tester, repository);

    await tester.tap(find.byKey(const Key('nav-create')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('new-piece-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('mold-input')), 'Classic Cup');
    await tester.pump();
    await tester.tap(find.byKey(const Key('mold-suggestion-Classic Cup')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('destination-Order')));
    await tester.pump();

    tester.testTextInput.hide();
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('save-piece-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-piece-button')));
    await tester.pumpAndSettle();

    expect(find.text('No order selected'), findsOneWidget);
    expect(find.text('This piece is not linked to any order.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-orderless-piece-button')));
    await tester.pumpAndSettle();

    final created = repository.recentPieces(limit: 1).single;
    expect(created.destination, PieceDestination.order);
    expect(created.linkedRecord, isNull);
    expect(created.createdByUserId, _testUser.id);
  });

  testWidgets('new piece can be created with no color', (
    WidgetTester tester,
  ) async {
    final repository = DemoStudioRepository.seeded();
    _configureMobileViewport(tester);

    await _pumpVitrifyApp(tester, repository);

    await tester.tap(find.byKey(const Key('nav-create')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('new-piece-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('no-color-option')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('mold-input')), 'Classic Cup');
    await tester.pump();
    await tester.tap(find.byKey(const Key('mold-suggestion-Classic Cup')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('no-color-option')));
    await tester.pump();

    tester.testTextInput.hide();
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('save-piece-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-piece-button')));
    await tester.pumpAndSettle();

    final created = repository.recentPieces(limit: 1).single;
    expect(created.colors, isEmpty);
    expect(created.id, matches(RegExp(r'^classiccup_[A-Z0-9]{4}$')));

    await tester.tap(find.byKey(const Key('nav-all-pieces')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('global-search-input')),
      created.id,
    );
    await tester.pump();

    expect(find.textContaining('No color'), findsWidgets);
  });

  testWidgets('user page shows user history including failed pieces', (
    WidgetTester tester,
  ) async {
    final repository = DemoStudioRepository.seeded();
    final mold = repository.findExactMold('Classic Cup')!;
    final created = await repository.createPieces(
      mold: mold,
      quantity: 1,
      colors: const <StudioColor>[],
      price: 28,
      destination: PieceDestination.stock,
      commercialState: CommercialState.available,
      createdBy: _testUser,
    );
    final failed = await repository.updatePiece(
      created.single.copyWith(
        failureRecord: FailureRecord(
          reason: 'Cracked',
          recordedAt: DateTime.now(),
        ),
      ),
    );
    _configureMobileViewport(tester);

    await _pumpVitrifyApp(tester, repository);
    await tester.tap(find.byKey(const Key('header-user-button')));
    await tester.pumpAndSettle();

    expect(find.text(_testUser.name), findsOneWidget);
    expect(find.byKey(Key('user-history-${failed.id}')), findsOneWidget);
    expect(find.text('To fire - Stock - Failed'), findsOneWidget);
  });

  testWidgets(
    'all pieces groups same-batch matching pieces and expands inline',
    (WidgetTester tester) async {
      final repository = DemoStudioRepository.seeded();
      final mold = repository.findExactMold('Classic Cup')!;
      final color = repository.findExactColor('Bone White')!;
      final grouped = await repository.createPieces(
        mold: mold,
        quantity: 3,
        colors: <StudioColor>[color],
        price: 31.5,
        destination: PieceDestination.stock,
        commercialState: CommercialState.available,
      );
      _configureMobileViewport(tester);

      await _pumpVitrifyApp(tester, repository);
      await tester.tap(find.byKey(const Key('nav-all-pieces')));
      await tester.pumpAndSettle();

      expect(find.text('Classic Cup — Bone White (×3)'), findsOneWidget);
      expect(find.byKey(Key('piece-row-${grouped.first.id}')), findsNothing);

      await tester.tap(find.text('Classic Cup — Bone White (×3)'));
      await tester.pumpAndSettle();

      for (final piece in grouped) {
        expect(find.byKey(Key('piece-row-${piece.id}')), findsOneWidget);
      }
    },
  );

  testWidgets(
    'all pieces uses header search, horizontal filters, and flat detail rows',
    (WidgetTester tester) async {
      final repository = DemoStudioRepository.seeded();
      final target = repository.allPieces().firstWhere(
        (piece) => piece.stage == PieceStage.ready,
      );
      _configureMobileViewport(tester);

      await _pumpVitrifyApp(tester, repository);
      await tester.tap(find.byKey(const Key('nav-all-pieces')));
      await tester.pumpAndSettle();

      expect(find.text('ALL PIECES'), findsNothing);
      expect(find.byKey(const Key('all-pieces-search')), findsNothing);
      expect(find.byKey(const Key('mold-filter-input')), findsNothing);
      expect(find.byKey(const Key('color-filter-input')), findsNothing);
      expect(find.byKey(const Key('failed-only-filter')), findsOneWidget);
      expect(find.text('Open'), findsNothing);
      expect(find.text(target.id), findsNothing);
      expect(find.byKey(const Key('filter-all')), findsOneWidget);
      expect(find.byKey(const Key('stage-filter-To fire')), findsOneWidget);
      expect(find.byKey(const Key('stage-filter-To glaze')), findsOneWidget);
      expect(find.byKey(const Key('stage-filter-Ready')), findsOneWidget);
      expect(
        find.byKey(const Key('destination-filter-Client')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('destination-filter-Student')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('destination-filter-Stock')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('global-search-input')),
        target.id,
      );
      await tester.pump();

      expect(find.byKey(Key('piece-row-${target.id}')), findsOneWidget);
      expect(find.textContaining(target.mold.name), findsWidgets);

      await tester.tap(find.byKey(const Key('stage-filter-To fire')));
      await tester.pump();
      expect(find.byKey(Key('piece-row-${target.id}')), findsNothing);

      await tester.tap(find.byKey(const Key('filter-all')));
      await tester.pump();
      expect(find.byKey(Key('piece-row-${target.id}')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('global-search-input')),
        'not a real porcelain piece',
      );
      await tester.pump();
      expect(find.text('No pieces found'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('global-search-input')),
        target.id,
      );
      await tester.pump();

      await tester.tap(find.byKey(Key('piece-row-${target.id}')));
      await tester.pumpAndSettle();

      expect(find.text('EDIT PIECE'), findsNothing);
      expect(find.byKey(const Key('piece-see-more-button')), findsOneWidget);
      expect(find.text(target.id), findsNothing);

      await tester.tap(find.byKey(const Key('piece-see-more-button')));
      await tester.pumpAndSettle();

      expect(find.text('Piece ID'), findsOneWidget);
      expect(find.text(target.id), findsOneWidget);
      expect(find.byKey(Key('piece-detail-edit-${target.id}')), findsOneWidget);

      await tester.tap(find.byKey(Key('piece-detail-edit-${target.id}')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit-mold')), findsOneWidget);
    },
  );

  testWidgets(
    'edit piece is display-first and identity changes save as new piece',
    (WidgetTester tester) async {
      final repository = DemoStudioRepository.seeded();
      final piece = repository.allPieces().firstWhere(
        (item) => item.mold.name == 'Classic Cup',
      );
      _configureMobileViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          builder: (context, child) {
            return Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (context) {
                    return SelectionArea(
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                ),
              ],
            );
          },
          home: PieceEditorScreen.edit(repository: repository, piece: piece),
        ),
      );

      expect(find.byKey(const Key('global-search-input')), findsOneWidget);
      expect(find.text(piece.id), findsOneWidget);
      expect(find.byKey(const Key('quantity-input')), findsNothing);
      expect(find.byKey(const Key('color-input')), findsNothing);

      await tester.tap(find.byKey(const Key('edit-color')));
      await tester.pump();
      expect(find.byKey(const Key('color-input')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('color-input')), 'Rust');
      await tester.pump();
      await tester.tap(find.byKey(const Key('color-suggestion-Rust Line')));
      await tester.pump();

      expect(find.text('Save as new piece'), findsOneWidget);

      await tester.tap(find.byKey(const Key('save-piece-button')));
      await tester.pumpAndSettle();

      expect(
        repository.allPieces().where((item) => item.id == piece.id),
        hasLength(1),
      );
      expect(
        repository.allPieces().where(
          (item) => item.id != piece.id && item.mold.id == piece.mold.id,
        ),
        isNotEmpty,
      );
    },
  );

  testWidgets('delete piece still confirms before removal', (
    WidgetTester tester,
  ) async {
    final repository = DemoStudioRepository.seeded();
    final piece = repository.allPieces().first;
    _configureMobileViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        builder: (context, child) {
          return Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) {
                  return SelectionArea(child: child ?? const SizedBox.shrink());
                },
              ),
            ],
          );
        },
        home: PieceEditorScreen.edit(repository: repository, piece: piece),
      ),
    );

    await tester.tap(find.byKey(const Key('delete-piece-button')));
    await tester.pumpAndSettle();

    expect(find.text('Delete piece'), findsOneWidget);
    expect(
      find.text('Delete ${piece.id}? This cannot be undone.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      repository.allPieces().where((item) => item.id == piece.id),
      hasLength(1),
    );
  });
}

Future<void> _pumpVitrifyApp(
  WidgetTester tester,
  DemoStudioRepository repository,
) async {
  await tester.pumpWidget(
    VitrifyApp(
      repository: repository,
      initialUser: _testUser,
      persistUser: false,
    ),
  );
  await tester.pump();
}

void _configureMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

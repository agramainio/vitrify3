import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitrify3/src/app.dart';
import 'package:vitrify3/src/design_system.dart';
import 'package:vitrify3/src/demo_studio_repository.dart';
import 'package:vitrify3/src/models.dart';
import 'package:vitrify3/src/piece_editor_screen.dart';

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
    },
  );

  testWidgets(
    'shell uses global header, compact bench state, and central create',
    (WidgetTester tester) async {
      final repository = DemoStudioRepository.seeded();
      _configureMobileViewport(tester);

      await tester.pumpWidget(VitrifyApp(repository: repository));

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
    },
  );

  testWidgets('plus create flow stays direct and collapses selected order', (
    WidgetTester tester,
  ) async {
    final repository = DemoStudioRepository.seeded();
    _configureMobileViewport(tester);

    await tester.pumpWidget(VitrifyApp(repository: repository));

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

  testWidgets(
    'all pieces uses header search, horizontal filters, and row edit',
    (WidgetTester tester) async {
      final repository = DemoStudioRepository.seeded();
      final target = repository.allPieces().firstWhere(
        (piece) => piece.stage == PieceStage.ready,
      );
      _configureMobileViewport(tester);

      await tester.pumpWidget(VitrifyApp(repository: repository));
      await tester.tap(find.byKey(const Key('nav-all-pieces')));
      await tester.pumpAndSettle();

      expect(find.text('ALL PIECES'), findsNothing);
      expect(find.byKey(const Key('all-pieces-search')), findsNothing);
      expect(find.text('Open'), findsNothing);
      expect(find.text(target.id), findsNothing);

      await tester.enterText(
        find.byKey(const Key('global-search-input')),
        target.id,
      );
      await tester.pump();

      expect(find.byKey(Key('piece-row-${target.id}')), findsOneWidget);
      expect(find.text(target.mold.name), findsOneWidget);

      await tester.tap(find.byKey(const Key('stage-filter-To fire')));
      await tester.pump();
      expect(find.byKey(Key('piece-row-${target.id}')), findsNothing);

      await tester.tap(find.byKey(const Key('stage-filter-all')));
      await tester.pump();
      expect(find.byKey(Key('piece-row-${target.id}')), findsOneWidget);

      await tester.tap(find.byKey(Key('piece-row-${target.id}')));
      await tester.pumpAndSettle();

      expect(find.text('EDIT PIECE'), findsNothing);
      expect(find.text(target.id), findsOneWidget);
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

      expect(
        find.text('Changing mold or colors creates a new piece ID.'),
        findsOneWidget,
      );
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

void _configureMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

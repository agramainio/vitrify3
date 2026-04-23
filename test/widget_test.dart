import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitrify3/src/app.dart';
import 'package:vitrify3/src/design_system.dart';
import 'package:vitrify3/src/demo_studio_repository.dart';
import 'package:vitrify3/src/models.dart';
import 'package:vitrify3/src/piece_editor_screen.dart';

void main() {
  test(
    'repository preserves history when identity changes and supports delete',
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
      expect(updatedWithoutIdentityChange.stage, PieceStage.toGlaze);

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
      expect(updatedWithIdentityChange.mold.name, 'Ripple Bowl');
      expect(updatedWithIdentityChange.colors.single.name, 'Rust Line');

      final pieces = repository.allPieces();
      expect(pieces.where((piece) => piece.id == original.id), hasLength(1));
      expect(
        pieces.where((piece) => piece.id == updatedWithIdentityChange.id),
        hasLength(1),
      );

      await repository.deletePiece(updatedWithIdentityChange.id);

      final afterDelete = repository.allPieces();
      expect(
        afterDelete.where((piece) => piece.id == updatedWithIdentityChange.id),
        isEmpty,
      );
      expect(
        afterDelete.where((piece) => piece.id == original.id),
        hasLength(1),
      );
    },
  );

  testWidgets('bench stays minimal and new piece flow is direct', (
    WidgetTester tester,
  ) async {
    final repository = DemoStudioRepository.seeded();
    _configureMobileViewport(tester);

    await tester.pumpWidget(VitrifyApp(repository: repository));

    expect(find.byType(SelectionArea), findsOneWidget);
    expect(
      find.text(
        'Bench controls intake. New pieces start here, then move through production. Stock is only the ready count at the bottom.',
      ),
      findsNothing,
    );
    expect(find.text('Recent pieces'), findsNothing);

    final benchLabel = tester.widget<Text>(find.text('BENCH'));
    expect(benchLabel.style?.fontFamily, AppTypography.bodyFontFamily);

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
    expect(find.text('Bone White'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('color-input')),
      'Sunset Copper',
    );
    await tester.pump();
    expect(find.byKey(const Key('create-inline-color')), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-inline-color')));
    await tester.pump();
    expect(find.text('Sunset Copper'), findsWidgets);

    await tester.tap(find.byKey(const Key('destination-Order')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('linked-record-input')),
      'Order 001',
    );
    await tester.pump();
    expect(
      find.byKey(const Key('link-suggestion-Order 001 - Martin')),
      findsOneWidget,
    );
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

    expect(repository.countPiecesByStage(PieceStage.toFire), 4);

    final created = repository.recentPieces(limit: 2);
    expect(created, hasLength(2));
    expect(created.first.mold.name, 'Classic Cup');
    expect(
      created.first.id,
      matches(RegExp(r'^classiccup_bonewhite_sunsetcopper_[A-Z0-9]{4}$')),
    );
    expect(
      created.first.colors.map((item) => item.name),
      containsAll(<String>['Bone White', 'Sunset Copper']),
    );
    expect(created.first.price, 28);
    expect(created.first.destination, PieceDestination.order);
    expect(created.first.linkedRecord?.label, 'Order 001 - Martin');
    expect(created.first.commercialState, CommercialState.reserved);
  });

  testWidgets(
    'all pieces page is the central access point for piece management',
    (WidgetTester tester) async {
      final repository = DemoStudioRepository.seeded();
      final target = repository.allPieces().firstWhere(
        (piece) => piece.stage == PieceStage.ready,
      );
      _configureMobileViewport(tester);

      await tester.pumpWidget(VitrifyApp(repository: repository));

      await tester.tap(find.byKey(const Key('nav-all-pieces')));
      await tester.pumpAndSettle();

      expect(find.text('ALL PIECES'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('all-pieces-search')),
        target.id,
      );
      await tester.pump();

      expect(find.byKey(Key('piece-row-${target.id}')), findsOneWidget);

      await tester.tap(find.byKey(Key('open-piece-${target.id}')));
      await tester.pumpAndSettle();
      expect(find.text('PIECE'), findsOneWidget);
      expect(find.text(target.id), findsWidgets);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('edit-piece-${target.id}')));
      await tester.pumpAndSettle();
      expect(find.text('EDIT PIECE'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('delete-piece-${target.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Delete piece'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        repository.allPieces().where((piece) => piece.id == target.id),
        isEmpty,
      );
    },
  );

  testWidgets('edit piece shows delete confirmation and identity change path', (
    WidgetTester tester,
  ) async {
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
                  return SelectionArea(child: child ?? const SizedBox.shrink());
                },
              ),
            ],
          );
        },
        home: PieceEditorScreen.edit(repository: repository, piece: piece),
      ),
    );

    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.byKey(const Key('delete-piece-button')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('color-input')), 'Rust');
    await tester.pump();
    expect(find.byKey(const Key('color-suggestion-Rust Line')), findsOneWidget);
    await tester.tap(find.byKey(const Key('color-suggestion-Rust Line')));
    await tester.pump();

    expect(
      find.text('Changing mold or colors creates a new piece ID.'),
      findsOneWidget,
    );
    expect(find.text('Save as new piece'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-piece-button')));
    await tester.pumpAndSettle();

    expect(find.text('Delete piece'), findsOneWidget);
    expect(
      find.text('Delete ${piece.id}? This cannot be undone.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete piece'), findsNothing);
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

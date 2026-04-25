import 'package:flutter/material.dart';

import 'design_system.dart';
import 'global_piece_search.dart';
import 'models.dart';
import 'piece_detail_screen.dart';
import 'piece_editor_screen.dart';
import 'studio_repository.dart';

class UserPage extends StatefulWidget {
  const UserPage({
    required this.repository,
    required this.currentUser,
    super.key,
  });

  final StudioRepository repository;
  final StudioUser currentUser;

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openPiece(Piece piece) async {
    _searchController.clear();
    setState(() {});
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => PieceDetailScreen(
          repository: widget.repository,
          piece: piece,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _openNewPiece() async {
    _searchController.clear();
    setState(() {});
    await Navigator.of(context).push<List<Piece>>(
      MaterialPageRoute(
        builder: (context) => PieceEditorScreen.create(
          repository: widget.repository,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              screenName: widget.currentUser.name,
              searchController: _searchController,
              onSearchChanged: (_) => setState(() {}),
              onBack: () => Navigator.of(context).maybePop(),
              onUserTap: () {},
            ),
            GlobalPieceSearchResults(
              repository: widget.repository,
              searchController: _searchController,
              onOpenPiece: _openPiece,
              onCreatePiece: _openNewPiece,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: const [
                  _UserPageSection(title: 'Profile'),
                  _UserPageSection(title: 'Settings'),
                  _UserPageSection(title: 'Configuration'),
                  _UserPageSection(title: 'Help'),
                  _UserPageSection(title: 'About'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserPageSection extends StatelessWidget {
  const _UserPageSection({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AppSection(
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.bodyLarge),
          ),
          Text('Coming soon', style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

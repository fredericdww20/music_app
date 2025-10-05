// lib/widgets/app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../player_service.dart';
import '../widgets/mini_player.dart';
import '../pages/album_list_page.dart';
import '../pages/artists_page.dart';

class AppScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final int selectedIndex;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.selectedIndex,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  // Évite les snackbars en rafale
  DateTime? _lastSnackAt;

  @override
  Widget build(BuildContext context) {
    final ps = context.watch<PlayerService>();

    // Écoute des événements “soft” du player (auto-reprise / recovery)
    return StreamBuilder<String>(
      stream: ps.eventsStream, // ajouté dans PlayerService (patch plus bas)
      builder: (context, snap) {
        final msg = snap.data;
        if (msg != null) {
          final now = DateTime.now();
          if (_lastSnackAt == null ||
              now.difference(_lastSnackAt!) > const Duration(seconds: 2)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                duration: const Duration(seconds: 2),
              ),
            );
            _lastSnackAt = now;
          }
        }

        // UI
        return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: Column(
            children: [
              // Mini-player visible uniquement si piste active
              if (ps.currentTrack != null && ps.isPlaying)
                const Material(
                  elevation: 2,
                  child: SizedBox(height: 56, child: MiniPlayer()),
                ),
              // Contenu de la page
              Expanded(child: widget.body),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: widget.selectedIndex,
            onTap: (index) {
              if (index == widget.selectedIndex) return;
              // Navigation par remplacement : 0 = Albums, 1 = Artistes
              if (index == 0) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AlbumListPage()),
                );
              } else if (index == 1) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ArtistsPage()),
                );
              }
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.album), label: "Albums"),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: "Artistes",
              ),
            ],
          ),
        );
      },
    );
  }
}

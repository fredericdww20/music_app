import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../player_service.dart';
import '../denon_cast.dart';
import '../api_service.dart';
import '../widgets/mini_player.dart';
import 'full_player_page.dart';

class TrackListPage extends StatelessWidget {
  final Album album;
  const TrackListPage({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(album.album),
        actions: [
          if (player.isCasting)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.redAccent),
              onPressed: () async {
                await player.disableCasting();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Cast arrêté")));
              },
            ),
          IconButton(
            icon: const Icon(Icons.cast, color: Colors.white),
            onPressed: () async {
              final devices = await player.discoverDevices();
              if (devices.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Aucun appareil trouvé")),
                );
                return;
              }
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Appareils disponibles"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: devices.map((d) {
                      return ListTile(
                        title: Text(d.friendlyName ?? d.modelName ?? "Inconnu"),
                        subtitle: Text(d.manufacturer ?? ""),
                        onTap: () async {
                          Navigator.pop(context);
                          await player.enableCasting(d);
                          // ⚡ dès qu’un appareil est choisi, lancer tout l’album
                          if (album.tracks.isNotEmpty) {
                            await player.playList(album.tracks, 0);
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Casting ${album.album} sur ${d.friendlyName ?? 'appareil'}",
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          album.cover != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    album.cover!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                )
              : const Icon(Icons.album, size: 120, color: Colors.white70),
          const SizedBox(height: 10),
          Text(
            album.album,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),

          // Boutons Jouer / Aléatoire (lecture locale si pas de cast actif)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ElevatedButton(
                    onPressed: () {
                      if (album.tracks.isNotEmpty) {
                        player.playList(album.tracks, 0);
                      }
                    },
                    child: const Text("Jouer"),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ElevatedButton(
                    onPressed: () {
                      if (album.tracks.isNotEmpty) {
                        final shuffled = List<Track>.from(album.tracks)
                          ..shuffle();
                        player.playList(shuffled, 0);
                      }
                    },
                    child: const Text("Aléatoire"),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Liste des pistes (⚡ sans icône Cast maintenant)
          Expanded(
            child: ListView.separated(
              itemCount: album.tracks.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: Colors.white12, height: 1),
              itemBuilder: (context, index) {
                final track = album.tracks[index];
                return ListTile(
                  title: Text(track.title),
                  onTap: () => player.playList(album.tracks, index),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

// -------- MINI LECTEUR --------

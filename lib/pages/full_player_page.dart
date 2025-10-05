import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import '../player_service.dart';

class FullPlayerPage extends StatelessWidget {
  const FullPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerService>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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

                          // ⚡ si une musique est en cours, continuer en cast
                          if (player.currentTrack != null) {
                            await player.playList([player.currentTrack!], 0);
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Casting sur ${d.friendlyName ?? 'appareil'}",
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
      body: Consumer<PlayerService>(
        builder: (context, player, child) {
          final track = player.currentTrack;
          if (track == null) {
            return const Center(
              child: Text(
                "Aucune musique en cours",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start, // ⚡ aligne en haut
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ---- Album ----
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                    child: SizedBox(
                      height: 24,
                      child: Marquee(
                        text: track.albumName,
                        style: const TextStyle(
                          fontSize: 22,
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                        blankSpace: 40.0,
                        velocity: 20.0,
                        pauseAfterRound: Duration(milliseconds: 800),
                        startPadding: 10.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ---- Pochette ----
                  track.albumCover != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            track.albumCover!,
                            width: 250,
                            height: 250,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(
                          Icons.album,
                          size: 200,
                          color: Colors.white70,
                        ),
                  const SizedBox(height: 20),

                  // ---- Titre chanson ----
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      track.title,
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---- Barre de progression + temps ----
                  StreamBuilder<Duration?>(
                    stream: player.isCasting
                        ? player.castDurationStream
                        : player.durationStream,
                    builder: (context, durationSnapshot) {
                      final duration = durationSnapshot.data ?? Duration.zero;

                      return StreamBuilder<Duration>(
                        stream: player.isCasting
                            ? player.castPositionStream
                            : player.positionStream,
                        builder: (context, positionSnapshot) {
                          final position =
                              positionSnapshot.data ?? Duration.zero;

                          return Column(
                            children: [
                              Slider(
                                min: 0,
                                max: duration.inSeconds.toDouble(),
                                value: position.inSeconds
                                    .clamp(0, duration.inSeconds)
                                    .toDouble(),
                                onChanged: (value) {
                                  player.seek(Duration(seconds: value.toInt()));
                                },
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(position),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(duration),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // ---- Badges Qualité / Débit ----
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (track.sampleRate != null)
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white24,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        "Qualité : ${track.sampleRate}",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  if (track.bitrate != null)
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white24,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        "Débit : ${track.bitrate}",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // ---- Contrôles ----
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 50,
                        icon: const Icon(
                          Icons.skip_previous,
                          color: Colors.white,
                        ),
                        onPressed: () => player.previous(),
                      ),
                      IconButton(
                        iconSize: 80,
                        icon: Icon(
                          player.isPlaying
                              ? Icons.pause_circle
                              : Icons.play_circle,
                          color: Colors.white,
                        ),
                        onPressed: () => player.togglePlayPause(),
                      ),
                      IconButton(
                        iconSize: 50,
                        icon: const Icon(Icons.skip_next, color: Colors.white),
                        onPressed: () => player.next(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// -------- FORMATAGE TEMPS --------
String _formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  return "$minutes:$seconds";
}

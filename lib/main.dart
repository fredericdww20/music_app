import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:marquee/marquee.dart';
import 'denon_cast.dart';

import 'api_service.dart';
import 'models.dart';
import 'player_service.dart';
import 'splash_screen.dart';

import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => PlayerService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFB388FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB388FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: const Color(0xFFB388FF),
          inactiveTrackColor: Colors.white24,
          thumbColor: const Color(0xFFB388FF),
        ),
      ),

      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(), // ⚡ logo animé
        '/albums': (context) => const AlbumListPage(),
      },
    );
  }
}

// -------- PAGE LISTE ALBUMS --------
class AlbumListPage extends StatefulWidget {
  const AlbumListPage({super.key});

  @override
  State<AlbumListPage> createState() => _AlbumListPageState();
}

class _AlbumListPageState extends State<AlbumListPage> {
  late Future<List<Album>> albums;
  final api = ApiService("https://www.musique.fportemer.fr");

  @override
  void initState() {
    super.initState();
    albums = api.fetchAlbums();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mes Albums")),
      body: FutureBuilder<List<Album>>(
        future: albums,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Erreur: ${snapshot.error}"));
          } else {
            final data = snapshot.data!;
            return GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 2 colonnes
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.75, // permet à l'image d'occuper la card
              ),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final album = data[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrackListPage(album: album),
                      ),
                    );
                  },
                  child: Card(
                    clipBehavior: Clip.antiAlias, // arrondis respectés
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Cover en FULL dans la card
                        Expanded(
                          child: album.cover != null
                              ? Image.network(album.cover!, fit: BoxFit.cover)
                              : const Icon(
                                  Icons.album,
                                  size: 100,
                                  color: Colors.white70,
                                ),
                        ),
                        // Nom de l’album centré
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            album.album,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

// -------- PAGE LISTE TITRES --------
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
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, player, child) {
        if (player.currentTrack == null) {
          return const SizedBox.shrink();
        }

        final track = player.currentTrack!;
        final displayTitle = "${track.albumName} - ${track.title}";

        return BottomAppBar(
          color: Colors.grey[900],
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FullPlayerPage()),
              );
            },
            child: ListTile(
              leading: const Icon(Icons.music_note, color: Colors.white),
              title: SizedBox(
                height: 20,
                child: Marquee(
                  text: displayTitle,
                  style: const TextStyle(color: Colors.white),
                  blankSpace: 40.0,
                  velocity: 30.0,
                  pauseAfterRound: Duration(seconds: 1),
                  startPadding: 10.0,
                ),
              ),
              trailing: IconButton(
                icon: Icon(
                  player.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Theme.of(context).primaryColor,
                ),
                onPressed: () => player.togglePlayPause(),
              ),
            ),
          ),
        );
      },
    );
  }
}

// -------- LECTEUR PLEIN ECRAN --------
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
                          fontSize: 18,
                          color: Colors.white70,
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
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---- Barre de progression + temps ----
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
                          color: Theme.of(context).primaryColor,
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

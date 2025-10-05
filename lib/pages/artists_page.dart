import 'package:flutter/material.dart';
import '../api_service.dart';
import '../models.dart';
import 'track_list_page.dart';

class ArtistsPage extends StatefulWidget {
  const ArtistsPage({super.key});

  @override
  State<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage> {
  late Future<List<Album>> _albums;
  final api = ApiService("https://www.musique.fportemer.fr");

  @override
  void initState() {
    super.initState();
    _albums = api.fetchAlbums();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Artistes")),
      body: FutureBuilder<List<Album>>(
        future: _albums,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("Erreur: ${snap.error}"));
          }
          final albums = snap.data ?? [];

          // Agrégation artistes
          final Map<String, _ArtistAgg> byArtist = {};
          for (final a in albums) {
            // Déduit l'artiste de la 1re piste ; fallback = nom d’album si vide
            final artist =
                (a.tracks.isNotEmpty ? a.tracks.first.artist : a.album).trim();
            final key = artist.isEmpty ? a.album : artist;

            final agg = byArtist.putIfAbsent(key, () => _ArtistAgg(name: key));
            agg.albumCount += 1;
            agg.trackCount += a.tracks.length;
            agg.albums.add(a);
            // Première cover rencontrée
            agg.cover ??= a.cover;
          }

          final artists = byArtist.values.toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

          if (artists.isEmpty) {
            return const Center(child: Text("Aucun artiste détecté."));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.75,
            ),
            itemCount: artists.length,
            itemBuilder: (context, i) {
              final art = artists[i];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ArtistAlbumsPage(artist: art),
                    ),
                  );
                },
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: art.cover != null
                            ? Image.network(art.cover!, fit: BoxFit.cover)
                            : const Icon(
                                Icons.person,
                                size: 100,
                                color: Colors.white70,
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Text(
                              art.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${art.albumCount} album(s) • ${art.trackCount} piste(s)",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ArtistAgg {
  _ArtistAgg({required this.name});
  final String name;
  String? cover;
  int albumCount = 0;
  int trackCount = 0;
  final List<Album> albums = [];
}

class ArtistAlbumsPage extends StatelessWidget {
  const ArtistAlbumsPage({super.key, required this.artist});
  final _ArtistAgg artist;

  @override
  Widget build(BuildContext context) {
    final albums = artist.albums;
    return Scaffold(
      appBar: AppBar(title: Text(artist.name)),
      body: GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.75,
        ),
        itemCount: albums.length,
        itemBuilder: (context, i) {
          final album = albums[i];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TrackListPage(album: album)),
              );
            },
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: album.cover != null
                        ? Image.network(album.cover!, fit: BoxFit.cover)
                        : const Icon(
                            Icons.album,
                            size: 100,
                            color: Colors.white70,
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      album.album,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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

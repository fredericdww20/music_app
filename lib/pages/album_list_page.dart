import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';
import '../player_service.dart';
import 'track_list_page.dart';

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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          setState(() {
            // TODO: changer l'index de la page
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.album), label: "Albums"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Artistes"),
        ],
      ),
    );
  }
}

// -------- PAGE LISTE TITRES --------

class Track {
  final String title;
  final String url;
  final String albumName;
  final String? albumCover;
  final String? sampleRate;
  final String? bitrate;

  Track({
    required this.title,
    required this.url,
    required this.albumName,
    this.albumCover,
    this.sampleRate,
    this.bitrate,
  });

  String get artist {
    try {
      final uri = Uri.parse(url);
      final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();

      // ['Artiste','Album','Fichier'] → nouvelle arbo
      if (segs.length >= 3) {
        return Uri.decodeComponent(segs[0]);
      }

      // ['Album','Fichier'] → ancienne arbo → on affiche le nom d’album
      if (segs.length >= 2) {
        return albumName;
      }
    } catch (_) {
      // Si parsing échoue, on retombe sur l’album
    }
    return albumName;
  }

  factory Track.fromJson(
    Map<String, dynamic> json,
    String albumName,
    String? albumCover,
  ) {
    return Track(
      title: json['title'],
      url: json['url'],
      albumName: albumName,
      albumCover: albumCover,
      sampleRate: json['sampleRate'],
      bitrate: json['bitrate'],
    );
  }
}

class Album {
  final String album;
  final String? cover;
  final List<Track> tracks;

  Album({required this.album, this.cover, required this.tracks});

  factory Album.fromJson(Map<String, dynamic> json) {
    final albumName = json['album'];
    final cover = json['cover'];
    final tracksJson = (json['tracks'] as List<dynamic>? ?? []);
    final tracks = tracksJson
        .map((t) => Track.fromJson(t as Map<String, dynamic>, albumName, cover))
        .toList();

    return Album(album: albumName, cover: cover, tracks: tracks);
  }
}

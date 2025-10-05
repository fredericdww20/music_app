import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/models.dart'; // adapte si ton package name est différent

void main() {
  test('Album.fromJson parse basique', () {
    final json = {
      'id': 'a1',
      'title': 'Demo',
      'artist': 'Band',
      'cover': 'https://exemple/cover.jpg',
      'tracks': [
        {'id': 't1', 'title': 'Song', 'url': 'https://exemple/song.mp3', 'duration': 123}
      ]
    };
    final album = Album.fromJson(json);
    expect(album.id, 'a1');
    expect(album.tracks.first.title, 'Song');
  });
}

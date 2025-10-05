import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  final String baseUrl;
  ApiService(this.baseUrl);

  Future<List<Album>> fetchAlbums() async {
    final uri = Uri.parse("$baseUrl/catalogue.php");
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data
          .map((a) => Album.fromJson(a as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception("Erreur serveur: ${res.statusCode}");
    }
  }
}

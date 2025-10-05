import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'models.dart';

/// Service HTTP minimaliste et robuste, compatible avec l’existant.
/// - Timeout par défaut (10s)
/// - Erreurs explicites
/// - Injection d'un http.Client (testabilité)
class ApiService {
  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  ApiService(this.baseUrl, {http.Client? client, Duration? timeout})
    : _client = client ?? http.Client(),
      timeout = timeout ?? const Duration(seconds: 10);

  /// GET /catalogue.php
  /// Retourne la liste des albums (avec pistes) telle que renvoyée par ton backend.
  Future<List<Album>> fetchAlbums() async {
    final uri = Uri.parse('$baseUrl/catalogue.php');

    late http.Response res;
    try {
      res = await _client.get(uri).timeout(timeout);
    } on TimeoutException {
      throw Exception('Délai dépassé lors de l’appel à $uri');
    } catch (e) {
      throw Exception('Erreur réseau lors de l’appel à $uri : $e');
    }

    if (res.statusCode != 200) {
      throw Exception(
        'Erreur serveur ${res.statusCode} : ${res.reasonPhrase ?? ''}',
      );
    }

    // Optionnel : vérification simple du Content-Type si ton backend l’envoie
    final contentType = res.headers['content-type'] ?? '';
    if (!contentType.contains('application/json')) {
      // On tente quand même de parser, mais on prévient si ce n’est pas du JSON annoncé
      // (tu peux rendre ceci strict si besoin)
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (e) {
      throw Exception('Réponse non valide (JSON invalide) : $e');
    }

    if (decoded is! List) {
      throw Exception('Format inattendu : la racine JSON doit être une liste');
    }

    try {
      return decoded
          .map<Album>((a) => Album.fromJson(a as Map<String, dynamic>))
          .toList(growable: false);
    } catch (e) {
      throw Exception('Erreur de parsing des albums : $e');
    }
  }

  /// À appeler quand tu n’utilises plus ce service (ex. tests)
  void dispose() {
    _client.close();
  }
}

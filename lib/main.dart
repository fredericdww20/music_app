import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/album_list_page.dart';
import 'player_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => PlayerService())],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,

        // ✅ Thème Material 3 moderne
        theme: AppTheme.light, // ou AppTheme.dark
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system, // bascule automatique clair/sombre
        // ✅ Page d’accueil (inchangée)
        home: const AlbumListPage(),
      ),
    );
  }
}

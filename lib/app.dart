import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/album_list_page.dart';
import 'splash_screen.dart';

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

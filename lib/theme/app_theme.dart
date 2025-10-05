import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Thèmes Material 3 optionnels et non-intrusifs.
class AppTheme {
  static const _seed = Color(0xFFB388FF);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      primary: const Color.fromARGB(255, 0, 0, 0),
      brightness: Brightness.light,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      primary: Colors.black,
      brightness: Brightness.dark,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ),
  );
}

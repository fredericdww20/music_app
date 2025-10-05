import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'player_service.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => PlayerService(),
      child: const MyApp(),
    ),
  );
}

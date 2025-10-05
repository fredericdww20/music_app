import 'package:flutter/material.dart';

/// Affiche une snackbar simple (remplace proprement l'actuelle si nécessaire).
void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

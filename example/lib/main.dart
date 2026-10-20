import 'package:flutter/material.dart';

import 'gallery_page.dart';

void main() => runApp(const HoloGalleryApp());

/// Demo app for the holo_card package.
class HoloGalleryApp extends StatelessWidget {
  /// Creates the app.
  const HoloGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Holo Card',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C5CFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0C14),
      ),
      home: const GalleryPage(),
    );
  }
}

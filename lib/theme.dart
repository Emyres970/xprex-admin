import 'package:flutter/material.dart';

final appTheme = ThemeData.dark().copyWith(
  primaryColor: Colors.amber,
  scaffoldBackgroundColor: const Color(0xFF000000), // Pure Black for contrast
  cardColor: const Color(0xFF1E1E1E), // Dark Grey for cards
  
  // FIX: Distinct Input Fields so they don't blend into the background
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF2C2C2C),
    hintStyle: const TextStyle(color: Colors.white38),
    labelStyle: const TextStyle(color: Colors.white70),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white10),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.amber, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
  ),

  // FIX: Consistent Text Styles
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
    bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
  ),
);

// main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_1/pages/splash_screen.dart';
// --- NEW IMPORT ---
import 'package:flutter_application_1/services/notification_service.dart';

void main() async { 
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // --- INITIALIZE NOTIFICATIONS HERE ---
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();

  runApp(const BionanaApp());
}

class BionanaApp extends StatelessWidget {
  const BionanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      primarySwatch: Colors.green,
      scaffoldBackgroundColor: Color(0xFFF7F9F8),
      textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20, 
          fontWeight: FontWeight.w600,
          color: Colors.black87
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.yellow[700],
          foregroundColor: Colors.black,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      cardTheme: CardThemeData( 
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        color: Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: Colors.green[800],
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        elevation: 2,
      )
    );

    return MaterialApp(
      title: 'BIONANA',
      debugShowCheckedModeBanner: false, 
      theme: theme, 
      home: SplashScreen(), 
    );
  }
}
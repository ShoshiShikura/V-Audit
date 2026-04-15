import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'db/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await _populatePresetWorkers(); // Preset worker population is now disabled but can be re-enabled if needed
  runApp(const VAuditApp());
}

class VAuditApp extends StatelessWidget {
  const VAuditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V-Audit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF4B1EFF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4B1EFF),
          primary: const Color(0xFF4B1EFF),
          secondary: const Color(0xFFFF6F61),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4B1EFF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          bodyMedium: TextStyle(
            color: Colors.black87,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF4B1EFF), width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          prefixIconColor: Colors.grey,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

/// TEMPORARY: Migration home screen to fix user encryption
class MigrationHome extends StatelessWidget {
  const MigrationHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Run User Decryption Migration')),
      body: Center(
        child: ElevatedButton(
          child: const Text('Fix All Users (Decryption Migration)'),
          onPressed: () async {
            await DatabaseHelper().fixAllUsersDecryption();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User migration complete!')),
              );
            }
          },
        ),
      ),
    );
  }
}

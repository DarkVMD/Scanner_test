import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

const _background = Color(0xFF0B1220);
const _surface = Color(0xFF151F30);
const _primary = Color(0xFF70B7FF);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShelfLifeApp());
}

class ShelfLifeApp extends StatelessWidget {
  const ShelfLifeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Vscan',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _background,
      colorScheme: const ColorScheme.dark(
        primary: _primary,
        secondary: Color(0xFF70D6B0),
        surface: _surface,
        onSurface: Color(0xFFEAF0F8),
        error: Color(0xFFFF7777),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _background,
        foregroundColor: Color(0xFFEAF0F8),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(color: _surface, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFF26364B)))),
      dialogTheme: DialogThemeData(backgroundColor: _surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF101A29),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF30435C))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF30435C))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _primary, width: 1.5)),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    ),
    home: const HomeScreen(),
  );
}

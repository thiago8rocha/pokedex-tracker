import 'package:flutter/material.dart';

// ─── DEFINIÇÃO DOS TEMAS DISPONÍVEIS ─────────────────────────────

class AppThemeDefinition {
  final String id;
  final String label;
  // Cores de preview: primária, secundária, terciária
  final Color seedLight;
  final Color seedDark;
  // Cores para o preview visual (3 swatches)
  final List<Color> previewColors;

  const AppThemeDefinition({
    required this.id,
    required this.label,
    required this.seedLight,
    required this.seedDark,
    required this.previewColors,
  });
}

class AppThemes {
  static const all = [
    AppThemeDefinition(
      id: 'system',
      label: 'Sistema',
      // Seed nula — usa o padrão Material 3 (azul/teal neutro)
      seedLight: Color(0xFF6750A4), // roxo padrão Material 3
      seedDark:  Color(0xFF6750A4),
      previewColors: [Color(0xFF6750A4), Color(0xFF9C89B8), Color(0xFFEADDFF)],
    ),
    AppThemeDefinition(
      id: 'pokeball',
      label: 'Pokébola',
      seedLight: Color(0xFFE53935),
      seedDark:  Color(0xFFB71C1C),
      previewColors: [Color(0xFFE53935), Color(0xFF212121), Color(0xFFFFFFFF)],
    ),
    AppThemeDefinition(
      id: 'ocean',
      label: 'Oceano',
      seedLight: Color(0xFF1565C0),
      seedDark:  Color(0xFF0D47A1),
      previewColors: [Color(0xFF1565C0), Color(0xFF42A5F5), Color(0xFFE3F2FD)],
    ),
    AppThemeDefinition(
      id: 'forest',
      label: 'Floresta',
      seedLight: Color(0xFF2E7D32),
      seedDark:  Color(0xFF1B5E20),
      previewColors: [Color(0xFF2E7D32), Color(0xFF81C784), Color(0xFFE8F5E9)],
    ),
    AppThemeDefinition(
      id: 'psychic',
      label: 'Psíquico',
      seedLight: Color(0xFF7B1FA2),
      seedDark:  Color(0xFF4A148C),
      previewColors: [Color(0xFF7B1FA2), Color(0xFFCE93D8), Color(0xFFF3E5F5)],
    ),
    AppThemeDefinition(
      id: 'fire',
      label: 'Fogo',
      seedLight: Color(0xFFE65100),
      seedDark:  Color(0xFFBF360C),
      previewColors: [Color(0xFFE65100), Color(0xFFFFCC02), Color(0xFFFFE0B2)],
    ),
    AppThemeDefinition(
      id: 'electric',
      label: 'Elétrico',
      seedLight: Color(0xFFF9A825),
      seedDark:  Color(0xFFF57F17),
      previewColors: [Color(0xFFF9A825), Color(0xFFFFF176), Color(0xFF212121)],
    ),
    AppThemeDefinition(
      id: 'ice',
      label: 'Gelo',
      seedLight: Color(0xFF0097A7),
      seedDark:  Color(0xFF006064),
      previewColors: [Color(0xFF0097A7), Color(0xFF80DEEA), Color(0xFFE0F7FA)],
    ),
  ];

  static AppThemeDefinition byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);

  static ThemeData light(String themeId) {
    final appBarTheme = const AppBarTheme(
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
    );
    if (themeId == 'system') {
      // Sem seed fixa — Material 3 usa o esquema padrão roxo/violeta
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        appBarTheme: appBarTheme,
      );
    }
    final def = byId(themeId);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: def.seedLight,
      appBarTheme: appBarTheme,
    );
  }

  static ThemeData dark(String themeId) {
    final appBarTheme = const AppBarTheme(
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
    );
    if (themeId == 'system') {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        appBarTheme: appBarTheme,
      );
    }
    final def = byId(themeId);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: def.seedDark,
      appBarTheme: appBarTheme,
    );
  }
}

// ─── APP THEME CONTROLLER ─────────────────────────────────────────
// ValueNotifier global — o main.dart escuta e reconstrói o MaterialApp.

class AppThemeController extends ChangeNotifier {
  String _themeId = 'system';
  ThemeMode _themeMode = ThemeMode.system;

  String get themeId => _themeId;
  ThemeMode get themeMode => _themeMode;

  void setTheme(String id, ThemeMode mode) {
    _themeId = id;
    _themeMode = mode;
    notifyListeners();
  }
}

// Instância global — acessada pelo main.dart e pelo settings
final appThemeController = AppThemeController();
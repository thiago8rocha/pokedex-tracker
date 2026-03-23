import 'package:flutter/material.dart';

/// Ícone de energia no estilo oficial do Pokémon TCG Pocket.
/// Assets em assets/pocket/energy/{type}.png
class PocketEnergyIcon extends StatelessWidget {
  final String type;
  final double size;

  const PocketEnergyIcon({super.key, required this.type, this.size = 24});

  // TCG Pocket tem 10 tipos de energia:
  // Grass, Fire, Water, Lightning, Psychic, Fighting, Darkness, Metal, Colorless, Dragon
  // (Fairy não existe no TCG Pocket)
  static const Map<String, String> _assetName = {
    'Grass':      'Grass',
    'Fire':       'Fire',
    'Water':      'Water',
    'Lightning':  'Lightning',
    'Psychic':    'Psychic',
    'Fighting':   'Fighting',
    'Darkness':   'Darkness',
    'Metal':      'Metal',
    'Colorless':  'Colorless',
    'Dragon':     'Dragon',
    // Aliases de outros contextos → equivalente no Pocket
    'Electric':   'Lightning',
    'Dark':       'Darkness',
    'Steel':      'Metal',
    'Normal':     'Colorless',
    'Fairy':      'Colorless', // Fairy não existe no Pocket → Colorless
  };

  static const Map<String, Color> _fallbackColors = {
    'Grass':      Color(0xFF3D8B3D),
    'Fire':       Color(0xFFCC2200),
    'Water':      Color(0xFF0A78C8),
    'Lightning':  Color(0xFFDDAA00),
    'Psychic':    Color(0xFF6A1FAB),
    'Fighting':   Color(0xFFAA3300),
    'Darkness':   Color(0xFF18324F),
    'Metal':      Color(0xFF808080),
    'Colorless':  Color(0xFFCCCCCC),
    'Dragon':     Color(0xFF8B7520),
  };

  @override
  Widget build(BuildContext context) {
    final asset = _assetName[type] ?? 'Colorless';
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/pocket/energy/$asset.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          final color = _fallbackColors[type] ?? const Color(0xFFAAAAAA);
          return Container(
            width: size, height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(child: Text(
              type.isNotEmpty ? type[0] : '?',
              style: TextStyle(color: Colors.white,
                  fontSize: size * 0.45, fontWeight: FontWeight.w800),
            )),
          );
        },
      ),
    );
  }
}

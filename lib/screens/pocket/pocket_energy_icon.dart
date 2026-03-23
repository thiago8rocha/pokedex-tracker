import 'package:flutter/material.dart';

/// Ícone de energia no estilo oficial do Pokémon TCG Pocket.
///
/// Usa assets/pocket/energy/{Type}.png (adicionar ao pubspec se ainda não feito).
/// Fallback automático para assets/types/{type}.png (já no pubspec).
class PocketEnergyIcon extends StatelessWidget {
  final String type;
  final double size;

  const PocketEnergyIcon({super.key, required this.type, this.size = 24});

  // Mapeamento TCG Pocket → arquivo em assets/pocket/energy/
  static const Map<String, String> _pocketAsset = {
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
    'Electric':   'Lightning',
    'Dark':       'Darkness',
    'Steel':      'Metal',
    'Normal':     'Colorless',
    'Fairy':      'Colorless',
  };

  // Fallback: mapeamento TCG → assets/types/ (já declarado no pubspec)
  static const Map<String, String> _typesAsset = {
    'Grass':      'grass',
    'Fire':       'fire',
    'Water':      'water',
    'Lightning':  'electric',
    'Electric':   'electric',
    'Psychic':    'psychic',
    'Fighting':   'fighting',
    'Darkness':   'dark',
    'Dark':       'dark',
    'Metal':      'steel',
    'Steel':      'steel',
    'Colorless':  'normal',
    'Normal':     'normal',
    'Dragon':     'dragon',
    'Fairy':      'fairy',
  };

  @override
  Widget build(BuildContext context) {
    final pocket = _pocketAsset[type] ?? 'Colorless';
    final fallback = _typesAsset[type] ?? 'normal';

    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/pocket/energy/$pocket.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        // Se assets/pocket/energy/ não estiver no pubspec, usa assets/types/
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/types/$fallback.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

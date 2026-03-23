import 'package:flutter/material.dart';

// ─── RARIDADES TCG POCKET ─────────────────────────────────────────
//
// O sistema de raridade do Pocket usa diamantes, estrelas e coroa:
//   1 Diamante  (Common)
//   2 Diamantes (Uncommon)
//   3 Diamantes (Rare)
//   4 Diamantes (Double Rare)
//   1 Estrela   (Art Rare)
//   2 Estrelas  (Super Rare)
//   3 Estrelas  (Immersive Rare)
//   Coroa       (Crown Rare — máxima raridade)
//
// Shiny variants:
//   1 Shiny     (Shiny Rare)
//   2 Shiny     (Shiny Super Rare)

class PocketRarityBadge extends StatelessWidget {
  final String rarity;

  /// compact: usado na listagem (menor, sem label)
  /// expanded: usado no detalhe (maior, com label)
  final bool expanded;

  const PocketRarityBadge({
    super.key,
    required this.rarity,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icons  = _buildIcons(rarity, scheme);

    if (icons.isEmpty) {
      // Raridade desconhecida: exibir texto simples
      return Text(
        rarity,
        style: TextStyle(
          fontSize: expanded ? 11 : 9,
          color: scheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: icons,
    );
  }

  List<Widget> _buildIcons(String rarity, ColorScheme scheme) {
    final r = rarity.trim().toLowerCase();

    // Diamantes
    if (r == 'one diamond')   return _diamonds(1, scheme);
    if (r == 'two diamond')   return _diamonds(2, scheme);
    if (r == 'three diamond') return _diamonds(3, scheme);
    if (r == 'four diamond')  return _diamonds(4, scheme);

    // Estrelas
    if (r == 'one star')   return _stars(1, scheme);
    if (r == 'two star')   return _stars(2, scheme);
    if (r == 'three star') return _stars(3, scheme);

    // Coroa
    if (r == 'crown') return [_crownIcon(scheme)];

    // Shiny
    if (r == 'one shiny')   return _shinies(1, scheme);
    if (r == 'two shiny')   return _shinies(2, scheme);

    return [];
  }

  double get _iconSize => expanded ? 14.0 : 9.0;

  List<Widget> _diamonds(int count, ColorScheme scheme) {
    // Cor: progride de cinza (common) para azul (double rare)
    final colors = [
      Colors.grey.shade400,
      Colors.grey.shade500,
      Colors.blue.shade300,
      Colors.blue.shade500,
    ];
    final color = colors[(count - 1).clamp(0, colors.length - 1)];
    return List.generate(
      count,
      (_) => Padding(
        padding: EdgeInsets.only(right: expanded ? 2 : 1),
        child: Icon(Icons.diamond, size: _iconSize, color: color),
      ),
    );
  }

  List<Widget> _stars(int count, ColorScheme scheme) {
    // Estrelas: dourado → dourado brilhante → holográfico (simulado em amarelo-âmbar)
    final colors = [
      Colors.amber.shade400,
      Colors.amber.shade600,
      Colors.orange.shade400,
    ];
    final color = colors[(count - 1).clamp(0, colors.length - 1)];
    return List.generate(
      count,
      (_) => Padding(
        padding: EdgeInsets.only(right: expanded ? 2 : 1),
        child: Icon(Icons.star_rounded, size: _iconSize + 2, color: color),
      ),
    );
  }

  Widget _crownIcon(ColorScheme scheme) {
    return Icon(
      Icons.workspace_premium_rounded,
      size: _iconSize + 3,
      color: Colors.amber.shade300,
    );
  }

  List<Widget> _shinies(int count, ColorScheme scheme) {
    return List.generate(
      count,
      (_) => Padding(
        padding: EdgeInsets.only(right: expanded ? 2 : 1),
        child: Icon(Icons.auto_awesome, size: _iconSize, color: Colors.cyan.shade300),
      ),
    );
  }
}

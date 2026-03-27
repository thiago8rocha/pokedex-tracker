import 'dart:math' show pi;
import 'package:flutter/material.dart';

// ─── RARIDADES TCG POCKET ─────────────────────────────────────────
//
// 1 Losango  (Common)        2 Losangos  (Uncommon)
// 3 Losangos (Rare)          4 Losangos  (Double Rare)
// 1 Estrela  (Art Rare)      2 Estrelas  (Super Rare)
// 3 Estrelas (Immersive Rare)
// Coroa      (Crown Rare)
// 1 Shiny    (Shiny Rare)    2 Shiny     (Shiny Super Rare)

class PocketRarityBadge extends StatelessWidget {
  final String rarity;
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
      return Text(rarity,
        style: TextStyle(fontSize: expanded ? 11 : 9,
            color: scheme.onSurfaceVariant),
        maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return Row(mainAxisSize: MainAxisSize.min, children: icons);
  }

  List<Widget> _buildIcons(String rarity, ColorScheme scheme) {
    final r = rarity.trim().toLowerCase();

    if (r == 'one diamond')   return _diamonds(1);
    if (r == 'two diamond')   return _diamonds(2);
    if (r == 'three diamond') return _diamonds(3);
    if (r == 'four diamond')  return _diamonds(4);

    if (r == 'one star')   return _stars(1);
    if (r == 'two star')   return _stars(2);
    if (r == 'three star') return _stars(3);

    if (r == 'crown') return [_crown()];

    if (r == 'one shiny')   return _shinies(1);
    if (r == 'two shiny')   return _shinies(2);

    return [];
  }

  double get _sz => expanded ? 14.0 : 9.0;

  // Losango: crop_square rotacionado 45° — mesmo visual do ◆ do Windows
  Widget _diamond(Color color) => Padding(
    padding: EdgeInsets.symmetric(horizontal: expanded ? 1.5 : 1),
    child: Transform.rotate(
      angle: pi / 4,
      child: Icon(Icons.crop_square, size: _sz, color: color),
    ),
  );

  List<Widget> _diamonds(int count) {
    const colors = [
      Color(0xFF9E9E9E), // 1 — cinza (Common)
      Color(0xFF78909C), // 2 — azul-cinza (Uncommon)
      Color(0xFF42A5F5), // 3 — azul (Rare)
      Color(0xFF1565C0), // 4 — azul escuro (Double Rare)
    ];
    final color = colors[(count - 1).clamp(0, 3)];
    return List.generate(count, (_) => _diamond(color));
  }

  List<Widget> _stars(int count) {
    const colors = [
      Color(0xFFFFCA28), // 1 — dourado (Art Rare)
      Color(0xFFFFB300), // 2 — dourado intenso (Super Rare)
      Color(0xFFFF8F00), // 3 — âmbar (Immersive Rare)
    ];
    final color = colors[(count - 1).clamp(0, 2)];
    return List.generate(count, (_) => Padding(
      padding: EdgeInsets.symmetric(horizontal: expanded ? 1.5 : 1),
      child: Icon(Icons.star_rounded, size: _sz + 2, color: color),
    ));
  }

  Widget _crown() => Padding(
    padding: EdgeInsets.symmetric(horizontal: expanded ? 1.5 : 1),
    child: Icon(Icons.workspace_premium_rounded,
        size: _sz + 4, color: const Color(0xFFFFD54F)),
  );

  List<Widget> _shinies(int count) => List.generate(count, (_) => Padding(
    padding: EdgeInsets.symmetric(horizontal: expanded ? 1.5 : 1),
    child: Icon(Icons.auto_awesome, size: _sz + 1, color: const Color(0xFF4DD0E1)),
  ));
}

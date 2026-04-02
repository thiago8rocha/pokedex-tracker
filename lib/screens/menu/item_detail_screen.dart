import 'package:flutter/material.dart';
import 'package:dexcurator/screens/detail/detail_shared.dart' show neutralBg;
import 'package:dexcurator/screens/menu/items_list_screen.dart'
    show ItemEntry, ItemSprite;

class ItemDetailScreen extends StatelessWidget {
  final ItemEntry item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sellPrice = item.cost > 0 ? (item.cost ~/ 2) : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.displayName),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [

        // ── Sprite + Nome ──────────────────────────────────────────
        Center(child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: neutralBg(context),
            borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            ItemSprite(url: item.sprite, size: 80),
            const SizedBox(height: 12),
            Text(item.displayName, textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            if (item.namePt.isNotEmpty && item.namePt != item.nameEn) ...[
              const SizedBox(height: 2),
              Text(item.nameEn.replaceAll('-', ' '),
                  style: TextStyle(fontSize: 12,
                      color: scheme.onSurfaceVariant)),
            ],
          ]),
        )),

        const SizedBox(height: 16),

        // ── Categoria e Bolsa ─────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: neutralBg(context),
            borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            _InfoRow('Categoria', item.categoryPt, scheme),
            Divider(height: 1, color: scheme.outlineVariant.withOpacity(0.4)),
            _InfoRow('Aba na bolsa', item.pocket, scheme),
            if (item.cost > 0) ...[
              Divider(height: 1, color: scheme.outlineVariant.withOpacity(0.4)),
              _InfoRow('Preço de compra', '₽${_fmt(item.cost)}', scheme),
              Divider(height: 1, color: scheme.outlineVariant.withOpacity(0.4)),
              _InfoRow('Preço de venda', '₽${_fmt(sellPrice)}', scheme),
            ] else
              ...[
                Divider(height: 1,
                    color: scheme.outlineVariant.withOpacity(0.4)),
                _InfoRow('Preço', 'Não vendível', scheme),
              ],
          ]),
        ),

        // ── Descrição no jogo ─────────────────────────────────────
        if (item.flavor.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Descrição no jogo',
            child: Text(item.flavor,
                style: TextStyle(fontSize: 13, color: scheme.onSurface,
                    height: 1.5, fontStyle: FontStyle.italic)),
          ),
        ],

        // ── Efeito detalhado ──────────────────────────────────────
        if (item.effect.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: 'Efeito',
            child: Text(item.effect,
                style: TextStyle(fontSize: 13, color: scheme.onSurface,
                    height: 1.5)),
          ),
        ],

        const SizedBox(height: 32),
      ]),
    );
  }

  String _fmt(int v) {
    if (v >= 1000) {
      final k = v ~/ 1000;
      final r = v % 1000;
      return r == 0 ? '${k}k' : '$v';
    }
    return v.toString();
  }
}

// ─── Linha de info ────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label, value; final ColorScheme scheme;
  const _InfoRow(this.label, this.value, this.scheme);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(children: [
      Text(label, style: TextStyle(fontSize: 12,
          color: scheme.onSurfaceVariant)),
      const Spacer(),
      Text(value, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ─── Seção com título ─────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title; final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: neutralBg(context),
        borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.6)),
        const SizedBox(height: 6),
        child,
      ]),
    );
  }
}

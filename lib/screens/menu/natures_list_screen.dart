import 'package:flutter/material.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart'
    show BilingualTerm;

// ─── Modelo ───────────────────────────────────────────────────────
class _Nature {
  final String  nameEn;
  final String  namePt;
  final String? increased;
  final String? decreased;
  final String? likeFlavor;
  final String? hateFlavor;
  const _Nature(this.nameEn, this.namePt, this.increased, this.decreased,
      [this.likeFlavor, this.hateFlavor]);
  bool get isNeutral => increased == null;
}

// ─── Dados ────────────────────────────────────────────────────────
const _natures = [
  _Nature('hardy',    'Forte',      null,   null),
  _Nature('lonely',   'Solitária',  'atk',  'def',  'spicy',  'sour'),
  _Nature('brave',    'Corajosa',   'atk',  'spe',  'spicy',  'sweet'),
  _Nature('adamant',  'Firme',      'atk',  'spa',  'spicy',  'dry'),
  _Nature('naughty',  'Levada',     'atk',  'spd',  'spicy',  'bitter'),
  _Nature('bold',     'Ousada',     'def',  'atk',  'sour',   'spicy'),
  _Nature('docile',   'Dócil',      null,   null),
  _Nature('relaxed',  'Tranquila',  'def',  'spe',  'sour',   'sweet'),
  _Nature('impish',   'Travessa',   'def',  'spa',  'sour',   'dry'),
  _Nature('lax',      'Descuidada', 'def',  'spd',  'sour',   'bitter'),
  _Nature('timid',    'Tímida',     'spe',  'atk',  'sweet',  'spicy'),
  _Nature('hasty',    'Apressada',  'spe',  'def',  'sweet',  'sour'),
  _Nature('serious',  'Séria',      null,   null),
  _Nature('jolly',    'Alegre',     'spe',  'spa',  'sweet',  'dry'),
  _Nature('naive',    'Ingênua',    'spe',  'spd',  'sweet',  'bitter'),
  _Nature('modest',   'Modesta',    'spa',  'atk',  'dry',    'spicy'),
  _Nature('mild',     'Suave',      'spa',  'def',  'dry',    'sour'),
  _Nature('quiet',    'Quieta',     'spa',  'spe',  'dry',    'sweet'),
  _Nature('bashful',  'Acanhada',   null,   null),
  _Nature('rash',     'Impulsiva',  'spa',  'spd',  'dry',    'bitter'),
  _Nature('calm',     'Calma',      'spd',  'atk',  'bitter', 'spicy'),
  _Nature('gentle',   'Gentil',     'spd',  'def',  'bitter', 'sour'),
  _Nature('sassy',    'Insolente',  'spd',  'spe',  'bitter', 'sweet'),
  _Nature('careful',  'Cuidadosa',  'spd',  'spa',  'bitter', 'dry'),
  _Nature('quirky',   'Estranha',   null,   null),
];

const _statLabel = {
  'atk': 'Ataque',
  'def': 'Defesa',
  'spa': 'Atq. Esp.',
  'spd': 'Def. Esp.',
  'spe': 'Velocidade',
};

const _flavorLabel = {
  'spicy':  'Apimentado',
  'sour':   'Azedo',
  'sweet':  'Doce',
  'dry':    'Seco',
  'bitter': 'Amargo',
};

const _flavorIcon = {
  'spicy':  '🌶',
  'sour':   '🍋',
  'sweet':  '🍬',
  'dry':    '🌿',
  'bitter': '☕',
};

// ─── Tela ─────────────────────────────────────────────────────────
class NaturesListScreen extends StatefulWidget {
  const NaturesListScreen({super.key});
  @override State<NaturesListScreen> createState() => _NaturesListScreenState();
}

class _NaturesListScreenState extends State<NaturesListScreen> {
  bool   _searching = false;
  String _search    = '';
  String? _filterStat;
  final _searchCtrl = TextEditingController();
  final _filterKey  = GlobalKey();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<_Nature> get _filtered {
    var list = _natures.toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((n) =>
          n.nameEn.contains(q) || n.namePt.toLowerCase().contains(q)).toList();
    }
    if (_filterStat != null) {
      list = list.where((n) => n.increased == _filterStat).toList();
    }
    return list;
  }

  void _toggleSearch() => setState(() {
    _searching = !_searching;
    if (!_searching) { _search = ''; _searchCtrl.clear(); }
  });

  void _showStatFilter() async {
    final box  = _filterKey.currentContext?.findRenderObject() as RenderBox?;
    final pos  = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = box?.size ?? Size.zero;
    final rect = RelativeRect.fromLTRB(
        pos.dx, pos.dy + size.height, pos.dx + size.width, 0);

    Widget item(String label, String? value) {
      final sel = _filterStat == value;
      return PopupMenuItem<String?>(
        value: value,
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(
              fontSize: 13,
              fontWeight: sel ? FontWeight.w700 : FontWeight.normal))),
          if (sel) Icon(Icons.check, size: 16,
              color: Theme.of(context).colorScheme.primary),
        ]),
      );
    }

    final result = await showMenu<String?>(
      context: context,
      position: rect,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        item('Todas', null),
        for (final s in ['atk', 'def', 'spa', 'spd', 'spe'])
          item('+ ${_statLabel[s]}', s),
      ],
    );
    if (mounted) setState(() => _filterStat = result);
  }

  @override
  Widget build(BuildContext context) {
    final scheme   = Theme.of(context).colorScheme;
    final filtered = _filtered;
    final label    = _filterStat == null
        ? 'Todas as naturezas'
        : '+ ${_statLabel[_filterStat]}';

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl, autofocus: true,
                onChanged: (v) => setState(() => _search = v),
                decoration: const InputDecoration(
                    hintText: 'Buscar natureza...', border: InputBorder.none),
                style: const TextStyle(fontSize: 16),
              )
            : const Text('Naturezas'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Column(children: [
        // Dropdown de filtro
        GestureDetector(
          key: _filterKey,
          onTap: _showStatFilter,
          child: Container(
            color: scheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(children: [
              Text(label, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: _filterStat != null
                      ? scheme.primary : scheme.onSurfaceVariant)),
              const SizedBox(width: 4),
              Icon(Icons.expand_more, size: 16,
                  color: _filterStat != null
                      ? scheme.primary : scheme.onSurfaceVariant),
            ]),
          ),
        ),

        Expanded(child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => Divider(
              height: 1, color: scheme.outlineVariant.withOpacity(0.5)),
          itemBuilder: (_, i) => _NatureTile(nature: filtered[i]),
        )),
      ]),
    );
  }
}

// ─── Tile ─────────────────────────────────────────────────────────
class _NatureTile extends StatelessWidget {
  final _Nature nature;
  const _NatureTile({required this.nature});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const up   = Color(0xFF2E7D32);
    const down = Color(0xFFC62828);
    const neu  = Color(0xFF888888);

    final incLabel = nature.increased != null ? _statLabel[nature.increased]! : '—';
    final decLabel = nature.decreased != null ? _statLabel[nature.decreased]! : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Nome da natureza
        BilingualTerm(
          namePt: nature.namePt,
          nameEn: nature.nameEn,
          baseStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          secondaryStyle: const TextStyle(fontSize: 11),
        ),

        const SizedBox(height: 8),

        // Badges de stat
        Row(children: [
          // Stat aumentado
          Expanded(child: _StatBox(
            label: incLabel,
            icon: nature.isNeutral
                ? Icons.remove_rounded
                : Icons.arrow_upward_rounded,
            color: nature.isNeutral ? neu : up,
            scheme: scheme,
          )),
          const SizedBox(width: 8),
          // Stat reduzido
          Expanded(child: _StatBox(
            label: nature.isNeutral ? '—' : decLabel,
            icon: nature.isNeutral
                ? Icons.remove_rounded
                : Icons.arrow_downward_rounded,
            color: nature.isNeutral ? neu : down,
            scheme: scheme,
          )),
        ]),

        // Sabores (só para não-neutras)
        if (!nature.isNeutral && nature.likeFlavor != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            _FlavorBadge(
              label: _flavorLabel[nature.likeFlavor]!,
              emoji: _flavorIcon[nature.likeFlavor]!,
              likes: true,
              scheme: scheme,
            ),
            const SizedBox(width: 8),
            _FlavorBadge(
              label: _flavorLabel[nature.hateFlavor]!,
              emoji: _flavorIcon[nature.hateFlavor]!,
              likes: false,
              scheme: scheme,
            ),
          ]),
        ],
      ]),
    );
  }
}

// ─── Caixa de stat ────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String      label;
  final IconData    icon;
  final Color       color;
  final ColorScheme scheme;
  const _StatBox({required this.label, required this.icon,
      required this.color, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.35), width: 0.5),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

// ─── Badge de sabor ───────────────────────────────────────────────
class _FlavorBadge extends StatelessWidget {
  final String      label;
  final String      emoji;
  final bool        likes;
  final ColorScheme scheme;
  const _FlavorBadge({required this.label, required this.emoji,
      required this.likes, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(children: [
        Text(likes ? 'Gosta:' : 'Odeia:',
            style: TextStyle(fontSize: 10,
                color: scheme.onSurfaceVariant.withOpacity(0.7))),
        const SizedBox(width: 4),
        Text(emoji, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w500,
            color: scheme.onSurface)),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:dexcurator/screens/detail/detail_shared.dart'
    show BilingualTerm;

// ─── Constantes de cor pré-computadas ────────────────────────────
// Evita withOpacity() em cada build
const _upBg     = Color(0x142E7D32); // verde 8%
const _upBorder = Color(0x592E7D32); // verde 35%
const _upText   = Color(0xFF2E7D32);
const _dnBg     = Color(0x14C62828);
const _dnBorder = Color(0x59C62828);
const _dnText   = Color(0xFFC62828);
const _neuBg    = Color(0x14888888);
const _neuBorder= Color(0x59888888);
const _neuText  = Color(0xFF888888);

// ─── Decorações pré-computadas ────────────────────────────────────
const _upDec  = BoxDecoration(color: _upBg,  borderRadius: BorderRadius.all(Radius.circular(4)), border: Border.fromBorderSide(BorderSide(color: _upBorder, width: 0.5)));
const _dnDec  = BoxDecoration(color: _dnBg,  borderRadius: BorderRadius.all(Radius.circular(4)), border: Border.fromBorderSide(BorderSide(color: _dnBorder, width: 0.5)));
const _neuDec = BoxDecoration(color: _neuBg, borderRadius: BorderRadius.all(Radius.circular(4)), border: Border.fromBorderSide(BorderSide(color: _neuBorder, width: 0.5)));

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
  'atk': 'Ataque',       'def': 'Defesa',
  'spa': 'Atq. Esp.',    'spd': 'Def. Esp.',
  'spe': 'Velocidade',
};

const _flavorLabel = {
  'spicy': 'Apimentado', 'sour':   'Azedo',
  'sweet': 'Doce',       'dry':    'Seco',
  'bitter':'Amargo',
};

const _flavorIcon = {
  'spicy': '🌶', 'sour': '🍋',
  'sweet': '🍬', 'dry':  '🌿',
  'bitter':'☕',
};

// ─── Tela ─────────────────────────────────────────────────────────
class NaturesListScreen extends StatefulWidget {
  const NaturesListScreen({super.key});
  @override State<NaturesListScreen> createState() => _NaturesListScreenState();
}

class _NaturesListScreenState extends State<NaturesListScreen> {
  bool    _searching  = false;
  String  _search     = '';
  String? _filterStat;
  final   _searchCtrl = TextEditingController();
  final   _filterKey  = GlobalKey();

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
    final box = _filterKey.currentContext?.findRenderObject() as RenderBox?;
    final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final sz  = box?.size ?? Size.zero;
    final rect = RelativeRect.fromLTRB(pos.dx, pos.dy + sz.height, pos.dx + sz.width, 0);

    PopupMenuItem<String?> mk(String label, String? value) {
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
        mk('Todas', null),
        for (final s in ['atk', 'def', 'spa', 'spd', 'spe'])
          mk('+ ${_statLabel[s]}', s),
      ],
    );
    if (mounted) setState(() => _filterStat = result);
  }

  @override
  Widget build(BuildContext context) {
    final scheme   = Theme.of(context).colorScheme;
    final filtered = _filtered;
    final label    = _filterStat == null
        ? 'Todas as naturezas' : '+ ${_statLabel[_filterStat]}';

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
        GestureDetector(
          key: _filterKey,
          onTap: _showStatFilter,
          child: Container(
            color: scheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(children: [
              Text(label, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: _filterStat != null ? scheme.primary : scheme.onSurfaceVariant)),
              const SizedBox(width: 4),
              Icon(Icons.expand_more, size: 16,
                  color: _filterStat != null ? scheme.primary : scheme.onSurfaceVariant),
            ]),
          ),
        ),
        Expanded(child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          // itemExtent fixo para evitar cálculos de layout por item
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x1A888888)),
          itemBuilder: (_, i) => _NatureTile(nature: filtered[i]),
        )),
      ]),
    );
  }
}

// ─── Tile — const onde possível, sem withOpacity() ────────────────
class _NatureTile extends StatelessWidget {
  final _Nature nature;
  const _NatureTile({required this.nature, super.key});

  @override
  Widget build(BuildContext context) {
    final n = nature;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Nome
        BilingualTerm(
          namePt: n.namePt,
          nameEn: n.nameEn,
          baseStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          secondaryStyle: const TextStyle(fontSize: 11),
        ),

        // Sabores (logo abaixo do nome, só não-neutras)
        if (!n.isNeutral && n.likeFlavor != null) ...[
          const SizedBox(height: 4),
          Row(children: [
            Text('Gosta: ', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
            Text(_flavorIcon[n.likeFlavor]!, style: const TextStyle(fontSize: 10)),
            const SizedBox(width: 2),
            Text(_flavorLabel[n.likeFlavor]!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
            const SizedBox(width: 12),
            Text('Odeia: ', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
            Text(_flavorIcon[n.hateFlavor]!, style: const TextStyle(fontSize: 10)),
            const SizedBox(width: 2),
            Text(_flavorLabel[n.hateFlavor]!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
          ]),
        ],

        const SizedBox(height: 7),

        // Caixas de stat
        if (n.isNeutral)
          // Neutras: um único traço centralizado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: _neuDec,
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.remove_rounded, size: 13, color: _neuText),
              SizedBox(width: 5),
              Text('Neutra', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _neuText)),
            ]),
          )
        else
          Row(children: [
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
              decoration: _upDec,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.arrow_upward_rounded, size: 13, color: _upText),
                const SizedBox(width: 5),
                Text(_statLabel[n.increased]!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _upText)),
              ]),
            )),
            const SizedBox(width: 8),
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
              decoration: _dnDec,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.arrow_downward_rounded, size: 13, color: _dnText),
                const SizedBox(width: 5),
                Text(_statLabel[n.decreased]!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _dnText)),
              ]),
            )),
          ]),
      ]),
    );
  }
}

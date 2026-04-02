import 'package:flutter/material.dart';
import 'package:dexcurator/models/pokemon.dart';
import 'package:dexcurator/screens/detail/detail_shared.dart'
    show ptType, defaultSpriteNotifier;
import 'package:dexcurator/screens/go/go_detail_screen.dart';
import 'package:dexcurator/services/pokeapi_service.dart';
import 'package:dexcurator/services/storage_service.dart';
import 'package:dexcurator/theme/type_colors.dart';

class GoRegionalFormsScreen extends StatefulWidget {
  const GoRegionalFormsScreen({super.key});
  @override State<GoRegionalFormsScreen> createState() => _GoRegionalFormsScreenState();
}

class _GoRegionalFormsScreenState extends State<GoRegionalFormsScreen> {
  final _api     = PokeApiService();
  final _storage = StorageService();
  final Map<String, Map<String, dynamic>?> _statsCache = {};

  Future<void> _openDetail(BuildContext ctx, _FormEntry form) async {
    final cacheKey = form.spriteKey ?? '${form.id}';
    if (!_statsCache.containsKey(cacheKey)) {
      final data = await _api.fetchPokemon(form.id)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      _statsCache[cacheKey] = data;
    }
    final d = _statsCache[cacheKey];
    int sv(String n) {
      final raw = d?['stats'] as List?;
      if (raw == null) return 0;
      final s = raw.firstWhere((s) => s['stat']['name'] == n, orElse: () => null);
      return (s?['base_stat'] as int?) ?? 0;
    }
    final st     = defaultSpriteNotifier.value;
    final folder = st == 'pixel' ? 'pixel' : st == 'home' ? 'home' : 'artwork';
    final key    = form.spriteKey ?? '${form.id}';
    const base   = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';

    final pokemon = Pokemon(
      id: form.id, entryNumber: form.id,
      name: form.name,            // nome PT completo ex: "Marowak de Alola"
      types: form.types,          // tipos corretos da forma
      baseHp: sv('hp'), baseAttack: sv('attack'), baseDefense: sv('defense'),
      baseSpAttack: sv('special-attack'), baseSpDefense: sv('special-defense'),
      baseSpeed: sv('speed'),
      spriteUrl:           'assets/sprites/$folder/$key.webp',
      spriteShinyUrl:      '$base/other/official-artwork/shiny/${form.id}.png',
      spritePixelUrl:      'assets/sprites/pixel/$key.webp',
      spritePixelShinyUrl: '$base/shiny/${form.id}.png',
      spritePixelFemaleUrl: null,
      spriteHomeUrl:       'assets/sprites/artwork/$key.webp',
      spriteHomeShinyUrl:  '$base/other/home/shiny/${form.id}.png',
      spriteHomeFemaleUrl: null,
    );
    if (!ctx.mounted) return;
    bool caught = await _storage.isCaught('pokémon_go', form.id);
    if (!ctx.mounted) return;
    Navigator.push(ctx, PageRouteBuilder(
      pageBuilder: (_, __, ___) => GoDetailScreen(
        pokemon: pokemon, caught: caught,
        hideFormsTab: true,
        onToggleCaught: () async {
          caught = !caught;
          await _storage.setCaught('pokémon_go', form.id, caught);
        },
      ),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 180),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Formas Alternativas'),
          scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent,
          bottom: TabBar(
            tabs: const [Tab(text: 'Regionais'), Tab(text: 'Variantes'), Tab(text: 'Outras')],
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        body: TabBarView(children: [
          _RegionalTab(onTap: _openDetail),
          _VariantsTab(onTap: _openDetail),
          _OtherFormsTab(onTap: _openDetail),
        ]),
      ),
    );
  }
}

// ─── Badge de tipo compacto ───────────────────────────────────────
class _TypeChip extends StatelessWidget {
  final String type;
  const _TypeChip(this.type);
  static const _names = {
    'normal':'Normal','fire':'Fogo','water':'Água','electric':'Elétrico',
    'grass':'Planta','ice':'Gelo','fighting':'Lutador','poison':'Veneno',
    'ground':'Terreno','flying':'Voador','psychic':'Psíquico','bug':'Inseto',
    'rock':'Pedra','ghost':'Fantasma','dragon':'Dragão','dark':'Sombrio',
    'steel':'Aço','fairy':'Fada',
  };
  @override
  Widget build(BuildContext context) {
    final color = TypeColors.fromType(ptType(type));
    return Container(
      height: 18, constraints: const BoxConstraints(minWidth: 70),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      child: Row(mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset('assets/types/$type.png', width: 10, height: 10,
              errorBuilder: (_, __, ___) => const SizedBox(width: 10)),
          const SizedBox(width: 3),
          Text(_names[type] ?? type, style: const TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: Colors.white, height: 1.0)),
        ]),
    );
  }
}

// ─── Tile de forma ────────────────────────────────────────────────
class _FormTile extends StatefulWidget {
  final _FormEntry form;
  final Future<void> Function(BuildContext, _FormEntry) onTap;
  const _FormTile({required this.form, required this.onTap});
  @override State<_FormTile> createState() => _FormTileState();
}

class _FormTileState extends State<_FormTile> {
  bool _tapping = false;
  @override
  Widget build(BuildContext context) {
    final scheme     = Theme.of(context).colorScheme;
    final key        = widget.form.spriteKey ?? '${widget.form.id}';
    final spritePath = 'assets/sprites/artwork/$key.webp';
    return GestureDetector(
      onTap: _tapping ? null : () async {
        setState(() => _tapping = true);
        await widget.onTap(context, widget.form);
        if (mounted) setState(() => _tapping = false);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: scheme.outlineVariant, width: 0.5)),
        child: Row(children: [
          Image.asset(spritePath, width: 40, height: 40, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/sprites/artwork/${widget.form.id}.webp',
              width: 40, height: 40, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => SizedBox(width: 40, height: 40,
                child: Icon(Icons.catching_pokemon, size: 24,
                    color: scheme.onSurfaceVariant.withOpacity(0.4))))),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.form.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Wrap(spacing: 4, runSpacing: 3,
                children: widget.form.types.map((t) => _TypeChip(t)).toList()),
            ])),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 16,
              color: scheme.onSurfaceVariant.withOpacity(0.4)),
        ]),
      ),
    );
  }
}

class _SectionWidget extends StatelessWidget {
  final _FormSection section;
  final Future<void> Function(BuildContext, _FormEntry) onTap;
  const _SectionWidget({required this.section, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8),
        child: Text(section.title, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant))),
      ...section.forms.map((f) => _FormTile(form: f, onTap: onTap)),
      const SizedBox(height: 16),
    ]);
  }
}

// ─── ABA: Regionais ───────────────────────────────────────────────
class _RegionalTab extends StatelessWidget {
  final Future<void> Function(BuildContext, _FormEntry) onTap;
  const _RegionalTab({required this.onTap});
  static const _sections = [
    _FormSection('Alola', [
      _FormEntry(26,  'Raichu de Alola',    ['electric','psychic'], spriteKey: '26_ALOLA'),
      _FormEntry(27,  'Sandshrew de Alola', ['ice','steel'],        spriteKey: '27_ALOLA'),
      _FormEntry(28,  'Sandslash de Alola', ['ice','steel'],        spriteKey: '28_ALOLA'),
      _FormEntry(37,  'Vulpix de Alola',    ['ice'],                spriteKey: '37_ALOLA'),
      _FormEntry(38,  'Ninetales de Alola', ['ice','fairy'],        spriteKey: '38_ALOLA'),
      _FormEntry(50,  'Diglett de Alola',   ['ground','steel'],     spriteKey: '50_ALOLA'),
      _FormEntry(51,  'Dugtrio de Alola',   ['ground','steel'],     spriteKey: '51_ALOLA'),
      _FormEntry(52,  'Meowth de Alola',    ['dark'],               spriteKey: '52_ALOLA'),
      _FormEntry(53,  'Persian de Alola',   ['dark'],               spriteKey: '53_ALOLA'),
      _FormEntry(74,  'Geodude de Alola',   ['rock','electric'],    spriteKey: '74_ALOLA'),
      _FormEntry(75,  'Graveler de Alola',  ['rock','electric'],    spriteKey: '75_ALOLA'),
      _FormEntry(76,  'Golem de Alola',     ['rock','electric'],    spriteKey: '76_ALOLA'),
      _FormEntry(88,  'Grimer de Alola',    ['poison','dark'],      spriteKey: '88_ALOLA'),
      _FormEntry(89,  'Muk de Alola',       ['poison','dark'],      spriteKey: '89_ALOLA'),
      _FormEntry(103, 'Exeggutor de Alola', ['grass','dragon'],     spriteKey: '103_ALOLA'),
      _FormEntry(105, 'Marowak de Alola',   ['fire','ghost'],       spriteKey: '105_ALOLA'),
    ]),
    _FormSection('Galar', [
      _FormEntry(52,  'Meowth de Galar',    ['steel'],              spriteKey: '52_GALARIAN'),
      _FormEntry(77,  'Ponyta de Galar',    ['psychic'],            spriteKey: '77_GALARIAN'),
      _FormEntry(78,  'Rapidash de Galar',  ['psychic','fairy'],    spriteKey: '78_GALARIAN'),
      _FormEntry(79,  'Slowpoke de Galar',  ['psychic'],            spriteKey: '79_GALARIAN'),
      _FormEntry(80,  'Slowbro de Galar',   ['poison','psychic'],   spriteKey: '80_GALARIAN'),
      _FormEntry(83,  "Farfetch'd de Galar",['fighting'],           spriteKey: '83_GALARIAN'),
      _FormEntry(110, 'Weezing de Galar',   ['poison','fairy'],     spriteKey: '110_GALARIAN'),
      _FormEntry(122, 'Mr. Mime de Galar',  ['ice','psychic'],      spriteKey: '122_GALARIAN'),
      _FormEntry(144, 'Articuno de Galar',  ['psychic','flying'],   spriteKey: '144_GALARIAN'),
      _FormEntry(145, 'Zapdos de Galar',    ['fighting','flying'],  spriteKey: '145_GALARIAN'),
      _FormEntry(146, 'Moltres de Galar',   ['dark','flying'],      spriteKey: '146_GALARIAN'),
      _FormEntry(199, 'Slowking de Galar',  ['poison','psychic'],   spriteKey: '199_GALARIAN'),
      _FormEntry(222, 'Corsola de Galar',   ['ghost'],              spriteKey: '222_GALARIAN'),
      _FormEntry(263, 'Zigzagoon de Galar', ['dark','normal'],      spriteKey: '263_GALARIAN'),
      _FormEntry(264, 'Linoone de Galar',   ['dark','normal'],      spriteKey: '264_GALARIAN'),
      _FormEntry(618, 'Stunfisk de Galar',  ['ground','steel'],     spriteKey: '618_GALARIAN'),
    ]),
    _FormSection('Hisui', [
      _FormEntry(58,  'Growlithe de Hisui', ['fire','rock'],        spriteKey: '58_HISUI'),
      _FormEntry(59,  'Arcanine de Hisui',  ['fire','rock'],        spriteKey: '59_HISUI'),
      _FormEntry(100, 'Voltorb de Hisui',   ['electric','grass'],   spriteKey: '100_HISUI'),
      _FormEntry(101, 'Electrode de Hisui', ['electric','grass'],   spriteKey: '101_HISUI'),
      _FormEntry(157, 'Typhlosion de Hisui',['fire','ghost'],       spriteKey: '157_HISUI'),
      _FormEntry(211, 'Qwilfish de Hisui',  ['dark','poison'],      spriteKey: '211_HISUI'),
      _FormEntry(215, 'Sneasel de Hisui',   ['fighting','poison'],  spriteKey: '215_HISUI'),
      _FormEntry(503, 'Samurott de Hisui',  ['water','dark'],       spriteKey: '503_HISUI'),
      _FormEntry(549, 'Lilligant de Hisui', ['grass','fighting'],   spriteKey: '549_HISUI'),
      _FormEntry(570, 'Zorua de Hisui',     ['normal','ghost'],     spriteKey: '570_HISUI'),
      _FormEntry(571, 'Zoroark de Hisui',   ['normal','ghost'],     spriteKey: '571_HISUI'),
      _FormEntry(628, 'Braviary de Hisui',  ['psychic','flying'],   spriteKey: '628_HISUI'),
      _FormEntry(705, 'Sliggoo de Hisui',   ['steel','dragon'],     spriteKey: '705_HISUI'),
      _FormEntry(706, 'Goodra de Hisui',    ['steel','dragon'],     spriteKey: '706_HISUI'),
      _FormEntry(724, 'Decidueye de Hisui', ['grass','fighting'],   spriteKey: '724_HISUI'),
    ]),
    _FormSection('Paldea', [
      _FormEntry(128, 'Tauros de Paldea (Combat)', ['fighting'],         spriteKey: '128_PALDEA_COMBAT'),
      _FormEntry(128, 'Tauros de Paldea (Blaze)',  ['fighting','fire'],  spriteKey: '128_PALDEA_BLAZE'),
      _FormEntry(128, 'Tauros de Paldea (Aqua)',   ['fighting','water'], spriteKey: '128_PALDEA_AQUA'),
      _FormEntry(194, 'Wooper de Paldea',          ['poison','ground'],  spriteKey: '194_PALDEA'),
    ]),
  ];
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: _sections.map((s) => _SectionWidget(section: s, onTap: onTap)).toList());
}

// ─── ABA: Variantes ───────────────────────────────────────────────
class _VariantsTab extends StatelessWidget {
  final Future<void> Function(BuildContext, _FormEntry) onTap;
  const _VariantsTab({required this.onTap});
  static const _sections = [
    _FormSection('Unown', [
      _FormEntry(201, 'Unown (A–Z, !, ?)', ['psychic']),
    ]),
    _FormSection('Vivillon', [
      _FormEntry(666, 'Vivillon (20 padrões)', ['bug','flying']),
    ]),
    _FormSection('Flabébé / Floette / Florges', [
      _FormEntry(669, 'Flabébé (5 cores)', ['fairy']),
    ]),
  ];
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: _sections.map((s) => _SectionWidget(section: s, onTap: onTap)).toList());
}

// ─── ABA: Outras Formas ───────────────────────────────────────────
class _OtherFormsTab extends StatelessWidget {
  final Future<void> Function(BuildContext, _FormEntry) onTap;
  const _OtherFormsTab({required this.onTap});
  static const _sections = [
    _FormSection('Castform', [
      _FormEntry(351, 'Castform Normal', ['normal']),
      _FormEntry(351, 'Castform Sunny',  ['fire'],  spriteKey: '351_SUNNY'),
      _FormEntry(351, 'Castform Rainy',  ['water'], spriteKey: '351_RAINY'),
      _FormEntry(351, 'Castform Snowy',  ['ice'],   spriteKey: '351_SNOWY'),
    ]),
    _FormSection('Deoxys', [
      _FormEntry(386, 'Deoxys Normal',   ['psychic']),
      _FormEntry(386, 'Deoxys Attack',   ['psychic'], spriteKey: '386_ATTACK'),
      _FormEntry(386, 'Deoxys Defense',  ['psychic'], spriteKey: '386_DEFENSE'),
      _FormEntry(386, 'Deoxys Speed',    ['psychic'], spriteKey: '386_SPEED'),
    ]),
    _FormSection('Rotom', [
      _FormEntry(479, 'Rotom Normal',  ['electric','ghost']),
      _FormEntry(479, 'Rotom Heat',    ['electric','fire'],   spriteKey: '479_HEAT'),
      _FormEntry(479, 'Rotom Wash',    ['electric','water'],  spriteKey: '479_WASH'),
      _FormEntry(479, 'Rotom Frost',   ['electric','ice'],    spriteKey: '479_FROST'),
      _FormEntry(479, 'Rotom Fan',     ['electric','flying'], spriteKey: '479_FAN'),
      _FormEntry(479, 'Rotom Mow',     ['electric','grass'],  spriteKey: '479_MOW'),
    ]),
    _FormSection('Giratina', [
      _FormEntry(487, 'Giratina Altered', ['ghost','dragon']),
      _FormEntry(487, 'Giratina Origin',  ['ghost','dragon'], spriteKey: '487_ORIGIN'),
    ]),
    _FormSection('Shaymin', [
      _FormEntry(492, 'Shaymin Land', ['grass']),
      _FormEntry(492, 'Shaymin Sky',  ['grass','flying'], spriteKey: '492_SKY'),
    ]),
    _FormSection('Tornadus / Thundurus / Landorus', [
      _FormEntry(641, 'Tornadus Incarnate',  ['flying']),
      _FormEntry(641, 'Tornadus Therian',    ['flying'],            spriteKey: '641_THERIAN'),
      _FormEntry(642, 'Thundurus Incarnate', ['electric','flying']),
      _FormEntry(642, 'Thundurus Therian',   ['electric','flying'], spriteKey: '642_THERIAN'),
      _FormEntry(645, 'Landorus Incarnate',  ['ground','flying']),
      _FormEntry(645, 'Landorus Therian',    ['ground','flying'],   spriteKey: '645_THERIAN'),
    ]),
    _FormSection('Kyurem', [
      _FormEntry(646, 'Kyurem Normal', ['dragon','ice']),
      _FormEntry(646, 'Kyurem Black',  ['dragon','ice'], spriteKey: '646_BLACK'),
      _FormEntry(646, 'Kyurem White',  ['dragon','ice'], spriteKey: '646_WHITE'),
    ]),
    _FormSection('Zygarde', [
      _FormEntry(718, 'Zygarde 10%',      ['dragon','ground'], spriteKey: '718_10'),
      _FormEntry(718, 'Zygarde 50%',      ['dragon','ground']),
      _FormEntry(718, 'Zygarde Complete', ['dragon','ground'], spriteKey: '718_COMPLETE'),
    ]),
  ];
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: _sections.map((s) => _SectionWidget(section: s, onTap: onTap)).toList());
}

// ─── Modelos ──────────────────────────────────────────────────────
class _FormSection {
  final String title; final List<_FormEntry> forms;
  const _FormSection(this.title, this.forms);
}

class _FormEntry {
  final int id;
  final String name;
  final List<String> types;
  final String? spriteKey;
  const _FormEntry(this.id, this.name, this.types, {this.spriteKey});
}

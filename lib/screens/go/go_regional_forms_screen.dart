import 'package:flutter/material.dart';
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart'
    show ptType, defaultSpriteNotifier;
import 'package:pokedex_tracker/screens/go/go_detail_screen.dart';
import 'package:pokedex_tracker/services/pokeapi_service.dart';
import 'package:pokedex_tracker/services/pokedex_data_service.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/theme/type_colors.dart';

// Formas alternativas disponíveis no Pokémon GO (mar/2026)
// Fontes: Bulbapedia, Serebii, LeekDuck

class GoRegionalFormsScreen extends StatefulWidget {
  const GoRegionalFormsScreen({super.key});
  @override
  State<GoRegionalFormsScreen> createState() => _GoRegionalFormsScreenState();
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
    final apiData = _statsCache[cacheKey];

    int statVal(String name) {
      final raw = apiData?['stats'] as List<dynamic>?;
      if (raw == null) return 0;
      final s = raw.firstWhere((s) => s['stat']['name'] == name, orElse: () => null);
      return (s?['base_stat'] as int?) ?? 0;
    }

    final svc   = PokedexDataService.instance;
    final types = svc.getTypes(form.id);
    final st    = defaultSpriteNotifier.value;
    const base  = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';

    String spriteAsset(String t) {
      final folder = t == 'pixel' ? 'pixel' : t == 'home' ? 'home' : 'artwork';
      final key = form.spriteKey ?? '${form.id}';
      return 'assets/sprites/$folder/$key.webp';
    }

    final pokemon = Pokemon(
      id: form.id, entryNumber: form.id,
      name: form.name.replaceAll(RegExp(r' de (Alola|Galar|Hisui|Paldea)'), ''),
      types: types.isNotEmpty ? types : ['normal'],
      baseHp: statVal('hp'), baseAttack: statVal('attack'),
      baseDefense: statVal('defense'), baseSpAttack: statVal('special-attack'),
      baseSpDefense: statVal('special-defense'), baseSpeed: statVal('speed'),
      spriteUrl:           spriteAsset(st),
      spriteShinyUrl:      '$base/other/official-artwork/shiny/${form.id}.png',
      spritePixelUrl:      spriteAsset('pixel'),
      spritePixelShinyUrl: '$base/shiny/${form.id}.png',
      spritePixelFemaleUrl: null,
      spriteHomeUrl:       spriteAsset('artwork'),
      spriteHomeShinyUrl:  '$base/other/home/shiny/${form.id}.png',
      spriteHomeFemaleUrl: null,
    );

    if (!ctx.mounted) return;
    bool caught = await _storage.isCaught('pokémon_go', form.id);
    if (!ctx.mounted) return;

    Navigator.push(ctx, PageRouteBuilder(
      pageBuilder: (_, __, ___) => GoDetailScreen(
        pokemon: pokemon, caught: caught,
        onToggleCaught: () async {
          caught = !caught;
          await _storage.setCaught('pokémon_go', form.id, caught);
        },
      ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 180),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Formas Alternativas'),
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Regionais'),
              Tab(text: 'Variantes'),
              Tab(text: 'Outras'),
            ],
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

// ─── ABA: Formas Regionais ────────────────────────────────────────

class _RegionalTab extends StatelessWidget {
  final Future<void> Function(BuildContext, _FormEntry) onTap;
  const _RegionalTab({required this.onTap});

  static const _sections = [
    _FormSection('Alola', [
      _FormEntry(26,  'Raichu de Alola',    'Elétrico / Psíquico', spriteKey: '26_ALOLA'),
      _FormEntry(27,  'Sandshrew de Alola', 'Gelo / Aço',          spriteKey: '27_ALOLA'),
      _FormEntry(28,  'Sandslash de Alola', 'Gelo / Aço',          spriteKey: '28_ALOLA'),
      _FormEntry(37,  'Vulpix de Alola',    'Gelo',                spriteKey: '37_ALOLA'),
      _FormEntry(38,  'Ninetales de Alola', 'Gelo / Fada',         spriteKey: '38_ALOLA'),
      _FormEntry(50,  'Diglett de Alola',   'Terra / Aço',         spriteKey: '50_ALOLA'),
      _FormEntry(51,  'Dugtrio de Alola',   'Terra / Aço',         spriteKey: '51_ALOLA'),
      _FormEntry(52,  'Meowth de Alola',    'Sombrio',             spriteKey: '52_ALOLA'),
      _FormEntry(53,  'Persian de Alola',   'Sombrio',             spriteKey: '53_ALOLA'),
      _FormEntry(74,  'Geodude de Alola',   'Pedra / Elétrico',    spriteKey: '74_ALOLA'),
      _FormEntry(75,  'Graveler de Alola',  'Pedra / Elétrico',    spriteKey: '75_ALOLA'),
      _FormEntry(76,  'Golem de Alola',     'Pedra / Elétrico',    spriteKey: '76_ALOLA'),
      _FormEntry(88,  'Grimer de Alola',    'Venenoso / Sombrio',  spriteKey: '88_ALOLA'),
      _FormEntry(89,  'Muk de Alola',       'Venenoso / Sombrio',  spriteKey: '89_ALOLA'),
      _FormEntry(103, 'Exeggutor de Alola', 'Planta / Dragão',     spriteKey: '103_ALOLA'),
      _FormEntry(105, 'Marowak de Alola',   'Fogo / Fantasma',     spriteKey: '105_ALOLA'),
    ]),
    _FormSection('Galar', [
      _FormEntry(52,  'Meowth de Galar',    'Aço',                 spriteKey: '52_GALARIAN'),
      _FormEntry(77,  'Ponyta de Galar',    'Psíquico',            spriteKey: '77_GALARIAN'),
      _FormEntry(78,  'Rapidash de Galar',  'Psíquico / Fada',     spriteKey: '78_GALARIAN'),
      _FormEntry(79,  'Slowpoke de Galar',  'Psíquico',            spriteKey: '79_GALARIAN'),
      _FormEntry(80,  'Slowbro de Galar',   'Venenoso / Psíquico', spriteKey: '80_GALARIAN'),
      _FormEntry(83,  "Farfetch'd de Galar",'Lutador',             spriteKey: '83_GALARIAN'),
      _FormEntry(110, 'Weezing de Galar',   'Venenoso / Fada',     spriteKey: '110_GALARIAN'),
      _FormEntry(122, 'Mr. Mime de Galar',  'Gelo / Psíquico',     spriteKey: '122_GALARIAN'),
      _FormEntry(144, 'Articuno de Galar',  'Psíquico / Voador',   spriteKey: '144_GALARIAN'),
      _FormEntry(145, 'Zapdos de Galar',    'Lutador / Voador',    spriteKey: '145_GALARIAN'),
      _FormEntry(146, 'Moltres de Galar',   'Sombrio / Voador',    spriteKey: '146_GALARIAN'),
      _FormEntry(199, 'Slowking de Galar',  'Venenoso / Psíquico', spriteKey: '199_GALARIAN'),
      _FormEntry(222, 'Corsola de Galar',   'Fantasma',            spriteKey: '222_GALARIAN'),
      _FormEntry(263, 'Zigzagoon de Galar', 'Sombrio / Normal',    spriteKey: '263_GALARIAN'),
      _FormEntry(264, 'Linoone de Galar',   'Sombrio / Normal',    spriteKey: '264_GALARIAN'),
      _FormEntry(618, 'Stunfisk de Galar',  'Terra / Aço',         spriteKey: '618_GALARIAN'),
    ]),
    _FormSection('Hisui', [
      _FormEntry(58,  'Growlithe de Hisui', 'Fogo / Pedra',        spriteKey: '58_HISUI'),
      _FormEntry(59,  'Arcanine de Hisui',  'Fogo / Pedra',        spriteKey: '59_HISUI'),
      _FormEntry(100, 'Voltorb de Hisui',   'Elétrico / Planta',   spriteKey: '100_HISUI'),
      _FormEntry(101, 'Electrode de Hisui', 'Elétrico / Planta',   spriteKey: '101_HISUI'),
      _FormEntry(157, 'Typhlosion de Hisui','Fogo / Fantasma',     spriteKey: '157_HISUI'),
      _FormEntry(211, 'Qwilfish de Hisui',  'Sombrio / Venenoso',  spriteKey: '211_HISUI'),
      _FormEntry(215, 'Sneasel de Hisui',   'Lutador / Venenoso',  spriteKey: '215_HISUI'),
      _FormEntry(503, 'Samurott de Hisui',  'Água / Sombrio',      spriteKey: '503_HISUI'),
      _FormEntry(549, 'Lilligant de Hisui', 'Planta / Lutador',    spriteKey: '549_HISUI'),
      _FormEntry(570, 'Zorua de Hisui',     'Normal / Fantasma',   spriteKey: '570_HISUI'),
      _FormEntry(571, 'Zoroark de Hisui',   'Normal / Fantasma',   spriteKey: '571_HISUI'),
      _FormEntry(628, 'Braviary de Hisui',  'Psíquico / Voador',   spriteKey: '628_HISUI'),
      _FormEntry(705, 'Sliggoo de Hisui',   'Aço / Dragão',        spriteKey: '705_HISUI'),
      _FormEntry(706, 'Goodra de Hisui',    'Aço / Dragão',        spriteKey: '706_HISUI'),
      _FormEntry(724, 'Decidueye de Hisui', 'Planta / Lutador',    spriteKey: '724_HISUI'),
    ]),
    _FormSection('Paldea', [
      _FormEntry(128, 'Tauros de Paldea (Combat)', 'Lutador',             spriteKey: '128_PALDEA_COMBAT'),
      _FormEntry(128, 'Tauros de Paldea (Blaze)',  'Lutador / Fogo',      spriteKey: '128_PALDEA_BLAZE'),
      _FormEntry(128, 'Tauros de Paldea (Aqua)',   'Lutador / Água',      spriteKey: '128_PALDEA_AQUA'),
      _FormEntry(194, 'Wooper de Paldea',          'Venenoso / Terra',    spriteKey: '194_PALDEA'),
      _FormEntry(195, 'Quagsire',                  'Venenoso / Terra',    spriteKey: '195_PALDEA'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _sections.map((s) =>
          _FormSectionWidget(section: s, scheme: scheme, onTap: onTap)).toList(),
    );
  }
}

// ─── ABA: Variantes ───────────────────────────────────────────────

class _VariantsTab extends StatelessWidget {
  final Future<void> Function(BuildContext, _FormEntry) onTap;
  const _VariantsTab({required this.onTap});

  static const _sections = [
    _FormSection('Unown (28 formas)', [
      _FormEntry(201, 'Unown A–Z, !, ?', 'Psíquico'),
    ]),
    _FormSection('Vivillon (20 padrões)', [
      _FormEntry(666, 'Vivillon (vários padrões)', 'Inseto / Voador'),
    ]),
    _FormSection('Flabébé / Floette / Florges (5 cores)', [
      _FormEntry(669, 'Flabébé (5 cores)', 'Fada'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _sections.map((s) =>
          _FormSectionWidget(section: s, scheme: scheme, onTap: onTap)).toList(),
    );
  }
}

// ─── ABA: Outras Formas ───────────────────────────────────────────

class _OtherFormsTab extends StatelessWidget {
  final Future<void> Function(BuildContext, _FormEntry) onTap;
  const _OtherFormsTab({required this.onTap});

  static const _sections = [
    _FormSection('Castform (4 formas)', [
      _FormEntry(351, 'Castform Normal',  'Normal'),
      _FormEntry(351, 'Castform Sunny',   'Fogo'),
      _FormEntry(351, 'Castform Rainy',   'Água'),
      _FormEntry(351, 'Castform Snowy',   'Gelo'),
    ]),
    _FormSection('Deoxys (4 formas)', [
      _FormEntry(386, 'Deoxys Normal',   'Psíquico'),
      _FormEntry(386, 'Deoxys Attack',   'Psíquico', spriteKey: '386_ATTACK'),
      _FormEntry(386, 'Deoxys Defense',  'Psíquico', spriteKey: '386_DEFENSE'),
      _FormEntry(386, 'Deoxys Speed',    'Psíquico', spriteKey: '386_SPEED'),
    ]),
    _FormSection('Rotom (6 formas)', [
      _FormEntry(479, 'Rotom Normal',  'Elétrico / Fantasma'),
      _FormEntry(479, 'Rotom Heat',    'Elétrico / Fogo',    spriteKey: '479_HEAT'),
      _FormEntry(479, 'Rotom Wash',    'Elétrico / Água',    spriteKey: '479_WASH'),
      _FormEntry(479, 'Rotom Frost',   'Elétrico / Gelo',    spriteKey: '479_FROST'),
      _FormEntry(479, 'Rotom Fan',     'Elétrico / Voador',  spriteKey: '479_FAN'),
      _FormEntry(479, 'Rotom Mow',     'Elétrico / Planta',  spriteKey: '479_MOW'),
    ]),
    _FormSection('Giratina (2 formas)', [
      _FormEntry(487, 'Giratina Altered', 'Fantasma / Dragão'),
      _FormEntry(487, 'Giratina Origin',  'Fantasma / Dragão', spriteKey: '487_ORIGIN'),
    ]),
    _FormSection('Shaymin (2 formas)', [
      _FormEntry(492, 'Shaymin Land', 'Planta'),
      _FormEntry(492, 'Shaymin Sky',  'Planta / Voador', spriteKey: '492_SKY'),
    ]),
    _FormSection('Tornadus / Thundurus / Landorus (Therian)', [
      _FormEntry(641, 'Tornadus Incarnate', 'Voador'),
      _FormEntry(641, 'Tornadus Therian',   'Voador',              spriteKey: '641_THERIAN'),
      _FormEntry(642, 'Thundurus Incarnate','Elétrico / Voador'),
      _FormEntry(642, 'Thundurus Therian',  'Elétrico / Voador',   spriteKey: '642_THERIAN'),
      _FormEntry(645, 'Landorus Incarnate', 'Terra / Voador'),
      _FormEntry(645, 'Landorus Therian',   'Terra / Voador',      spriteKey: '645_THERIAN'),
    ]),
    _FormSection('Kyurem (3 formas)', [
      _FormEntry(646, 'Kyurem Normal', 'Dragão / Gelo'),
      _FormEntry(646, 'Kyurem Black',  'Dragão / Gelo', spriteKey: '646_BLACK'),
      _FormEntry(646, 'Kyurem White',  'Dragão / Gelo', spriteKey: '646_WHITE'),
    ]),
    _FormSection('Zygarde (3 formas)', [
      _FormEntry(718, 'Zygarde 10%',      'Dragão / Terra', spriteKey: '718_10'),
      _FormEntry(718, 'Zygarde 50%',      'Dragão / Terra'),
      _FormEntry(718, 'Zygarde Complete', 'Dragão / Terra', spriteKey: '718_COMPLETE'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _sections.map((s) =>
          _FormSectionWidget(section: s, scheme: scheme, onTap: onTap)).toList(),
    );
  }
}

// ─── Widgets compartilhados ───────────────────────────────────────

class _FormSectionWidget extends StatelessWidget {
  final _FormSection section;
  final ColorScheme  scheme;
  final Future<void> Function(BuildContext, _FormEntry) onTap;
  const _FormSectionWidget({required this.section, required this.scheme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(section.title, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant)),
      ),
      ...section.forms.map((f) => _FormTile(form: f, scheme: scheme, onTap: onTap)),
      const SizedBox(height: 16),
    ]);
  }
}

class _FormTile extends StatefulWidget {
  final _FormEntry  form;
  final ColorScheme scheme;
  final Future<void> Function(BuildContext, _FormEntry) onTap;
  const _FormTile({required this.form, required this.scheme, required this.onTap});
  @override
  State<_FormTile> createState() => _FormTileState();
}

class _FormTileState extends State<_FormTile> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final spritePath = widget.form.spriteKey != null
        ? 'assets/sprites/artwork/${widget.form.spriteKey}.webp'
        : 'assets/sprites/artwork/${widget.form.id}.webp';

    return GestureDetector(
      onTap: _loading ? null : () async {
        setState(() => _loading = true);
        await widget.onTap(context, widget.form);
        if (mounted) setState(() => _loading = false);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: widget.scheme.outlineVariant, width: 0.5),
        ),
        child: Row(children: [
          _loading
              ? SizedBox(width: 40, height: 40,
                  child: Center(child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2,
                      color: widget.scheme.primary))))
              : Image.asset(
                  spritePath,
                  width: 40, height: 40, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/sprites/artwork/${widget.form.id}.webp',
                    width: 40, height: 40, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => SizedBox(width: 40, height: 40,
                      child: Icon(Icons.catching_pokemon, size: 24,
                          color: widget.scheme.onSurfaceVariant.withOpacity(0.4))),
                  ),
                ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.form.name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(widget.form.types,
                style: TextStyle(fontSize: 11, color: widget.scheme.onSurfaceVariant)),
          ])),
          Icon(Icons.chevron_right,
              size: 16, color: widget.scheme.onSurfaceVariant.withOpacity(0.4)),
        ]),
      ),
    );
  }
}

// ─── Modelos ──────────────────────────────────────────────────────

class _FormSection {
  final String           title;
  final List<_FormEntry> forms;
  const _FormSection(this.title, this.forms);
}

class _FormEntry {
  final int     id;
  final String  name;
  final String  types;
  final String? spriteKey; // null = usar sprite base do ID
  const _FormEntry(this.id, this.name, this.types, {this.spriteKey});
}

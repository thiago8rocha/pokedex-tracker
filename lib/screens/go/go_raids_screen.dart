import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart'
    show PokeballLoader, ptType, defaultSpriteNotifier;
import 'package:pokedex_tracker/screens/go/go_detail_screen.dart';
import 'package:pokedex_tracker/services/pokeapi_service.dart';
import 'package:pokedex_tracker/services/pokedex_data_service.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/theme/type_colors.dart';

// PENDÊNCIA — Créditos/Fontes (registrado em 6.4 do doc de projeto):
// - Raids Ativas: dados via scraping de leekduck.com/raid-bosses/
//   Quando a tela de Créditos for implementada, incluir LeekDuck como fonte.

// ─── Mapa EN → chave lowercase para assets/types/ ─────────────────
const _typeKeyMap = {
  'Normal':'normal','Fire':'fire','Water':'water','Electric':'electric',
  'Grass':'grass','Ice':'ice','Fighting':'fighting','Poison':'poison',
  'Ground':'ground','Flying':'flying','Psychic':'psychic','Bug':'bug',
  'Rock':'rock','Ghost':'ghost','Dragon':'dragon','Dark':'dark',
  'Steel':'steel','Fairy':'fairy',
};

// ─── Sprites de formas alternativas (regionais / mega) ────────────
// Chave: (id_base, FORMA) onde FORMA é extraída da URL pm618.fGALARIAN.icon.png
// Valor: URL do artwork oficial via PokeAPI sprites repo
const _formaSprites = <String, String>{
  // Regionais
  '618_GALARIAN': 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10172.png',
  '105_ALOLA':    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10104.png',
  '52_ALOLA':     'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10101.png',
  '52_GALARIAN':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10161.png',
  '83_GALARIAN':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10162.png',
  '199_GALARIAN': 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10182.png',
  '27_ALOLA':     'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10091.png',
  '77_GALARIAN':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10159.png',
  // Megas comuns em raids do GO
  '3_MEGA':    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10033.png',
  '6_MEGAX':   'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10034.png',
  '6_MEGAY':   'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10035.png',
  '9_MEGA':    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10036.png',
  '15_MEGA':   'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10041.png',
  '18_MEGA':   'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10068.png',
  '65_MEGA':   'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10043.png',
  '80_MEGA':   'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10026.png',
  '94_MEGA':   'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10044.png',
  '115_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10045.png',
  '127_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10046.png',
  '130_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10047.png',
  '142_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10048.png',
  '181_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10055.png',
  '208_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10056.png',
  '212_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10057.png',
  '214_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10058.png',
  '229_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10051.png',
  '248_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10060.png',
  '254_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10061.png',
  '257_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10062.png',
  '260_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10063.png',
  '282_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10065.png',
  '302_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10067.png',
  '303_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10066.png',
  '306_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10069.png',
  '308_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10070.png',
  '310_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10071.png',
  '319_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10072.png',
  '323_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10073.png',
  '334_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10074.png',
  '354_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10075.png',
  '359_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10076.png',
  '362_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10077.png',
  '373_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10089.png',
  '376_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10078.png',
  '380_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10079.png',
  '381_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10080.png',
  '384_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10090.png',
  '428_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10085.png',
  '445_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10088.png',
  '448_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10087.png',
  '460_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10086.png',
  // Primal
  '382_PRIMAL': 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10252.png',
  '383_PRIMAL': 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10253.png',
};

// ─── Shiny disponível no GO (base estática, mar/2026) ─────────────
const Set<int> _goShinyAvailable = {
  246, 345, 618, 744,   // 1★
  68, 450, 962,         // 3★
  894,                  // 5★
  229,                  // Mega
  380, 147, 131,        // Shadow
};

class GoRaidsScreen extends StatefulWidget {
  const GoRaidsScreen({super.key});
  @override
  State<GoRaidsScreen> createState() => _GoRaidsScreenState();
}

class _GoRaidsScreenState extends State<GoRaidsScreen> {
  List<_RaidBoss>  _raids  = [];
  List<_EventInfo> _events = [];
  bool    _loading = true;
  String? _error;

  final _api     = PokeApiService();
  final _storage = StorageService();
  final Map<int, Map<String, dynamic>?> _statsCache = {};

  @override
  void initState() { super.initState(); _loadRaids(); }

  Future<void> _loadRaids() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(
        Uri.parse('https://leekduck.com/raid-bosses/'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Android 14; Mobile) AppleWebKit/537.36',
          'Accept': 'text/html',
        },
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final html   = res.body;
      final raids  = _parseRaids(html);
      final events = _parseEvents(html);

      if (raids.isEmpty) throw Exception('Sem dados');
      if (mounted) setState(() {
        _raids   = raids;
        _events  = events;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error   = 'Não foi possível carregar as raids';
        _loading = false;
      });
    }
  }

  // ── Parser de raids ────────────────────────────────────────────
  // Estrutura real do LeekDuck verificada em mar/2026:
  //   <h2>1-Star Raids</h2>
  //   <img src="...pm246.icon.png">
  //   Larvitar
  //   <img src="...rock.png" title="Rock">Rock
  //   CP 548 – 594          ← LeekDuck usa en-dash (–)
  //   CP 686 – 743
  List<_RaidBoss> _parseRaids(String html) {
    final raids   = <_RaidBoss>[];
    final tierMap = {
      '1-Star Raids': 1, '3-Star Raids': 3,
      '5-Star Raids': 5, 'Mega Raids':   6,
    };

    final h2Rx = RegExp(
      r'<h2[^>]*>([\s\S]*?)<\/h2>([\s\S]*?)(?=<h2|$)',
      caseSensitive: false,
    );

    bool inShadow = false;

    for (final m in h2Rx.allMatches(html)) {
      final header  = _strip(m.group(1) ?? '').trim();
      final content = m.group(2) ?? '';

      if (header.toLowerCase().contains('shadow raid')) {
        inShadow = true;
        continue;
      }

      int? tier;
      for (final e in tierMap.entries) {
        if (header.contains(e.key)) { tier = e.value; break; }
      }
      if (tier == null) continue;

      final bossRx = RegExp(
        r'<img[^>]+src="([^"]*(?:pm\d|poke_capture)[^"]*)"[^>]*>'
        r'([\s\S]*?)(?=<img[^>]+src="[^"]*(?:pm\d|poke_capture)[^"]*"|$)',
        caseSensitive: false,
      );

      for (final bm in bossRx.allMatches(content)) {
        final imgSrc = bm.group(1) ?? '';
        final chunk  = bm.group(2) ?? '';

        // ── ID: da URL da imagem ───────────────────────────────
        final pmId   = RegExp(r'pm(\d+)\.').firstMatch(imgSrc);
        final pokeId = RegExp(r'poke_capture_(\d+)').firstMatch(imgSrc);
        final id     = int.tryParse(
            pmId?.group(1) ?? pokeId?.group(1) ?? '0') ?? 0;
        if (id == 0) continue;

        // ── Forma: extraída da URL para lookup de sprite ───────
        // ex: pm618.fGALARIAN.icon.png -> "GALARIAN"
        final formaMatch = RegExp(r'\.f([A-Z_]+)\.icon', caseSensitive: false)
            .firstMatch(imgSrc);
        final formaTag = formaMatch?.group(1)?.toUpperCase();

        final isMega     = formaTag == 'MEGA' || formaTag == 'MEGAS'
            || (formaTag?.startsWith('MEGA') ?? false);
        final isRegional = formaTag != null && !isMega
            && (formaTag == 'ALOLA' || formaTag == 'GALARIAN'
            || formaTag == 'HISUI' || formaTag == 'PALDEA');

        // ── Sprite alternativo para formas ─────────────────────
        final formaKey  = formaTag != null ? '${id}_$formaTag' : null;
        final altSprite = formaKey != null ? _formaSprites[formaKey] : null;

        // ── Nome: texto antes da primeira <img ─────────────────
        final beforeImg = chunk.split('<img')[0];
        var rawName = _strip(beforeImg).trim();
        // Remove "Shadow " E "Mega " do início — displayName os recoloca
        final baseName = rawName
            .replaceFirst(RegExp(r'^(Shadow|Mega)\s+', caseSensitive: false), '')
            .trim();
        if (baseName.isEmpty) continue;

        // ── Tipos: do atributo title="Rock" ────────────────────
        final types = RegExp(r'title="([A-Za-z]+)"')
            .allMatches(chunk)
            .map((t) => _typeKeyMap[t.group(1)] ?? '')
            .where((t) => t.isNotEmpty)
            .toList();

        // ── CP: LeekDuck usa en-dash (–) entre os valores ──────
        // Aceita hífen (-), en-dash (–) e entidade HTML (&ndash;)
        final cpMatches = RegExp(
          r'CP\s*([\d,]+)\s*(?:-|–|&ndash;)\s*([\d,]+)',
        ).allMatches(chunk).toList();
        final minCp      = cpMatches.isNotEmpty
            ? int.tryParse(cpMatches[0].group(1)!.replaceAll(',', '')) ?? 0 : 0;
        final maxCp      = cpMatches.isNotEmpty
            ? int.tryParse(cpMatches[0].group(2)!.replaceAll(',', '')) ?? 0 : 0;
        final minCpBoost = cpMatches.length > 1
            ? int.tryParse(cpMatches[1].group(1)!.replaceAll(',', '')) ?? 0 : 0;
        final maxCpBoost = cpMatches.length > 1
            ? int.tryParse(cpMatches[1].group(2)!.replaceAll(',', '')) ?? 0 : 0;

        // ── Shiny ──────────────────────────────────────────────
        final hasShiny = chunk.toLowerCase().contains('shiny')
            || chunk.contains('icon-shiny')
            || _goShinyAvailable.contains(id);

        raids.add(_RaidBoss(
          id: id, name: baseName, tier: tier,
          isShadow: inShadow, isMega: isMega, isRegional: isRegional,
          altSprite: altSprite,
          types: types,
          minCp: minCp, maxCp: maxCp,
          minCpBoost: minCpBoost, maxCpBoost: maxCpBoost,
          shinyAvailable: hasShiny,
        ));
      }
    }
    return raids;
  }

  // ── Parser de eventos ──────────────────────────────────────────
  // Estrutura real: "Selected Event" e "Ongoing" são texto puro no HTML
  // mas dentro de spans com classes CSS — strip resolve
  List<_EventInfo> _parseEvents(String html) {
    final events = <_EventInfo>[];

    // Strip completo do HTML antes de aplicar regex de texto
    final stripped = html.replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ');

    final eventRx = RegExp(
      r'Selected Event\s+Ongoing\s+([\s\S]*?)(?=Selected Event|\Z)',
      caseSensitive: false,
    );
    final endsRx   = RegExp(r'Ends?:\s*([A-Za-z]+\s+\d{1,2},?\s*\d{4}[^\n]*)', caseSensitive: false);
    final startsRx = RegExp(r'Starts?:\s*([A-Za-z]+\s+\d{1,2},?\s*\d{4}[^\n]*)', caseSensitive: false);

    for (final m in eventRx.allMatches(stripped)) {
      final block = m.group(1) ?? '';
      final lines = block.split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;

      // Primeira linha é o nome do evento
      final name = lines[0];
      if (name.length < 4) continue;

      final start = startsRx.firstMatch(block)?.group(1)?.trim();
      final end   = endsRx.firstMatch(block)?.group(1)?.trim();

      events.add(_EventInfo(name: name, start: start, end: end));
      if (events.length >= 2) break;
    }
    return events;
  }

  String _strip(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '').trim();

  // ── Navegação para detalhe ─────────────────────────────────────
  Future<void> _openDetail(BuildContext ctx, _RaidBoss boss) async {
    final bundleTypes = PokedexDataService.instance.getTypes(boss.id);
    final types = boss.types.isNotEmpty ? boss.types : bundleTypes;

    if (!_statsCache.containsKey(boss.id)) {
      final apiData = await _api.fetchPokemon(boss.id)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      _statsCache[boss.id] = apiData;
    }
    final apiData = _statsCache[boss.id];

    int statVal(String name) {
      final rawStats = apiData?['stats'] as List<dynamic>?;
      if (rawStats == null) return 0;
      final s = rawStats.firstWhere(
        (s) => s['stat']['name'] == name,
        orElse: () => null,
      );
      return (s?['base_stat'] as int?) ?? 0;
    }

    final spriteType = defaultSpriteNotifier.value;
    String spriteAsset(String t) {
      switch (t) {
        case 'pixel':   return 'assets/sprites/pixel/${boss.id}.webp';
        case 'home':    return 'assets/sprites/home/${boss.id}.webp';
        default:        return 'assets/sprites/artwork/${boss.id}.webp';
      }
    }
    const base = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';

    // Para detalhe, usar artwork da forma quando disponível
    final detailSprite = boss.altSprite ?? spriteAsset(spriteType);

    final pokemon = Pokemon(
      id:                  boss.id,
      entryNumber:         boss.id,
      name:                boss.name,
      types:               types.isNotEmpty ? types : ['normal'],
      baseHp:              statVal('hp'),
      baseAttack:          statVal('attack'),
      baseDefense:         statVal('defense'),
      baseSpAttack:        statVal('special-attack'),
      baseSpDefense:       statVal('special-defense'),
      baseSpeed:           statVal('speed'),
      spriteUrl:           detailSprite,
      spriteShinyUrl:      '$base/other/official-artwork/shiny/${boss.id}.png',
      spritePixelUrl:      spriteAsset('pixel'),
      spritePixelShinyUrl: '$base/shiny/${boss.id}.png',
      spritePixelFemaleUrl: null,
      spriteHomeUrl:       spriteAsset('home'),
      spriteHomeShinyUrl:  '$base/other/home/shiny/${boss.id}.png',
      spriteHomeFemaleUrl: null,
    );

    if (!ctx.mounted) return;
    bool caught = await _storage.isCaught('pokémon_go', boss.id);
    if (!ctx.mounted) return;

    Navigator.push(
      ctx,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => GoDetailScreen(
          pokemon: pokemon,
          caught: caught,
          onToggleCaught: () async {
            caught = !caught;
            await _storage.setCaught('pokémon_go', boss.id, caught);
          },
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 180),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raids Ativas'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loadRaids,
          ),
        ],
      ),
      body: _loading
          ? Center(child: PokeballLoader())
          : _raids.isEmpty
              ? _EmptyState(
                  message: _error ?? 'Nenhum raid ativo no momento',
                  onRetry: _loadRaids,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    if (_events.isNotEmpty) ...[
                      ..._events.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _EventBanner(event: e),
                      )),
                      const SizedBox(height: 8),
                    ],
                    ..._buildSections(),
                  ],
                ),
    );
  }

  List<Widget> _buildSections() {
    final widgets = <Widget>[];

    bool normalAdded = false;
    for (final tier in [1, 3, 5, 6]) {
      final list = _raids.where((r) => r.tier == tier && !r.isShadow).toList();
      if (list.isEmpty) continue;
      if (!normalAdded) {
        widgets.add(_SectionDivider(label: 'RAIDS', color: const Color(0xFF1565C0)));
        widgets.add(const SizedBox(height: 12));
        normalAdded = true;
      }
      widgets.add(_TierHeader(tier: tier, isShadow: false));
      widgets.add(const SizedBox(height: 10));
      widgets.add(_RaidGrid(bosses: list, onTap: _openDetail));
      widgets.add(const SizedBox(height: 20));
    }

    bool shadowAdded = false;
    for (final tier in [1, 3, 5, 6]) {
      final list = _raids.where((r) => r.tier == tier && r.isShadow).toList();
      if (list.isEmpty) continue;
      if (!shadowAdded) {
        widgets.add(_SectionDivider(label: 'SHADOW RAIDS', color: const Color(0xFF6A1FAB)));
        widgets.add(const SizedBox(height: 12));
        shadowAdded = true;
      }
      widgets.add(_TierHeader(tier: tier, isShadow: true));
      widgets.add(const SizedBox(height: 10));
      widgets.add(_RaidGrid(bosses: list, onTap: _openDetail));
      widgets.add(const SizedBox(height: 20));
    }

    return widgets;
  }
}

// ─── Modelos ──────────────────────────────────────────────────────

class _RaidBoss {
  final int      id;
  final String   name;
  final int      tier;
  final bool     isShadow;
  final bool     isMega;
  final bool     isRegional;
  final String?  altSprite;      // URL do sprite da forma (regional/mega)
  final List<String> types;      // chaves lowercase: 'fire', 'rock', etc.
  final int      minCp;
  final int      maxCp;
  final int      minCpBoost;
  final int      maxCpBoost;
  final bool     shinyAvailable;

  const _RaidBoss({
    required this.id, required this.name, required this.tier,
    required this.isShadow, required this.isMega, required this.isRegional,
    this.altSprite,
    required this.types,
    required this.minCp, required this.maxCp,
    required this.minCpBoost, required this.maxCpBoost,
    required this.shinyAvailable,
  });

  String get displayName {
    var n = name;
    if (isMega)   n = 'Mega $n';
    if (isShadow) n = 'Shadow $n';
    return n;
  }
}

class _EventInfo {
  final String  name;
  final String? start;
  final String? end;
  const _EventInfo({required this.name, this.start, this.end});
}

// ─── Banner do evento ─────────────────────────────────────────────

class _EventBanner extends StatelessWidget {
  final _EventInfo event;
  const _EventBanner({required this.event});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(event.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        if (event.start != null || event.end != null) ...[
          const SizedBox(height: 4),
          Wrap(children: [
            if (event.start != null)
              Text('Início: ${event.start}  ',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            if (event.end != null)
              Text('Fim: ${event.end}',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ]),
        ],
      ]),
    );
  }
}

// ─── Divisor de seção ─────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  final String label;
  final Color  color;
  const _SectionDivider({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Divider(color: color.withOpacity(0.3), thickness: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800,
            letterSpacing: 1.2, color: color)),
      ),
      Expanded(child: Divider(color: color.withOpacity(0.3), thickness: 1)),
    ]);
  }
}

// ─── Header de tier ───────────────────────────────────────────────

class _TierHeader extends StatelessWidget {
  final int tier;
  final bool isShadow;
  const _TierHeader({required this.tier, required this.isShadow});

  static const _meta = {
    6: ('Mega / Primal', Color(0xFF9C27B0)),
    5: ('5 Estrelas',    Color(0xFFE65100)),
    3: ('3 Estrelas',    Color(0xFF2E7D32)),
    1: ('1 Estrela',     Color(0xFF546E7A)),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _meta[tier] ?? ('Raid', const Color(0xFF888888));
    final c = isShadow ? const Color(0xFF6A1FAB) : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

// ─── Grid de pokémon ──────────────────────────────────────────────

class _RaidGrid extends StatelessWidget {
  final List<_RaidBoss> bosses;
  final Future<void> Function(BuildContext, _RaidBoss) onTap;
  const _RaidGrid({required this.bosses, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   3,
        crossAxisSpacing: 8,
        mainAxisSpacing:  8,
        childAspectRatio: 0.72,
      ),
      itemCount: bosses.length,
      itemBuilder: (ctx, i) => _RaidCard(boss: bosses[i], onTap: onTap),
    );
  }
}

// ─── Card de pokémon ──────────────────────────────────────────────

class _RaidCard extends StatefulWidget {
  final _RaidBoss boss;
  final Future<void> Function(BuildContext, _RaidBoss) onTap;
  const _RaidCard({required this.boss, required this.onTap});

  @override
  State<_RaidCard> createState() => _RaidCardState();
}

class _RaidCardState extends State<_RaidCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final boss   = widget.boss;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bundleTypes = PokedexDataService.instance.getTypes(boss.id);
    final displayTypes = boss.types.isNotEmpty ? boss.types : bundleTypes;

    final color1 = displayTypes.isNotEmpty
        ? TypeColors.fromType(ptType(displayTypes[0])) : scheme.primary;
    final color2 = displayTypes.length > 1
        ? TypeColors.fromType(ptType(displayTypes[1])) : color1;
    final bgOp = isDark ? 0.15 : 0.10;

    return GestureDetector(
      onTap: _loading ? null : () async {
        setState(() => _loading = true);
        await widget.onTap(context, boss);
        if (mounted) setState(() => _loading = false);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: displayTypes.length > 1
                ? [color1.withOpacity(bgOp), color2.withOpacity(bgOp)]
                : [color1.withOpacity(bgOp), color1.withOpacity(bgOp * 0.5)],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color1.withOpacity(0.3)),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Sprite — usa altSprite (rede) para formas, bundle para base
                  SizedBox(
                    height: 64,
                    width: double.infinity,
                    child: _loading
                        ? Center(
                            child: SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: color1),
                            ),
                          )
                        : boss.altSprite != null
                            ? Image.network(
                                boss.altSprite!,
                                width: 64, height: 64, fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/sprites/artwork/${boss.id}.webp',
                                  width: 64, height: 64, fit: BoxFit.contain,
                                ),
                              )
                            : Image.asset(
                                'assets/sprites/artwork/${boss.id}.webp',
                                width: 64, height: 64, fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.catching_pokemon,
                                  color: scheme.onSurfaceVariant.withOpacity(0.4),
                                  size: 36),
                              ),
                  ),

                  const SizedBox(height: 4),

                  // Nome
                  Text(
                    boss.displayName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, height: 1.2),
                  ),

                  const SizedBox(height: 4),

                  // Tipos — linha única, tamanho fixo para consistência
                  if (displayTypes.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: displayTypes.map((t) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _TypeBadge(type: t),
                      )).toList(),
                    ),

                  const SizedBox(height: 4),

                  // CP unboosted
                  if (boss.minCp > 0) ...[
                    Text(
                      'CP ${boss.minCp}–${boss.maxCp}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface),
                    ),
                    // CP boosted
                    if (boss.minCpBoost > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wb_sunny_outlined,
                              size: 9, color: Color(0xFFF9A825)),
                          const SizedBox(width: 2),
                          Text(
                            '${boss.minCpBoost}–${boss.maxCpBoost}',
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFF9A825)),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),

            // Ícone shiny — discreto, sem caixa, canto superior direito
            if (boss.shinyAvailable)
              const Positioned(
                top: 5, right: 5,
                child: Icon(Icons.auto_awesome,
                    size: 12, color: Color(0xFFFFC107)),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Badge de tipo com ícone PNG — largura fixa para consistência ──

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  static const _names = {
    'normal':   'Normal',   'fire':     'Fogo',    'water':    'Água',
    'electric': 'Elétrico', 'grass':    'Planta',  'ice':      'Gelo',
    'fighting': 'Lutador',  'poison':   'Veneno',  'ground':   'Terreno',
    'flying':   'Voador',   'psychic':  'Psíquico','bug':      'Inseto',
    'rock':     'Pedra',    'ghost':    'Fantasma','dragon':   'Dragão',
    'dark':     'Sombrio',  'steel':    'Aço',     'fairy':    'Fada',
  };

  @override
  Widget build(BuildContext context) {
    final color = TypeColors.fromType(ptType(type));
    final label = _names[type] ?? type;
    return Container(
      height: 18,                        // altura fixa em todos os badges
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/types/$type.png',
            width: 10, height: 10,
            errorBuilder: (_, __, ___) =>
                const SizedBox(width: 10, height: 10),
          ),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w600,
                  color: Colors.white, height: 1.0)),
        ],
      ),
    );
  }
}

// ─── Estado vazio ─────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _EmptyState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined,
                size: 64,
                color: Theme.of(context)
                    .colorScheme.onSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6))),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dexcurator/models/pokemon.dart';
import 'package:dexcurator/screens/detail/detail_shared.dart'
    show PokeballLoader, ptType, defaultSpriteNotifier;
import 'package:dexcurator/screens/go/go_detail_screen.dart';
import 'package:dexcurator/services/pokeapi_service.dart';
import 'package:dexcurator/services/pokedex_data_service.dart';
import 'package:dexcurator/services/storage_service.dart';
import 'package:dexcurator/core/app_constants.dart';
import 'package:dexcurator/theme/type_colors.dart';

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

// ─── Mapa forma → nome de arquivo no bundle ────────────────────────
// Chave: "{species_id}_{FORMA_TAG}" (ex: "618_GALARIAN")
// Valor: nome do arquivo sem extensão dentro de assets/sprites/*/
//
// Os arquivos são gerados pelo script download_form_sprites.py na raiz
// do projeto. O padrão de nomeação complementa o bundle base (1–1025.webp).
const _formaAsset = <String, String>{
  // Regionais
  '618_GALARIAN': '618_GALARIAN',
  '105_ALOLA':    '105_ALOLA',
  '52_ALOLA':     '52_ALOLA',
  '52_GALARIAN':  '52_GALARIAN',
  '83_GALARIAN':  '83_GALARIAN',
  '77_GALARIAN':  '77_GALARIAN',
  '199_GALARIAN': '199_GALARIAN',
  '27_ALOLA':     '27_ALOLA',
  '37_ALOLA':     '37_ALOLA',
  '50_ALOLA':     '50_ALOLA',
  '74_ALOLA':     '74_ALOLA',
  '88_ALOLA':     '88_ALOLA',
  '144_GALARIAN': '144_GALARIAN',
  '145_GALARIAN': '145_GALARIAN',
  '146_GALARIAN': '146_GALARIAN',
  // Megas
  '3_MEGA':    '3_MEGA',   '6_MEGAX':  '6_MEGAX',  '6_MEGAY':  '6_MEGAY',
  '9_MEGA':    '9_MEGA',   '15_MEGA':  '15_MEGA',  '18_MEGA':  '18_MEGA',
  '65_MEGA':   '65_MEGA',  '80_MEGA':  '80_MEGA',  '94_MEGA':  '94_MEGA',
  '115_MEGA':  '115_MEGA', '127_MEGA': '127_MEGA', '130_MEGA': '130_MEGA',
  '142_MEGA':  '142_MEGA', '181_MEGA': '181_MEGA', '208_MEGA': '208_MEGA',
  '212_MEGA':  '212_MEGA', '214_MEGA': '214_MEGA', '229_MEGA': '229_MEGA',
  '248_MEGA':  '248_MEGA', '254_MEGA': '254_MEGA', '257_MEGA': '257_MEGA',
  '260_MEGA':  '260_MEGA', '282_MEGA': '282_MEGA', '302_MEGA': '302_MEGA',
  '303_MEGA':  '303_MEGA', '306_MEGA': '306_MEGA', '308_MEGA': '308_MEGA',
  '310_MEGA':  '310_MEGA', '319_MEGA': '319_MEGA', '323_MEGA': '323_MEGA',
  '334_MEGA':  '334_MEGA', '354_MEGA': '354_MEGA', '359_MEGA': '359_MEGA',
  '362_MEGA':  '362_MEGA', '373_MEGA': '373_MEGA', '376_MEGA': '376_MEGA',
  '380_MEGA':  '380_MEGA', '381_MEGA': '381_MEGA', '384_MEGA': '384_MEGA',
  '428_MEGA':  '428_MEGA', '445_MEGA': '445_MEGA', '448_MEGA': '448_MEGA',
  '460_MEGA':  '460_MEGA',
  // Primals
  '382_PRIMAL': '382_PRIMAL',
  '383_PRIMAL': '383_PRIMAL',
};

// Retorna o asset path para um boss, incluindo formas do bundle.
String _spriteAsset(int id, String? formaKey, String spriteType) {
  final folder = switch (spriteType) {
    'pixel' => 'pixel',
    'home'  => 'home',
    _       => 'artwork',
  };
  final assetName = formaKey != null ? _formaAsset[formaKey] : null;
  final file      = assetName ?? '$id';
  return 'assets/sprites/$folder/$file.webp';
}

// ─── Shiny disponível no GO (base estática, mar/2026) ─────────────
const Set<int> _goShinyAvailable = {
  246, 345, 618, 744,
  68, 450, 962,
  894, 229,
  380, 147, 131,
};

class GoRaidsScreen extends StatefulWidget {
  const GoRaidsScreen({super.key});
  @override
  State<GoRaidsScreen> createState() => _GoRaidsScreenState();
}

class _GoRaidsScreenState extends State<GoRaidsScreen> {
  List<_RaidBoss> _raids       = [];
  _EventInfo?     _eventNormal;
  _EventInfo?     _eventShadow;
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
          'User-Agent': kUserAgent,
          'Accept': 'text/html',
        },
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final html  = res.body;
      final parts = html.split(RegExp(r'<h2[^>]*>Shadow Raids', caseSensitive: false));

      final raids       = _parseRaids(html);
      final eventNormal = _parseEvent(parts[0]);
      final eventShadow = parts.length > 1 ? _parseEvent(parts[1]) : null;

      if (raids.isEmpty) throw Exception('Sem dados');
      if (mounted) setState(() {
        _raids       = raids;
        _eventNormal = eventNormal;
        _eventShadow = eventShadow;
        _loading     = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error   = 'Não foi possível carregar as raids';
        _loading = false;
      });
    }
  }

  // ── Parser de raids ────────────────────────────────────────────
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

        final pmId   = RegExp(r'pm(\d+)\.').firstMatch(imgSrc);
        final pokeId = RegExp(r'poke_capture_(\d+)').firstMatch(imgSrc);
        final id     = int.tryParse(pmId?.group(1) ?? pokeId?.group(1) ?? '0') ?? 0;
        if (id == 0) continue;

        final formaMatch = RegExp(r'\.f([A-Za-z_]+)\.icon', caseSensitive: false)
            .firstMatch(imgSrc);
        final formaTag   = formaMatch?.group(1)?.toUpperCase();
        final isMega     = formaTag != null && formaTag.startsWith('MEGA');
        final isRegional = formaTag != null && !isMega;
        final formaKey   = formaTag != null ? '${id}_$formaTag' : null;

        final rawName  = _strip(chunk.split('<img')[0]).trim();
        final baseName = rawName
            .replaceFirst(RegExp(r'^(Shadow|Mega)\s+', caseSensitive: false), '')
            .trim();
        if (baseName.isEmpty) continue;

        final types = RegExp(r'title="([A-Za-z]+)"')
            .allMatches(chunk)
            .map((t) => _typeKeyMap[t.group(1)] ?? '')
            .where((t) => t.isNotEmpty)
            .toList();

        final hasShiny = chunk.toLowerCase().contains('shiny')
            || _goShinyAvailable.contains(id);

        raids.add(_RaidBoss(
          id: id, name: baseName, tier: tier,
          isShadow: inShadow, isMega: isMega, isRegional: isRegional,
          formaKey: formaKey,
          types: types, shinyAvailable: hasShiny,
        ));
      }
    }
    return raids;
  }

  // ── Parser de evento — retorna só o nome ──────────────────────
  _EventInfo? _parseEvent(String html) {
    final stripped = html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ');

    final m = RegExp(
      r'Selected Event\s+Ongoing\s+([\s\S]*?)(?=Selected Event|##|\Z)',
      caseSensitive: false,
    ).firstMatch(stripped);
    if (m == null) return null;

    final lines = (m.group(1) ?? '')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty
            && !RegExp(r'^Starts?:', caseSensitive: false).hasMatch(l)
            && !RegExp(r'^Ends?:', caseSensitive: false).hasMatch(l))
        .toList();

    final name = lines.isNotEmpty ? lines[0] : null;
    if (name == null || name.length < 4) return null;
    return _EventInfo(name: name);
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
          (s) => s['stat']['name'] == name, orElse: () => null);
      return (s?['base_stat'] as int?) ?? 0;
    }

    // Sprite exclusivamente do bundle — mesma lógica do card
    final spriteType = defaultSpriteNotifier.value;
    final mainSprite  = _spriteAsset(boss.id, boss.formaKey, spriteType);
    final pixelSprite = _spriteAsset(boss.id, boss.formaKey, 'pixel');
    final artworkFallback = _spriteAsset(boss.id, boss.formaKey, 'artwork');

    const base = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';

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
      spriteUrl:           mainSprite,
      spriteShinyUrl:      '$base/other/official-artwork/shiny/${boss.id}.png',
      spritePixelUrl:      pixelSprite,
      spritePixelShinyUrl: '$base/shiny/${boss.id}.png',
      spritePixelFemaleUrl: null,
      spriteHomeUrl:       artworkFallback,
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
          // Regionais já são a forma — sem aba Formas
          hideFormsTab: boss.isRegional,
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
                  children: _buildBody(),
                ),
    );
  }

  List<Widget> _buildBody() {
    final widgets = <Widget>[];

    if (_eventNormal != null) {
      widgets.add(_EventBanner(event: _eventNormal!));
      widgets.add(const SizedBox(height: 12));
    }

    if (_raids.any((r) => !r.isShadow)) {
      widgets.add(_SectionDivider(label: 'RAIDS', color: const Color(0xFF1565C0)));
      widgets.add(const SizedBox(height: 12));
      for (final tier in [1, 3, 5, 6]) {
        final list = _raids.where((r) => r.tier == tier && !r.isShadow).toList();
        if (list.isEmpty) continue;
        widgets.add(_TierHeader(tier: tier, isShadow: false));
        widgets.add(const SizedBox(height: 10));
        widgets.add(_RaidGrid(bosses: list, onTap: _openDetail));
        widgets.add(const SizedBox(height: 16));
      }
    }

    if (_raids.any((r) => r.isShadow)) {
      widgets.add(_SectionDivider(label: 'SHADOW RAIDS', color: const Color(0xFF6A1FAB)));
      widgets.add(const SizedBox(height: 12));
      for (final tier in [1, 3, 5, 6]) {
        final list = _raids.where((r) => r.tier == tier && r.isShadow).toList();
        if (list.isEmpty) continue;
        widgets.add(_TierHeader(tier: tier, isShadow: true));
        widgets.add(const SizedBox(height: 10));
        widgets.add(_RaidGrid(bosses: list, onTap: _openDetail));
        widgets.add(const SizedBox(height: 16));
      }
    }

    return widgets;
  }
}

// ─── Modelos ──────────────────────────────────────────────────────

class _RaidBoss {
  final int          id;
  final String       name;
  final int          tier;
  final bool         isShadow;
  final bool         isMega;
  final bool         isRegional;
  final String?      formaKey;   // ex: "618_GALARIAN", null para pokémon base
  final List<String> types;
  final bool         shinyAvailable;

  const _RaidBoss({
    required this.id, required this.name, required this.tier,
    required this.isShadow, required this.isMega, required this.isRegional,
    this.formaKey,
    required this.types, required this.shinyAvailable,
  });

  // Mapa formaKey → nome PT — evita depender do nome EN do LeekDuck
  static const _regionalNames = {
    '26_ALOLA': 'Raichu de Alola', '27_ALOLA': 'Sandshrew de Alola',
    '28_ALOLA': 'Sandslash de Alola', '37_ALOLA': 'Vulpix de Alola',
    '38_ALOLA': 'Ninetales de Alola', '50_ALOLA': 'Diglett de Alola',
    '51_ALOLA': 'Dugtrio de Alola', '52_ALOLA': 'Meowth de Alola',
    '53_ALOLA': 'Persian de Alola', '74_ALOLA': 'Geodude de Alola',
    '75_ALOLA': 'Graveler de Alola', '76_ALOLA': 'Golem de Alola',
    '88_ALOLA': 'Grimer de Alola', '89_ALOLA': 'Muk de Alola',
    '103_ALOLA': 'Exeggutor de Alola', '105_ALOLA': 'Marowak de Alola',
    '52_GALARIAN': 'Meowth de Galar', '77_GALARIAN': 'Ponyta de Galar',
    '78_GALARIAN': 'Rapidash de Galar', '79_GALARIAN': 'Slowpoke de Galar',
    '80_GALARIAN': 'Slowbro de Galar', '83_GALARIAN': "Farfetch'd de Galar",
    '110_GALARIAN': 'Weezing de Galar', '122_GALARIAN': 'Mr. Mime de Galar',
    '144_GALARIAN': 'Articuno de Galar', '145_GALARIAN': 'Zapdos de Galar',
    '146_GALARIAN': 'Moltres de Galar', '199_GALARIAN': 'Slowking de Galar',
    '222_GALARIAN': 'Corsola de Galar', '263_GALARIAN': 'Zigzagoon de Galar',
    '264_GALARIAN': 'Linoone de Galar', '618_GALARIAN': 'Stunfisk de Galar',
    '58_HISUI': 'Growlithe de Hisui', '59_HISUI': 'Arcanine de Hisui',
    '100_HISUI': 'Voltorb de Hisui', '101_HISUI': 'Electrode de Hisui',
    '157_HISUI': 'Typhlosion de Hisui', '211_HISUI': 'Qwilfish de Hisui',
    '215_HISUI': 'Sneasel de Hisui', '503_HISUI': 'Samurott de Hisui',
    '549_HISUI': 'Lilligant de Hisui', '570_HISUI': 'Zorua de Hisui',
    '571_HISUI': 'Zoroark de Hisui', '628_HISUI': 'Braviary de Hisui',
    '705_HISUI': 'Sliggoo de Hisui', '706_HISUI': 'Goodra de Hisui',
    '724_HISUI': 'Decidueye de Hisui',
  };

  String get displayName {
    // Regional: usa nome PT do mapa, ignorando o nome EN do LeekDuck
    if (isRegional && formaKey != null) {
      final ptName = _regionalNames[formaKey!];
      if (ptName != null) return isShadow ? 'Shadow $ptName' : ptName;
    }
    var n = name;
    if (isMega)   n = 'Mega $n';
    if (isShadow) n = 'Shadow $n';
    return n;
  }
}

class _EventInfo {
  final String name;
  const _EventInfo({required this.name});
}

// ─── Banner de evento ─────────────────────────────────────────────

class _EventBanner extends StatelessWidget {
  final _EventInfo event;
  const _EventBanner({required this.event});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      child: Text(event.name,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
        mainAxisExtent:   170,
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
  bool _navigating = false;

  @override
  Widget build(BuildContext context) {
    final boss  = widget.boss;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bundleTypes  = PokedexDataService.instance.getTypes(boss.id);
    final displayTypes = boss.types.isNotEmpty ? boss.types : bundleTypes;

    final color1 = displayTypes.isNotEmpty
        ? TypeColors.fromType(ptType(displayTypes[0])) : scheme.primary;
    final color2 = displayTypes.length > 1
        ? TypeColors.fromType(ptType(displayTypes[1])) : color1;
    final bgOp = isDark ? 0.15 : 0.10;

    // Sprite sempre do bundle — sem rede
    final spriteType = defaultSpriteNotifier.value;
    final spritePath = _spriteAsset(boss.id, boss.formaKey, spriteType);

    return GestureDetector(
      onTap: _navigating ? null : () async {
        setState(() => _navigating = true);
        await widget.onTap(context, boss);
        if (mounted) setState(() => _navigating = false);
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
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Sprite — bundle local, sem spinner
                  SizedBox(
                    height: 64, width: double.infinity,
                    child: Image.asset(
                      spritePath,
                      width: 64, height: 64, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/sprites/artwork/${boss.id}.webp',
                        width: 64, height: 64, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.catching_pokemon,
                          color: scheme.onSurfaceVariant.withOpacity(0.4),
                          size: 36,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    boss.displayName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, height: 1.2),
                  ),

                  const SizedBox(height: 5),

                  // Tipos empilhados, largura mínima uniforme
                  if (displayTypes.isNotEmpty)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: displayTypes.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: _TypeBadge(type: t),
                      )).toList(),
                    ),
                ],
              ),
            ),

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

// ─── Badge de tipo com ícone PNG ──────────────────────────────────

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
      height: 18,
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
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
            Icon(Icons.event_busy_outlined, size: 64,
                color: Theme.of(context)
                    .colorScheme.onSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center,
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

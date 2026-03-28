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

// ─── Sprites PokeAPI para tela de detalhe (formas regionais/mega) ──
// Apenas para detail — o card usa a imgSrc do LeekDuck diretamente.
const _detailSprites = <String, String>{
  '618_GALARIAN': 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10172.png',
  '105_ALOLA':    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10104.png',
  '52_ALOLA':     'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10101.png',
  '52_GALARIAN':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10161.png',
  '83_GALARIAN':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10162.png',
  '77_GALARIAN':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10159.png',
  '3_MEGA':    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10033.png',
  '6_MEGAX':   'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10034.png',
  '6_MEGAY':   'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10035.png',
  '9_MEGA':    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10036.png',
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
  '257_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10062.png',
  '260_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10063.png',
  '282_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10065.png',
  '310_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10071.png',
  '319_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10072.png',
  '334_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10074.png',
  '354_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10075.png',
  '359_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10076.png',
  '362_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10077.png',
  '373_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10089.png',
  '376_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10078.png',
  '380_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10079.png',
  '381_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10080.png',
  '384_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10090.png',
  '445_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10088.png',
  '448_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10087.png',
  '460_MEGA':  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10086.png',
  '382_PRIMAL': 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10252.png',
  '383_PRIMAL': 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/10253.png',
};

// ─── Shiny disponível no GO (base estática, mar/2026) ─────────────
const Set<int> _goShinyAvailable = {
  246, 345, 618, 744,
  68, 450, 962,
  894,
  229,
  380, 147, 131,
};

class GoRaidsScreen extends StatefulWidget {
  const GoRaidsScreen({super.key});
  @override
  State<GoRaidsScreen> createState() => _GoRaidsScreenState();
}

class _GoRaidsScreenState extends State<GoRaidsScreen> {
  List<_RaidBoss>  _raids      = [];
  _EventInfo?      _eventNormal;
  _EventInfo?      _eventShadow;
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

      final html = res.body;

      // Dividir o HTML em bloco normal e bloco shadow
      // O evento normal fica antes de "## Shadow Raids"
      // O evento shadow fica dentro de "## Shadow Raids"
      final shadowSplit = html.split(RegExp(r'<h2[^>]*>Shadow Raids', caseSensitive: false));
      final normalHtml = shadowSplit[0];
      final shadowHtml = shadowSplit.length > 1 ? shadowSplit[1] : '';

      final raids       = _parseRaids(html);
      final eventNormal = _parseEvent(normalHtml);
      final eventShadow = _parseEvent(shadowHtml);

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
  // Estrutura real do LeekDuck (verificada em mar/2026):
  //   <img src="...pm246.icon.png">
  //   Larvitar
  //   <img src="...rock.png" title="Rock">Rock
  //   CP 548 - 594   ← hífen com espaços (não en-dash)
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
      final header  = _stripTags(m.group(1) ?? '').trim();
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

        // ID da URL da imagem
        final pmId   = RegExp(r'pm(\d+)\.').firstMatch(imgSrc);
        final pokeId = RegExp(r'poke_capture_(\d+)').firstMatch(imgSrc);
        final id     = int.tryParse(
            pmId?.group(1) ?? pokeId?.group(1) ?? '0') ?? 0;
        if (id == 0) continue;

        // Forma: "MEGA", "GALARIAN", "ALOLA", etc.
        final formaMatch = RegExp(r'\.f([A-Za-z_]+)\.icon', caseSensitive: false)
            .firstMatch(imgSrc);
        final formaTag = formaMatch?.group(1)?.toUpperCase();
        final isMega     = formaTag != null && formaTag.startsWith('MEGA');
        final isRegional = formaTag != null && !isMega;

        // Sprite do card: URL do LeekDuck diretamente (funciona, é de lá que veio)
        // Para formas usa imgSrc; para base usa o bundle local
        final cardSprite = (isMega || isRegional) ? imgSrc : null;

        // Sprite do detalhe: PokeAPI artwork quando disponível
        final formaKey    = formaTag != null ? '${id}_$formaTag' : null;
        final detailSprite = formaKey != null ? _detailSprites[formaKey] : null;

        // Nome: texto antes da primeira <img de tipo
        final beforeImg = chunk.split('<img')[0];
        final rawName   = _stripTags(beforeImg).trim();
        // Remove "Shadow " e "Mega " do início — displayName os recoloca
        final baseName  = rawName
            .replaceFirst(RegExp(r'^(Shadow|Mega)\s+', caseSensitive: false), '')
            .trim();
        if (baseName.isEmpty) continue;

        // Tipos: do atributo title="Rock"
        final types = RegExp(r'title="([A-Za-z]+)"')
            .allMatches(chunk)
            .map((t) => _typeKeyMap[t.group(1)] ?? '')
            .where((t) => t.isNotEmpty)
            .toList();

        // Shiny
        final hasShiny = chunk.toLowerCase().contains('shiny')
            || _goShinyAvailable.contains(id);

        raids.add(_RaidBoss(
          id: id, name: baseName, tier: tier,
          isShadow: inShadow, isMega: isMega, isRegional: isRegional,
          cardSprite: cardSprite,
          detailSprite: detailSprite,
          types: types,
          shinyAvailable: hasShiny,
        ));
      }
    }
    return raids;
  }

  // ── Parser de evento ───────────────────────────────────────────
  // Busca "Selected Event ... Ongoing ... Nome ... Starts ... Ends" em um bloco HTML.
  // Retorna apenas nome + start + end. Ignora subtítulo/descrição.
  _EventInfo? _parseEvent(String html) {
    // Strip de todas as tags HTML primeiro
    final stripped = html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ');

    final m = RegExp(
      r'Selected Event\s+Ongoing\s+([\s\S]*?)(?=Selected Event|##|\Z)',
      caseSensitive: false,
    ).firstMatch(stripped);

    if (m == null) return null;

    final block = m.group(1) ?? '';
    final lines = block.split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return null;

    // Primeira linha = nome do evento
    final name = lines[0];
    if (name.length < 4) return null;

    String? start, end;
    for (final line in lines) {
      if (RegExp(r'^Starts?:', caseSensitive: false).hasMatch(line)) {
        start = line.replaceFirst(RegExp(r'^Starts?:\s*', caseSensitive: false), '').trim();
      } else if (RegExp(r'^Ends?:', caseSensitive: false).hasMatch(line)) {
        end = line.replaceFirst(RegExp(r'^Ends?:\s*', caseSensitive: false), '').trim();
      }
    }

    return _EventInfo(name: name, start: start, end: end);
  }

  String _stripTags(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '').trim();

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
    String bundleAsset(String t) {
      switch (t) {
        case 'pixel': return 'assets/sprites/pixel/${boss.id}.webp';
        case 'home':  return 'assets/sprites/home/${boss.id}.webp';
        default:      return 'assets/sprites/artwork/${boss.id}.webp';
      }
    }
    const base = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';
    final detailUrl = boss.detailSprite ?? bundleAsset(spriteType);

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
      spriteUrl:           detailUrl,
      spriteShinyUrl:      '$base/other/official-artwork/shiny/${boss.id}.png',
      spritePixelUrl:      bundleAsset('pixel'),
      spritePixelShinyUrl: '$base/shiny/${boss.id}.png',
      spritePixelFemaleUrl: null,
      spriteHomeUrl:       bundleAsset('home'),
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
                  children: _buildBody(),
                ),
    );
  }

  List<Widget> _buildBody() {
    final widgets = <Widget>[];

    // ── Evento das raids normais (antes das seções)
    if (_eventNormal != null) {
      widgets.add(_EventBanner(event: _eventNormal!));
      widgets.add(const SizedBox(height: 12));
    }

    // ── Raids normais (tiers 1, 3, 5, 6)
    final hasNormal = _raids.any((r) => !r.isShadow);
    if (hasNormal) {
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

    // ── Evento das shadow raids (antes das seções shadow)
    if (_eventShadow != null) {
      widgets.add(const SizedBox(height: 4));
      widgets.add(_EventBanner(event: _eventShadow!));
      widgets.add(const SizedBox(height: 12));
    }

    // ── Shadow raids (tiers 1, 3, 5, 6)
    final hasShadow = _raids.any((r) => r.isShadow);
    if (hasShadow) {
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
  final int      id;
  final String   name;
  final int      tier;
  final bool     isShadow;
  final bool     isMega;
  final bool     isRegional;
  final String?  cardSprite;    // URL LeekDuck para formas — garantido acessível
  final String?  detailSprite;  // URL PokeAPI artwork para tela de detalhe
  final List<String> types;
  final bool     shinyAvailable;

  const _RaidBoss({
    required this.id, required this.name, required this.tier,
    required this.isShadow, required this.isMega, required this.isRegional,
    this.cardSprite, this.detailSprite,
    required this.types, required this.shinyAvailable,
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
// Exibe: nome do evento + data/hora de início e fim.

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            event.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (event.start != null || event.end != null) ...[
            const SizedBox(height: 4),
            if (event.start != null)
              Text(
                'Início: ${event.start}',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            if (event.end != null)
              Text(
                'Fim: ${event.end}',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
          ],
        ],
      ),
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
        childAspectRatio: 0.82,   // sem CP, cards mais quadrados
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

    final bundleTypes  = PokedexDataService.instance.getTypes(boss.id);
    final displayTypes = boss.types.isNotEmpty ? boss.types : bundleTypes;

    final color1 = displayTypes.isNotEmpty
        ? TypeColors.fromType(ptType(displayTypes[0])) : scheme.primary;
    final color2 = displayTypes.length > 1
        ? TypeColors.fromType(ptType(displayTypes[1])) : color1;
    final bgOp = isDark ? 0.15 : 0.10;

    // Sprite do card:
    // - formas: Image.network da URL do LeekDuck (já acessível pelo app)
    // - base: Image.asset do bundle local
    Widget spriteWidget() {
      if (_loading) {
        return Center(
          child: SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: color1),
          ),
        );
      }
      if (boss.cardSprite != null) {
        return Image.network(
          boss.cardSprite!,
          width: 64, height: 64, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/sprites/artwork/${boss.id}.webp',
            width: 64, height: 64, fit: BoxFit.contain,
          ),
        );
      }
      return Image.asset(
        'assets/sprites/artwork/${boss.id}.webp',
        width: 64, height: 64, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.catching_pokemon,
          color: scheme.onSurfaceVariant.withOpacity(0.4), size: 36,
        ),
      );
    }

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
            // ── Conteúdo
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Sprite
                  SizedBox(
                    height: 64, width: double.infinity,
                    child: spriteWidget(),
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

                  const SizedBox(height: 5),

                  // Tipos: um em cima do outro (Column), centralizados
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

            // ── Ícone shiny discreto, sem caixa
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
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

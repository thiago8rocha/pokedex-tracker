import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dexcurator/models/pokemon.dart';
import 'package:dexcurator/services/pokedex_data_service.dart';
import 'package:dexcurator/services/storage_service.dart';
import 'package:dexcurator/translations.dart';
import 'package:dexcurator/core/pokemon_types.dart';

// ─── UTILITÁRIOS GLOBAIS ─────────────────────────────────────────

const String kApiBase = 'https://pokeapi.co/api/v2';

// ─── ÍCONES DE TIPO ───────────────────────────────────────────────
// SVGs em assets/types/<type>.svg (MIT — duiker101/pokemon-type-svg-icons)
String typeIconAsset(String type) => 'assets/types/${type.toLowerCase()}.png';

// ─── ÍCONES DE ESPECIALIDADE POKOPIA ─────────────────────────────
// Converte nome da especialidade para path do asset PNG
// Ex: 'Gather Honey' → 'assets/pokopia/specialties/gatherhoney.png'
const Map<String, String> _specialtyFileNames = {
  'Appraise':     'appraise',
  'Build':        'build',
  'Bulldoze':     'bulldoze',
  'Burn':         'burn',
  'Chop':         'chop',
  'Collect':      'collect',
  'Crush':        'crush',
  'DJ':           'dj',
  'Dream Island': 'dreamisland',
  'Eat':          'eat',
  'Engineer':     'engineer',
  'Explode':      'explode',
  'Fly':          'fly',
  'Gather':       'gather',
  'Gather Honey': 'gatherhoney',
  'Generate':     'generate',
  'Grow':         'grow',
  'Hype':         'hype',
  'Illuminate':   'illuminate',
  'Litter':       'litter',
  'Paint':        'paint',
  'Party':        'party',
  'Rarify':       'rarify',
  'Recycle':      'recycle',
  'Search':       'search',
  'Storage':      'storage',
  'Teleport':     'teleport',
  'Trade':        'trade',
  'Transform':    'transform',
  'Water':        'water',
  'Yawn':         'yawn',
};

String specialtyIconPath(String specialty) {
  final file = _specialtyFileNames[specialty] ?? specialty.toLowerCase().replaceAll(' ', '');
  return 'assets/pokopia/specialties/$file.png';
}

// Nomes traduzidos dos tipos
Map<String, String> get typeNamePt => typeNamesPt;

// ─── MAPEAMENTO pokedexId → version-groups da PokeAPI ─────────────
// Usado para buscar o flavor text do jogo correto em pokemon-species.
// Ordem: prioridade decrescente (primeiros = preferidos para esse jogo).
const Map<String, List<String>> pokedexVersionGroups = {
  'lets_go_pikachu___eevee':            ['lets-go-pikachu-lets-go-eevee'],
  'firered___leafgreen':                 ['firered-leafgreen'],
  'sword___shield':                      ['sword-shield'],
  'brilliant_diamond___shining_pearl':   ['brilliant-diamond-and-shining-pearl'],
  'legends_arceus':                      ['legends-arceus'],
  'scarlet___violet':                    ['scarlet-violet'],
  'legends_z-a':                         ['legends-za'],
  // Fallback para nacional: prioridade da geração mais recente
  'nacional': [
    'scarlet-violet', 'legends-za', 'legends-arceus',
    'brilliant-diamond-and-shining-pearl', 'sword-shield',
    'lets-go-pikachu-lets-go-eevee', 'firered-leafgreen',
    'ultra-sun-ultra-moon', 'sun-moon', 'omega-ruby-alpha-sapphire',
    'x-y', 'black-2-white-2', 'black-white', 'heartgold-soulsilver',
    'platinum', 'diamond-pearl', 'emerald', 'firered-leafgreen',
    'ruby-sapphire', 'crystal', 'gold-silver', 'red-blue',
  ],
};

/// Traduz o flavor text para pt-BR usando a API gratuita do Google Translate.
/// Se o texto já estiver em português ou a tradução falhar, retorna o original.
Future<String> translateFlavorText(String text) async {
  if (text.isEmpty) return text;

  // Pula tradução apenas se já for inequivocamente português
  final ptOnly = RegExp(
    r'\b(não|também|seus|suas|dele|dela|então|assim|isto|isso|aqui|pelo|pela|são|está)\b',
    caseSensitive: false,
  );
  if (ptOnly.hasMatch(text)) return text;

  // Tentativa 1: Google Translate (gratuito, sem chave)
  try {
    final url = Uri.https('translate.googleapis.com', '/translate_a/single', {
      'client': 'gtx', 'sl': 'en', 'tl': 'pt', 'dt': 't', 'q': text,
    });
    final r = await http.get(url).timeout(const Duration(seconds: 6));
    if (r.statusCode == 200) {
      final data = json.decode(r.body) as List<dynamic>;
      final result = (data[0] as List<dynamic>)
          .map((s) => (s as List<dynamic>)[0] as String? ?? '')
          .join('').trim();
      if (result.isNotEmpty && result != text) return result;
    }
  } catch (_) {}

  // Tentativa 2: MyMemory (API pública, sem chave)
  try {
    final url = Uri.https('api.mymemory.translated.net', '/get', {
      'q': text, 'langpair': 'en|pt-BR',
    });
    final r = await http.get(url).timeout(const Duration(seconds: 6));
    if (r.statusCode == 200) {
      final data = json.decode(r.body) as Map<String, dynamic>;
      final result = data['responseData']?['translatedText'] as String? ?? '';
      if (result.isNotEmpty && result != text) return result;
    }
  } catch (_) {}

  return text;
}


/// Prioriza pt-BR e pt; cai para en; prioriza a versão do jogo correto.
String extractFlavorText(
  List<dynamic> flavorEntries,
  String pokedexId,
) {
  String _clean(String s) =>
      s.replaceAll('\n', ' ').replaceAll('\f', ' ').replaceAll('\r', ' ')
       .replaceAll(RegExp(r' +'), ' ').trim();

  bool _isPt(String lang) => lang == 'pt-BR' || lang == 'pt';

  final preferredGroups = pokedexVersionGroups[pokedexId] ??
      pokedexVersionGroups['nacional']!;

  // Tentar cada version-group preferido, priorizando pt/pt-BR
  for (final vg in preferredGroups) {
    String ptText = '', enText = '';
    for (final e in flavorEntries) {
      final evg = e['version']?['name'] as String? ?? '';
      if (!_versionBelongsToGroup(evg, vg)) continue;
      final lang = e['language']['name'] as String;
      final text = _clean(e['flavor_text'] as String? ?? '');
      if (_isPt(lang) && ptText.isEmpty) ptText = text;
      if (lang == 'en' && enText.isEmpty) enText = text;
    }
    if (ptText.isNotEmpty) return ptText;
    if (enText.isNotEmpty) return enText;
  }

  // Fallback: qualquer entrada em pt/pt-BR ou en
  String anyPt = '', anyEn = '';
  for (final e in flavorEntries) {
    final lang = e['language']['name'] as String;
    final text = _clean(e['flavor_text'] as String? ?? '');
    if (_isPt(lang) && anyPt.isEmpty) anyPt = text;
    if (lang == 'en' && anyEn.isEmpty) anyEn = text;
  }
  return anyPt.isNotEmpty ? anyPt : anyEn;
}

// Mapeia version name → version-group name da PokeAPI
bool _versionBelongsToGroup(String version, String group) {
  const versionToGroup = {
    'sword':   'sword-shield',         'shield':  'sword-shield',
    'scarlet': 'scarlet-violet',       'violet':  'scarlet-violet',
    'lets-go-pikachu': 'lets-go-pikachu-lets-go-eevee',
    'lets-go-eevee':   'lets-go-pikachu-lets-go-eevee',
    'brilliant-diamond': 'brilliant-diamond-and-shining-pearl',
    'shining-pearl':     'brilliant-diamond-and-shining-pearl',
    'legends-arceus':    'legends-arceus',
    'legends-za':        'legends-za',
    'firered': 'firered-leafgreen', 'leafgreen': 'firered-leafgreen',
    'ultra-sun':   'ultra-sun-ultra-moon', 'ultra-moon': 'ultra-sun-ultra-moon',
    'sun':  'sun-moon', 'moon': 'sun-moon',
    'omega-ruby': 'omega-ruby-alpha-sapphire', 'alpha-sapphire': 'omega-ruby-alpha-sapphire',
    'x': 'x-y', 'y': 'x-y',
    'black-2': 'black-2-white-2', 'white-2': 'black-2-white-2',
    'black': 'black-white', 'white': 'black-white',
    'heartgold': 'heartgold-soulsilver', 'soulsilver': 'heartgold-soulsilver',
    'platinum': 'platinum',
    'diamond': 'diamond-pearl', 'pearl': 'diamond-pearl',
    'emerald': 'emerald',
    'ruby': 'ruby-sapphire', 'sapphire': 'ruby-sapphire',
    'crystal': 'crystal',
    'gold': 'gold-silver', 'silver': 'gold-silver',
    'red': 'red-blue', 'blue': 'red-blue',
  };
  return (versionToGroup[version] ?? version) == group;
}

// ─── MAPEAMENTO FORMAS → JOGO ─────────────────────────────────────
// Megas Kanto: Let's Go P/E. Megas não-Kanto: Legends: Z-A.
// Sword/Shield NÃO tem Megas. Gigamax é exclusivo de Sword/Shield.
const Map<String, String> formGameMap = {
  'mega':   "Let's Go P/E",
  'gmax':   'Sword / Shield',
  'alola':  'Sword / Shield',
  'galar':  'Sword / Shield',
  'hisui':  'Legends: Arceus',
  'paldea': 'Scarlet / Violet',
  'venusaur-mega':   "Let's Go P/E",
  'charizard-mega-x':"Let's Go P/E",
  'charizard-mega-y':"Let's Go P/E",
  'blastoise-mega':  "Let's Go P/E",
  'beedrill-mega':   "Let's Go P/E",
  'pidgeot-mega':    "Let's Go P/E",
  'alakazam-mega':   "Let's Go P/E",
  'slowbro-mega':    "Let's Go P/E",
  'gengar-mega':     "Let's Go P/E",
  'kangaskhan-mega': "Let's Go P/E",
  'pinsir-mega':     "Let's Go P/E",
  'gyarados-mega':   "Let's Go P/E",
  'aerodactyl-mega': "Let's Go P/E",
  'mewtwo-mega-x':   "Let's Go P/E",
  'mewtwo-mega-y':   "Let's Go P/E",
  'ampharos-mega':  'Legends: Z-A',
  'steelix-mega':   'Legends: Z-A',
  'scizor-mega':    'Legends: Z-A',
  'heracross-mega': 'Legends: Z-A',
  'houndoom-mega':  'Legends: Z-A',
  'tyranitar-mega': 'Legends: Z-A',
  'blaziken-mega':  'Legends: Z-A',
  'gardevoir-mega': 'Legends: Z-A',
  'mawile-mega':    'Legends: Z-A',
  'aggron-mega':    'Legends: Z-A',
  'medicham-mega':  'Legends: Z-A',
  'manectric-mega': 'Legends: Z-A',
  'banette-mega':   'Legends: Z-A',
  'absol-mega':     'Legends: Z-A',
  'garchomp-mega':  'Legends: Z-A',
  'lucario-mega':   'Legends: Z-A',
  'abomasnow-mega': 'Legends: Z-A',
  'latias-mega':    'Legends: Z-A',
  'latios-mega':    'Legends: Z-A',
  'sceptile-mega':  'Legends: Z-A',
  'swampert-mega':  'Legends: Z-A',
  'sableye-mega':   'Legends: Z-A',
  'sharpedo-mega':  'Legends: Z-A',
  'camerupt-mega':  'Legends: Z-A',
  'altaria-mega':   'Legends: Z-A',
  'glalie-mega':    'Legends: Z-A',
  'salamence-mega': 'Legends: Z-A',
  'metagross-mega': 'Legends: Z-A',
  'rayquaza-mega':  'Legends: Z-A',
  'lopunny-mega':   'Legends: Z-A',
  'gallade-mega':   'Legends: Z-A',
  'audino-mega':    'Legends: Z-A',
  'diancie-mega':   'Legends: Z-A',
  'dialga-origin':           'Legends: Arceus',
  'palkia-origin':           'Legends: Arceus',
  'basculin-whitestriped':   'Legends: Arceus',
  'enamorus-therian':        'Legends: Arceus',
  'tauros-paldea-combat':    'Scarlet / Violet',
  'tauros-paldea-blaze':     'Scarlet / Violet',
  'tauros-paldea-aqua':      'Scarlet / Violet',
  'wooper-paldea':           'Scarlet / Violet',
};

/// Resolve o jogo a partir do slug da variedade usando o mapa estático.
String? gameForForm(String slug) {
  if (formGameMap.containsKey(slug)) return formGameMap[slug];
  for (final suffix in ['mega', 'gmax', 'alola', 'galar', 'hisui', 'paldea']) {
    if (slug.contains('-$suffix')) return formGameMap[suffix];
  }
  return null;
}

String ptType(String en) => typeName(en);

Color typeTextColor(Color bg) =>
    bg.computeLuminance() > 0.35 ? Colors.black87 : Colors.white;

// ─── BILINGUAL MODE NOTIFIER ────────────────────────────────────
// ValueNotifier global — inicializado no main ou na primeira leitura.
// Qualquer widget pode ouvir sem async/FutureBuilder.

final bilingualModeNotifier = ValueNotifier<String>('both');

/// Inicializa o notifier lendo do storage. Chamar no main() antes do runApp.
Future<void> initBilingualMode() async {
  bilingualModeNotifier.value = await StorageService().getBilingualMode();
}

// ─── DEFAULT SPRITE NOTIFIER ─────────────────────────────────────
// Sincroniza o sprite padrão entre PokedexScreen, DetailHeader e Settings.

final defaultSpriteNotifier = ValueNotifier<String>('artwork');

Future<void> initDefaultSprite() async {
  defaultSpriteNotifier.value = await StorageService().getDefaultSprite();
}

// ─── FORMS IN LIST NOTIFIER ─────────────────────────────────────

final formsInListNotifier = ValueNotifier<Map<String, bool>>({
  'mega': true, 'gigantamax': true, 'regional': true, 'other': true,
});

Future<void> initShowFormsInList() async {
  final storage = StorageService();
  formsInListNotifier.value = {
    'mega':       await storage.getFormCategoryEnabled('mega'),
    'gigantamax': await storage.getFormCategoryEnabled('gigantamax'),
    'regional':   await storage.getFormCategoryEnabled('regional'),
    'other':      await storage.getFormCategoryEnabled('other'),
  };
}

// ─── HELPER BILÍNGUE ────────────────────────────────────────────
// Widget que exibe nome de move ou ability conforme a preferência.
// Usa o ValueNotifier global — sem FutureBuilder, sem async no build.

class BilingualTerm extends StatelessWidget {
  final String namePt;  // nome em português (pode ser vazio)
  final String nameEn;  // nome em inglês (sempre presente)
  final TextStyle? baseStyle;
  final TextStyle? secondaryStyle;

  const BilingualTerm({
    super.key,
    required this.namePt,
    required this.nameEn,
    this.baseStyle,
    this.secondaryStyle,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: bilingualModeNotifier,
      builder: (ctx, mode, _) {
        final enFormatted = nameEn.isEmpty ? '' :
            nameEn.replaceAll('-', ' ').split(' ')
                .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
                .join(' ');
        final ptFormatted = namePt.isNotEmpty ? namePt : enFormatted;
        final secondary = Theme.of(context).colorScheme.onSurfaceVariant;

        if (mode == 'en') {
          return Text(enFormatted,
            style: baseStyle ?? const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis, maxLines: 1);
        }
        if (mode == 'pt' || namePt.isEmpty) {
          return Text(ptFormatted,
            style: baseStyle ?? const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis, maxLines: 1);
        }
        // both: EN à esquerda (original), PT à direita (tradução)
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(child: Text(enFormatted,
              style: baseStyle ?? const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis, maxLines: 1)),
            const SizedBox(width: 6),
            Flexible(child: Text(ptFormatted,
              style: (secondaryStyle ?? const TextStyle(fontSize: 11))
                  .copyWith(color: secondary),
              overflow: TextOverflow.ellipsis, maxLines: 1)),
          ],
        );
      },
    );
  }
}

// ─── CORES DOS TIPOS ─────────────────────────────────────────────
// Extraídas dos ícones oficiais do Bulbapedia
Map<String, Color> get typeIconColors => typeColors;

// ─── POKÉBALL LOADER ─────────────────────────────────────────────
// Spinner customizado do projeto.
// size: normal (default 48px) para tela cheia, small (24px) para uso inline.

class PokeballLoader extends StatefulWidget {
  final double size;
  const PokeballLoader({super.key, this.size = 48});

  /// Versão pequena para uso inline (ex: dentro de SizedBox de 32px)
  const PokeballLoader.small({super.key}) : size = 24;

  @override
  State<PokeballLoader> createState() => _PokeballLoaderState();
}

class _PokeballLoaderState extends State<PokeballLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _PokeballPainter(_ctrl.value),
      ),
    );
  }
}

class _PokeballPainter extends CustomPainter {
  final double t; // 0.0 → 1.0
  _PokeballPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;

    // Rotação contínua
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(t * 2 * 3.14159265);
    canvas.translate(-cx, -cy);

    final paintRed   = Paint()..color = const Color(0xFFE53935)..style = PaintingStyle.fill;
    final paintWhite = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final paintBlack = Paint()..color = const Color(0xFF212121)..style = PaintingStyle.fill;
    final paintStroke = Paint()
      ..color = const Color(0xFF212121)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;

    // Metade superior (vermelha)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      3.14159265, 3.14159265, true, paintRed);

    // Metade inferior (branca)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      0, 3.14159265, true, paintWhite);

    // Faixa central preta
    final bandH = size.height * 0.12;
    canvas.drawRect(
      Rect.fromLTWH(0, cy - bandH / 2, size.width, bandH), paintBlack);

    // Círculo central externo (preto)
    canvas.drawCircle(Offset(cx, cy), r * 0.28, paintBlack);

    // Círculo central interno (branco)
    canvas.drawCircle(Offset(cx, cy), r * 0.18, paintWhite);

    // Contorno geral
    canvas.drawCircle(Offset(cx, cy), r - paintStroke.strokeWidth / 2, paintStroke);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PokeballPainter old) => old.t != t;
}

// ─── WIDGET: BADGE DE TIPO ────────────────────────────────────────
// Círculo PNG (transparente fora) encaixado no lado esquerdo
// do retângulo colorido. Sem blendMode, sem layer extra.

class TypeBadge extends StatelessWidget {
  final String type;
  const TypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final key   = type.toLowerCase();
    final label = typeNamePt[key] ?? ptType(type);
    final color = typeIconColors[key] ?? const Color(0xFF888888);

    return SizedBox(
      height: 32,
      width: 130,
      child: Stack(
        children: [
          // Fundo colorido sem bordas arredondadas
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
          // Texto centralizado (com padding para não sobrepor o ícone)
          Positioned.fill(
            left: 30,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          // Círculo PNG sobre o fundo — transparência funciona naturalmente
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Image.asset(
              typeIconAsset(type),
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(width: 32),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── WIDGET: CABEÇALHO DA ABA INFORMAÇÕES ────────────────────────
// Layout: categoria → seletor de jogo (opcional) → flavor text → Altura/Tipo/Peso

class AboutHeader extends StatefulWidget {
  final String category;
  final List<Map<String, dynamic>> flavorTexts; // grupos do bundle novo
  final String height;
  final String weight;
  final List<String> types;
  final bool loading;
  final String pokedexId; // jogo ativo — seleciona o grupo padrão

  const AboutHeader({
    super.key,
    required this.category,
    required this.flavorTexts,
    required this.height,
    required this.weight,
    required this.types,
    required this.loading,
    required this.pokedexId,
  });

  @override
  State<AboutHeader> createState() => _AboutHeaderState();
}

class _AboutHeaderState extends State<AboutHeader> {
  int _selectedIdx = 0;

  // Mapa pokedexId → gameName usado em flavorTexts[].games
  static const Map<String, String?> _pokedexToGame = {
    'red___blue':                    'Red / Blue',
    'gold___silver':                 'Gold / Silver',
    'ruby___sapphire':               'Ruby / Sapphire',
    'firered___leafgreen_(gba)':     'FireRed / LeafGreen (GBA)',
    'emerald':                       'Emerald',
    'diamond___pearl':               'Diamond / Pearl',
    'platinum':                      'Platinum',
    'heartgold___soulsilver':        'HeartGold / SoulSilver',
    'black___white':                 'Black / White',
    'black_2___white_2':             'Black 2 / White 2',
    'x___y':                         'X / Y',
    'omega_ruby___alpha_sapphire':   'Omega Ruby / Alpha Sapphire',
    'sun___moon':                    'Sun / Moon',
    'ultra_sun___ultra_moon':        'Ultra Sun / Ultra Moon',
    'lets_go_pikachu___eevee':       "Let's Go Pikachu / Eevee",
    'sword___shield':                'Sword / Shield',
    'brilliant_diamond___shining_pearl': 'Brilliant Diamond / Shining Pearl',
    'legends_arceus':                'Legends: Arceus',
    'scarlet___violet':              'Scarlet / Violet',
    'legends_z-a':                   'Legends: Z-A',
    'pokémon_go':                    'Pokémon GO',
    'pokopia':                       'Pokopia',
    'pokopia_event':                 'Pokopia',
    'nacional':                      null,
  };

  @override
  void initState() {
    super.initState();
    _selectDefaultGroup();
  }

  @override
  void didUpdateWidget(AboutHeader old) {
    super.didUpdateWidget(old);
    if (old.pokedexId != widget.pokedexId || old.flavorTexts != widget.flavorTexts) {
      _selectDefaultGroup();
    }
  }

  void _selectDefaultGroup() {
    if (widget.flavorTexts.isEmpty) return;
    final game = _pokedexToGame[widget.pokedexId];
    if (game == null) {
      // Nacional — usa o grupo mais recente (último)
      setState(() => _selectedIdx = widget.flavorTexts.length - 1);
      return;
    }
    final idx = widget.flavorTexts.indexWhere(
      (g) => (g['games'] as List).contains(game),
    );
    setState(() => _selectedIdx = idx >= 0 ? idx : widget.flavorTexts.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final categoryLabel = widget.loading
        ? ''
        : widget.category.isEmpty || widget.category == '—'
            ? '—'
            : widget.category;

    final groups      = widget.flavorTexts;
    final currentText = groups.isNotEmpty
        ? (groups[_selectedIdx]['textPt'] as String? ?? '')
        : '';

    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      // Categoria centralizada
      if (widget.loading)
        const SizedBox(height: 20,
          child: Center(child: PokeballLoader.small()))
      else
        Text(
          categoryLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13, color: secondary, fontStyle: FontStyle.italic),
        ),

      const SizedBox(height: 12),

      // Flavor text
      if (widget.loading)
        const SizedBox(height: 40,
          child: Center(child: PokeballLoader.small()))
      else
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            currentText.isEmpty ? '—' : currentText,
            key: ValueKey(_selectedIdx),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, height: 1.5),
          ),
        ),

      const SizedBox(height: 20),

      // Linha: Altura | Tipo | Peso
      // Títulos alinhados pelo topo. Valores de Altura e Peso
      // centrados verticalmente em relação ao bloco de tipos.
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Altura ──
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Altura', style: TextStyle(fontSize: 11, color: secondary)),
                Expanded(child: Center(
                  child: Text(widget.loading ? '—' : widget.height,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                )),
              ],
            )),

            // ── Tipo ──
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Tipo', style: TextStyle(fontSize: 11, color: secondary)),
                const SizedBox(height: 6),
                if (widget.loading)
                  const SizedBox(height: 32,
                    child: PokeballLoader.small())
                else
                  ...widget.types.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: TypeBadge(type: t),
                  )),
              ],
            )),

            // ── Peso ──
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Peso', style: TextStyle(fontSize: 11, color: secondary)),
                Expanded(child: Center(
                  child: Text(widget.loading ? '—' : widget.weight,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                )),
              ],
            )),
          ],
        ),
      ),

      const SizedBox(height: 8),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────

Widget secTitle(BuildContext context, String title) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(title, style: Theme.of(context).textTheme.labelSmall?.copyWith(
    letterSpacing: 0.8,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    fontWeight: FontWeight.w600,
    fontSize: 10,
  )),
);

// ─── WIDGET: SEÇÃO COM CARD ───────────────────────────────────────
// Título centralizado com borda da cor do tipo primário do Pokémon.
// Conteúdo dentro de um container com fundo levemente diferente do fundo.

class SectionCard extends StatelessWidget {
  final String title;
  final List<String> pokemonTypes;
  final Widget child;
  final bool loading;

  const SectionCard({
    super.key,
    required this.title,
    required this.pokemonTypes,
    required this.child,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tColor = pokemonTypes.isNotEmpty
        ? typeColor(pokemonTypes[0])
        : const Color(0xFF9E9E9E);

    final cardBg = isDark
        ? tColor.withOpacity(0.08)
        : tColor.withOpacity(0.06);

    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Card com espaço no topo para o badge ──
        Container(
          margin: const EdgeInsets.only(top: 14),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border.all(color: tColor.withOpacity(0.3), width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: loading
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(12),
                  child: PokeballLoader.small()))
              : child,
        ),

        // ── Badge do título centrado na borda superior do card ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: scaffoldBg,
                border: Border.all(color: tColor, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: tColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Color neutralBg(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFF5F5F5);

Color neutralBorder(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFE0E0E0);

// ─── HEADER COMPARTILHADO ────────────────────────────────────────

class DetailHeader extends StatefulWidget {
  final Pokemon pokemon;
  final bool caught;
  final VoidCallback onToggleCaught;
  final String caughtLabel;
  // Navegação entre pokémon
  final String? prevName;
  final int?    prevId;
  final String? nextName;
  final int?    nextId;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  // Ação customizada para o botão de voltar (ex: voltar para habitat)
  final VoidCallback? customBackAction;

  const DetailHeader({
    super.key,
    required this.pokemon,
    required this.caught,
    required this.onToggleCaught,
    this.caughtLabel = 'Capturado',
    this.prevName, this.prevId,
    this.nextName, this.nextId,
    this.onPrev, this.onNext,
    this.customBackAction,
  });

  @override
  State<DetailHeader> createState() => _DetailHeaderState();
}

class _DetailHeaderState extends State<DetailHeader> {
  bool _isShiny  = false;
  bool _isFemale = false;

  @override
  void initState() {
    super.initState();
  }

  /// URL do sprite baseado no modo padrão das configurações + shiny/female
  String get _spriteUrl {
    final p = widget.pokemon;
    const base = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';
    final spriteType = defaultSpriteNotifier.value;

    if (spriteType == 'home') {
      if (_isShiny) return p.spriteHomeShinyUrl ?? p.spriteUrl;
      if (_isFemale) return p.spriteHomeFemaleUrl ?? p.spriteHomeUrl ?? p.spriteUrl;
      return p.spriteHomeUrl ?? p.spriteUrl;
    }
    if (spriteType == 'pixel') {
      if (_isShiny) return p.spritePixelShinyUrl ?? p.spritePixelUrl ?? p.spriteUrl;
      if (_isFemale) return p.spritePixelFemaleUrl ?? p.spritePixelUrl ?? p.spriteUrl;
      return p.spritePixelUrl ?? p.spriteUrl;
    }
    // Artwork (padrão)
    if (_isShiny) return p.spriteShinyUrl ?? p.spriteUrl;
    if (_isFemale) return p.spritePixelFemaleUrl ?? '$base/front_female/${p.id}.png';
    return p.spriteUrl;
  }

  void _toggleShiny()  => setState(() => _isShiny  = !_isShiny);
  void _toggleFemale() => setState(() => _isFemale = !_isFemale);

  @override
  Widget build(BuildContext context) {
    final p = widget.pokemon;
    final pt = p.types.isNotEmpty ? p.types[0] : 'normal';
    // Suaviza a cor do tipo misturando com branco — mantém identidade mas reduz saturação
    final rawC1 = typeColor(pt);
    final rawC2 = p.types.length > 1 ? typeColor(p.types[1]) : rawC1;
    final c1 = Color.lerp(rawC1, Colors.white, 0.28)!;
    final c2 = Color.lerp(rawC2, Colors.white, 0.28)!;

    // Pokébola: vermelha = capturado, branca translúcida = não capturado
    final pokeballColor = widget.caught
        ? const Color(0xFFE24B4A)
        : Colors.white.withOpacity(0.75);

    final spriteType = defaultSpriteNotifier.value;
    final hasShinyNow = spriteType == 'home'
        ? p.spriteHomeShinyUrl != null
        : spriteType == 'pixel'
            ? p.spritePixelShinyUrl != null
            : p.spriteShinyUrl != null;
    final hasFemaleNow = spriteType == 'home'
        ? p.spriteHomeFemaleUrl != null
        : spriteType == 'pixel'
            ? p.spritePixelFemaleUrl != null
            : false;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: c1,
      iconTheme: const IconThemeData(color: Colors.white),
      leading: widget.customBackAction != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.customBackAction,
            )
          : null,
      actions: const [], // botões dentro do flexibleSpace
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [c1, c2.withOpacity(0.85)],
            ),
          ),
          child: SafeArea(
            child: Stack(children: [

              // ── Conteúdo central (sempre centralizado) ───────
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Espaço para não sobrepor botões do topo
                    const SizedBox(height: 8),
                    // Sprite — SizedBox fixo garante tamanho consistente
                    // independente da resolução da imagem (local vs rede, shiny vs normal)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _spriteUrl.startsWith('assets/')
                              ? Image.asset(
                                  _spriteUrl,
                                  key: ValueKey(_spriteUrl),
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                  filterQuality: defaultSpriteNotifier.value == 'pixel'
                                      ? FilterQuality.none
                                      : FilterQuality.medium,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.catching_pokemon, size: 100, color: Colors.white),
                                )
                              : Image.network(
                                  _spriteUrl,
                                  key: ValueKey(_spriteUrl),
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                  filterQuality: defaultSpriteNotifier.value == 'pixel'
                                      ? FilterQuality.none
                                      : FilterQuality.medium,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.catching_pokemon, size: 100, color: Colors.white),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Linha inferior: prev (esq) | nome atual (centro) | next (dir)
                    // O nome central usa Positioned.fill com padding lateral
                    // para nunca sobrepor os prev/next laterais.
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        height: 52,
                        child: Stack(
                          children: [

                            // ── Prev — esquerda ────────────────────────
                            if (widget.onPrev != null)
                              Positioned(
                                left: 0, top: 0, bottom: 0,
                                child: GestureDetector(
                                  onTap: widget.onPrev,
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Row(mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Icon(Icons.chevron_left, size: 20,
                                          color: Colors.white.withOpacity(0.9)),
                                        const SizedBox(width: 2),
                                        Column(mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (widget.prevId != null)
                                              Text('#${widget.prevId.toString().padLeft(3,'0')}',
                                                style: TextStyle(fontSize: 11,
                                                  color: Colors.white.withOpacity(0.65),
                                                  fontWeight: FontWeight.w500,
                                                  height: 1.1)),
                                            if (widget.prevName != null)
                                              Text(widget.prevName!,
                                                style: TextStyle(fontSize: 13,
                                                  color: Colors.white.withOpacity(0.85),
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.1)),
                                          ]),
                                      ]),
                                  ),
                                ),
                              ),

                            // ── Next — direita ─────────────────────────
                            if (widget.onNext != null)
                              Positioned(
                                right: 0, top: 0, bottom: 0,
                                child: GestureDetector(
                                  onTap: widget.onNext,
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Row(mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Column(mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            if (widget.nextId != null)
                                              Text('#${widget.nextId.toString().padLeft(3,'0')}',
                                                style: TextStyle(fontSize: 11,
                                                  color: Colors.white.withOpacity(0.65),
                                                  fontWeight: FontWeight.w500,
                                                  height: 1.1)),
                                            if (widget.nextName != null)
                                              Text(widget.nextName!,
                                                style: TextStyle(fontSize: 13,
                                                  color: Colors.white.withOpacity(0.85),
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.1)),
                                          ]),
                                        const SizedBox(width: 2),
                                        Icon(Icons.chevron_right, size: 20,
                                          color: Colors.white.withOpacity(0.9)),
                                      ]),
                                  ),
                                ),
                              ),

                            // ── Nome atual — centralizado com padding lateral ─
                            // padding de 90px de cada lado reserva espaço para
                            // os prev/next (max ~80px) sem sobrepor
                            Positioned.fill(
                              left: 90, right: 90,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('#${p.entryNumber.toString().padLeft(3, '0')}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.0,
                                      height: 1.1,
                                    )),
                                  Text(p.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                      height: 1.1,
                                    )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Coluna de botões no canto direito ─────────────
              // Aligned dentro da SafeArea, mesma coluna que o ícone da AppBar
              Positioned(
                top: 0,
                right: 4,
                bottom: 0,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Pokébola (capturado)
                        GestureDetector(
                          onTap: widget.onToggleCaught,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(Icons.catching_pokemon,
                              size: 28, color: pokeballColor),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // 2. Shiny (só mostra se existe no modo atual)
                        if (hasShinyNow)
                          _HeaderIconButton(
                            icon: Icons.auto_awesome,
                            active: _isShiny,
                            activeColor: const Color(0xFFFFD700),
                            onTap: _toggleShiny,
                          ),
                        // 3. Feminino (só mostra se existe no modo atual)
                        if (hasFemaleNow)
                          _HeaderIconButton(
                            icon: Icons.female,
                            active: _isFemale,
                            activeColor: Colors.pinkAccent,
                            onTap: _toggleFemale,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Botão compacto de variante dentro do header expandido
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final Color activeColor;

  const _HeaderIconButton({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: active
                ? activeColor.withOpacity(0.25)
                : Colors.black.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: active
                  ? activeColor.withOpacity(0.9)
                  : Colors.white.withOpacity(0.4),
              width: active ? 1.5 : 0.8,
            ),
          ),
          child: Icon(
            icon,
            size: 15,
            color: active ? activeColor : Colors.white.withOpacity(0.9),
          ),
        ),
      ),
    );
  }
}

// ─── ABA STATUS (compartilhada) ──────────────────────────────────

class StatusTab extends StatefulWidget {
  final Pokemon pokemon;
  const StatusTab({super.key, required this.pokemon});

  @override
  State<StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<StatusTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Fórmulas oficiais de min/max (nível 100) ──────────────────
  // Mín: sem EVs, sem IVs, nature negativa
  // Máx: 252 EVs, 31 IVs, nature positiva
  int _minStat(int base, bool isHp) {
    if (isHp) return ((2 * base * 100) ~/ 100) + 100 + 10; // mín HP nivel 100 sem EV/IV
    return (((2 * base * 100) ~/ 100) + 5) * 9 ~/ 10;
  }
  int _maxStat(int base, bool isHp) {
    if (isHp) return ((2 * base + 31 + 63) * 100 ~/ 100) + 100 + 10;
    return ((((2 * base + 31 + 63) * 100 ~/ 100) + 5) * 11 + 9) ~/ 10;
  }

  @override
  Widget build(BuildContext context) {
    final p  = widget.pokemon;
    final wk = _calculateWeaknesses(p.types);
    final tColor = p.types.isNotEmpty
        ? typeColor(p.types[0])
        : Theme.of(context).colorScheme.primary;

    // Grupos de dano
    final quad    = wk.entries.where((e) => e.value == 4.0).toList()..sort((a,b) => a.key.compareTo(b.key));
    final fraq    = wk.entries.where((e) => e.value == 2.0).toList()..sort((a,b) => a.key.compareTo(b.key));
    final neutral = wk.entries.where((e) => e.value == 1.0).toList()..sort((a,b) => a.key.compareTo(b.key));
    final half    = wk.entries.where((e) => e.value == 0.5).toList()..sort((a,b) => a.key.compareTo(b.key));
    final quart   = wk.entries.where((e) => e.value == 0.25).toList()..sort((a,b) => a.key.compareTo(b.key));
    final imun    = wk.entries.where((e) => e.value == 0.0).toList()..sort((a,b) => a.key.compareTo(b.key));
    final stats = [
      _StatRow('HP',           p.baseHp,        const Color(0xFF5a9e5a), isHp: true),
      _StatRow('Ataque',       p.baseAttack,     const Color(0xFFE24B4A)),
      _StatRow('Defesa',       p.baseDefense,    const Color(0xFF378ADD)),
      _StatRow('At. Especial', p.baseSpAttack,   const Color(0xFF9C27B0)),
      _StatRow('Def. Especial',p.baseSpDefense,  const Color(0xFF378ADD)),
      _StatRow('Velocidade',   p.baseSpeed,      const Color(0xFFEF9F27)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [

        // ── SEÇÃO STATUS ──────────────────────────────────────────
        SectionCard(
          title: 'STATUS BASE',
          pokemonTypes: p.types,
          child: Column(children: [
            // Abas Base / Mínimo / Máximo — full width, mesmo padrão da aba Golpes
            Row(
              children: [
                for (final e in [
                  (0, 'Base'),
                  (1, 'Mínimo'),
                  (2, 'Máximo'),
                ]) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _tabController.animateTo(e.$1),
                      child: AnimatedBuilder(
                        animation: _tabController,
                        builder: (ctx, _) {
                          final active = _tabController.index == e.$1;
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: active
                                  ? tColor
                                  : tColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: active
                                    ? tColor
                                    : tColor.withOpacity(0.35),
                                width: 1,
                              ),
                            ),
                            child: Text(e.$2,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? typeTextColor(tColor)
                                    : tColor,
                              )),
                          );
                        },
                      ),
                    ),
                  ),
                  if (e.$1 < 2) const SizedBox(width: 5),
                ],
              ],
            ),
            const SizedBox(height: 14),
            // Barras de stat
            ...stats.map((s) => _StatBarRow(
              context: context,
              row: s,
              tabController: _tabController,
              minVal: _minStat(s.base, s.isHp),
              maxVal: _maxStat(s.base, s.isHp),
            )),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Total: ${p.totalStats}',
                style: TextStyle(fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // ── SEÇÃO RELAÇÕES DE DANO ────────────────────────────────
        SectionCard(
          title: 'EFETIVIDADE DE TIPOS',
          pokemonTypes: p.types,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (quad.isNotEmpty)   _DamageGroup(title: 'Muito fraco a',         subtitle: '4× de dano',      entries: quad),
              if (fraq.isNotEmpty)   _DamageGroup(title: 'Fraco a',              subtitle: '2× de dano',      entries: fraq),
              if (neutral.isNotEmpty) _DamageGroup(title: 'Dano normal',         subtitle: '1× de dano',      entries: neutral),
              if (half.isNotEmpty)   _DamageGroup(title: 'Resistente a',         subtitle: '1/2× de dano',    entries: half),
              if (quart.isNotEmpty)  _DamageGroup(title: 'Muito resistente a',   subtitle: '1/4× de dano',    entries: quart),
              if (imun.isNotEmpty)   _DamageGroup(title: 'Imune a',              subtitle: '0× de dano',      entries: imun),
            ],
          ),
        ),
      ]),
    );
  }
}

// Dado de uma linha de stat
class _StatRow {
  final String label;
  final int base;
  final Color color;
  final bool isHp;
  const _StatRow(this.label, this.base, this.color, {this.isHp = false});
}

// Linha de stat com animação de aba
class _StatBarRow extends StatelessWidget {
  final BuildContext context;
  final _StatRow row;
  final TabController tabController;
  final int minVal;
  final int maxVal;

  const _StatBarRow({
    required this.context,
    required this.row,
    required this.tabController,
    required this.minVal,
    required this.maxVal,
  });

  @override
  Widget build(BuildContext _) {
    return AnimatedBuilder(
      animation: tabController.animation!,
      builder: (ctx, __) {
        // Interpolação suave entre valores durante a animação
        final anim = tabController.animation!.value;
        final fromIdx = tabController.previousIndex;
        final toIdx   = tabController.index;
        int fromVal = fromIdx == 0 ? row.base : fromIdx == 1 ? minVal : maxVal;
        int toVal   = toIdx   == 0 ? row.base : toIdx   == 1 ? minVal : maxVal;
        final t = (anim - fromIdx).abs().clamp(0.0, 1.0);
        final val = (fromVal + (toVal - fromVal) * t).round();
        return StatBar(label: row.label, value: val, color: row.color);
      },
    );
  }
}

// Grupo de tipos por relação de dano
class _DamageGroup extends StatelessWidget {
  final String title;     // ex: "Fraco contra"
  final String subtitle;  // ex: "2× de dano"
  final List<MapEntry<String, double>> entries;

  const _DamageGroup({
    super.key,
    required this.title,
    required this.subtitle,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 1),
          Text(subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            // TypeBadge usa o tipo em inglês internamente — mesmo padrão da aba Sobre
            children: entries.map((e) => TypeBadge(type: e.key)).toList(),
          ),
        ],
      ),
    );
  }
}
// ─── ABA FORMAS (compartilhada) ──────────────────────────────────

class FormsTab extends StatelessWidget {
  final List<Map<String, dynamic>> forms;
  final bool loading;
  const FormsTab({super.key, required this.forms, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: PokeballLoader.small());

    final altForms = forms.where((f) => !(f['isDefault'] as bool? ?? false)).toList();
    if (altForms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.catching_pokemon_outlined, size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Este Pokémon não possui formas alternativas',
              style: TextStyle(fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
          ]),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemCount: altForms.length,
      itemBuilder: (ctx, i) {
        final f = altForms[i];
        final id = f['id'] as int;
        final name = f['name'] as String;
        final types = (f['types'] as List<dynamic>? ?? []).map((t) => t as String).toList();
        final game = f['game'] as String?;
        final sprite = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
            'sprites/pokemon/other/official-artwork/$id.png';
        final c1 = types.isNotEmpty ? typeColor(types[0]) : Colors.grey;
        final c2 = types.length > 1 ? typeColor(types[1]) : c1;
        return GestureDetector(
          onTap: () => _showFormModal(ctx, id, name, types, game, sprite),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [c1.withOpacity(0.2), c2.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c1.withOpacity(0.3), width: 0.8),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Image.network(sprite, width: 72, height: 72,
                  errorBuilder: (_, __, ___) => const Icon(Icons.catching_pokemon, size: 50)),
              const SizedBox(height: 6),
              Text(_formatFormName(name),
                style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600, fontSize: 11),
                maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Wrap(spacing: 4, children: types.map((t) {
                final tc = typeColor(t);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: tc, borderRadius: BorderRadius.circular(4)),
                  child: Text(ptType(t), style: TextStyle(
                    fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700)),
                );
              }).toList()),
            ]),
          ),
        );
      },
    );
  }

  void _showFormModal(BuildContext context, int id, String name,
      List<String> types, String? game, String sprite) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c1 = types.isNotEmpty ? typeColor(types[0]) : Colors.grey;
    final c2 = types.length > 1 ? typeColor(types[1]) : c1;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2))),
          // Sprite solto, sem caixa
          Image.network(sprite,
            height: 220, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
              const Icon(Icons.catching_pokemon, size: 120)),
          const SizedBox(height: 12),
          // Nome
          Text(_formatFormName(name),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
          const SizedBox(height: 10),
          // Tipos
          Row(mainAxisAlignment: MainAxisAlignment.center,
            children: types.map((t) {
              final tc = typeColor(t);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: tc, borderRadius: BorderRadius.circular(4)),
                child: Text(ptType(t), style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: Colors.white)),
              );
            }).toList()),
        ]),
      ),
    );
  }

  String _formatFormName(String raw) {
    final parts = raw.split('-');
    if (parts.contains('mega')) {
      final idx = parts.indexOf('mega');
      final base = parts.sublist(0, idx).map((p) => _cap(p)).join(' ');
      final rest = parts.sublist(idx + 1).map((p) => _cap(p)).join(' ');
      return 'Mega $base${rest.isNotEmpty ? ' $rest' : ''}';
    }
    if (parts.contains('gmax')) {
      return 'Gigamax ${parts.where((p) => p != 'gmax').map(_cap).join(' ')}';
    }
    return parts.map(_cap).join(' ');
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─── ABA MOVES (compartilhada entre Nacional e Switch) ───────────

class MovesTab extends StatefulWidget {
  final List<Map<String, dynamic>> level, mt, tutor, egg;
  final List<String> pokemonTypes;
  const MovesTab({
    super.key,
    required this.level, required this.mt,
    required this.tutor, required this.egg,
    required this.pokemonTypes,
  });

  @override
  State<MovesTab> createState() => _MovesTabState();
}

class _MovesTabState extends State<MovesTab> {
  String _method = 'level';
  Map<String, dynamic>? _selectedMove;
  Map<String, dynamic>? _moveDetail;
  String _moveDescPt = '';
  bool _loadingMove = false;

  List<Map<String, dynamic>> get _currentMoves {
    switch (_method) {
      case 'mt':    return widget.mt;
      case 'tutor': return widget.tutor;
      case 'egg':   return widget.egg;
      default:      return widget.level;
    }
  }

  Future<void> _openMove(Map<String, dynamic> move) async {
    setState(() { _selectedMove = move; _loadingMove = true; _moveDetail = null; _moveDescPt = ''; });
    try {
      final r = await http.get(Uri.parse(move['url'] as String));
      if (r.statusCode == 200 && mounted) {
        final detail = json.decode(r.body) as Map<String, dynamic>;

        // Extrair descrição EN e traduzir antes de mostrar o modal
        String descEn = '';
        final flavors = detail['flavor_text_entries'] as List<dynamic>? ?? [];
        String ptDesc = '', enDesc = '';
        for (final e in flavors) {
          final lang = e['language']['name'] as String;
          if (lang == 'pt-BR' && ptDesc.isEmpty) ptDesc = (e['flavor_text'] as String? ?? '').replaceAll('\n', ' ').replaceAll('\f', ' ').trim();
          else if (lang == 'en' && enDesc.isEmpty) enDesc = (e['flavor_text'] as String? ?? '').replaceAll('\n', ' ').replaceAll('\f', ' ').trim();
        }
        if (ptDesc.isNotEmpty) {
          descEn = ''; // já tem PT nativo
          _moveDescPt = ptDesc;
        } else if (enDesc.isNotEmpty) {
          descEn = enDesc;
        } else {
          for (final e in (detail['effect_entries'] as List<dynamic>? ?? [])) {
            if ((e['language']['name'] as String) == 'en') {
              descEn = (e['short_effect'] as String? ?? '').trim(); break;
            }
          }
        }

        // Traduzir EN se necessário — feito antes de atualizar o state
        if (descEn.isNotEmpty) {
          _moveDescPt = await translateFlavorText(descEn);
        }

        if (mounted) setState(() { _moveDetail = detail; _loadingMove = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMove = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tColor = widget.pokemonTypes.isNotEmpty
        ? typeColor(widget.pokemonTypes[0])
        : const Color(0xFF9E9E9E);

    return Stack(children: [
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        child: SectionCard(
          title: 'GOLPES',
          pokemonTypes: widget.pokemonTypes,
          child: Column(children: [
            const SizedBox(height: 4),

            // ── Filtros — ocupam toda a largura ──
            Row(
              children: [
                for (final e in [('level','Nível'),('mt','MT'),('tutor','Tutor'),('egg','Ovo')]) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _method = e.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: _method == e.$1
                              ? tColor
                              : tColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _method == e.$1
                                ? tColor
                                : tColor.withOpacity(0.35),
                            width: 1,
                          ),
                        ),
                        child: Text(e.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: _method == e.$1
                              ? typeTextColor(tColor)
                              : tColor,
                        )),
                      ),
                    ),
                  ),
                  if (e.$1 != 'egg') const SizedBox(width: 5),
                ],
              ],
            ),

            const SizedBox(height: 10),

            // ── Legenda de categoria ──
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CatLegend(category: 'physical', label: 'Físico'),
                  const SizedBox(width: 16),
                  _CatLegend(category: 'special',  label: 'Especial'),
                  const SizedBox(width: 16),
                  _CatLegend(category: 'status',   label: 'Status'),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Divider(height: 1, color: tColor.withOpacity(0.2)),
            const SizedBox(height: 4),

            // ── Cabeçalho de colunas ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(children: [
                // Nível: mesma largura da coluna de dados (28 level / 36 mt) + gap de 8
                SizedBox(
                  width: _method == 'level' ? 28 : 36,
                  child: Text(
                    _method == 'level' ? 'Nível' : _method == 'mt' ? 'MT' : '',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF888888),
                      letterSpacing: 0.3, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
                ),
                const SizedBox(width: 8),
                // Tipo: centralizado sobre ícone tipo (32) + gap (6) + ícone cat (41) = 79px
                SizedBox(
                  width: 79,
                  child: const Text('Tipo', style: TextStyle(fontSize: 11,
                    color: Color(0xFF888888), letterSpacing: 0.3,
                    fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                const SizedBox(width: 8),
                // Golpe: Expanded igual à coluna de dados
                const Expanded(child: Text('Golpe', style: TextStyle(fontSize: 11,
                  color: Color(0xFF888888), letterSpacing: 0.3,
                  fontWeight: FontWeight.w700))),
                // Poder: mesma largura da coluna de dados (36)
                const SizedBox(width: 36,
                  child: Text('Poder', style: TextStyle(fontSize: 11,
                    color: Color(0xFF888888), letterSpacing: 0.3,
                    fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
              ]),
            ),

            Divider(height: 1, color: tColor.withOpacity(0.2)),

            // ── Lista de moves ──
            if (_currentMoves.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(
                  widget.level.isEmpty ? 'Carregando...' : 'Nenhum golpe',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13),
                )),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: _currentMoves.length,
                separatorBuilder: (_, __) => Divider(
                  height: 0.5, color: tColor.withOpacity(0.15)),
                itemBuilder: (ctx, i) => MoveRow(
                  move: _currentMoves[i],
                  method: _method,
                  onTap: () => _openMove(_currentMoves[i]),
                ),
              ),
          ]),
        ),
      ),
      if (_selectedMove != null)
        MoveModal(
          move: _selectedMove!,
          detail: _moveDetail,
          descPt: _moveDescPt,
          loading: _loadingMove,
          onClose: () => setState(() { _selectedMove = null; _moveDetail = null; _moveDescPt = ''; }),
        ),
    ]);
  }
}

// ─── LEGENDA DE CATEGORIA ─────────────────────────────────────────

class _CatLegend extends StatelessWidget {
  final String category, label;
  const _CatLegend({required this.category, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Image.asset(
        'assets/categories/$category.png',
        width: 37, height: 16,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          width: 16, height: 16,
          decoration: BoxDecoration(
            color: category == 'physical'
                ? const Color(0xFFE24B4A).withOpacity(0.15)
                : category == 'special'
                    ? const Color(0xFF9C27B0).withOpacity(0.15)
                    : const Color(0xFF888888).withOpacity(0.15),
            borderRadius: BorderRadius.circular(3)),
          child: CustomPaint(painter: CatIconPainter(category)),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }
}

// ─── MOVE ROW ────────────────────────────────────────────────────

class MoveRow extends StatefulWidget {
  final Map<String, dynamic> move;
  final String method;
  final VoidCallback onTap;
  const MoveRow({super.key, required this.move, required this.method, required this.onTap});

  @override
  State<MoveRow> createState() => _MoveRowState();
}

class _MoveRowState extends State<MoveRow> {
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse(widget.move['url'] as String));
      if (r.statusCode == 200 && mounted) {
        setState(() => _detail = json.decode(r.body));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final nameEn = widget.move['name'] as String;
    // Tradução local — garantida para todos os moves do mapa
    final namePt  = translateMove(nameEn);
    final level   = widget.move['level'] as int;
    final typeEn = _detail?['type']?['name'] as String? ?? '';
    final tColor = typeEn.isNotEmpty ? typeColor(typeEn) : const Color(0xFF9E9E9E);
    final catName = _detail?['damage_class']?['name'] as String? ?? '';
    final power = _detail?['power'] as int?;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          SizedBox(
            width: widget.method == 'level' ? 28 : 36,
            child: Text(
              widget.method == 'level' ? (level > 0 ? '$level' : '1')
                  : widget.method == 'mt' ? level.toString().padLeft(3, '0') : '',
              style: TextStyle(fontSize: widget.method == 'level' ? 11 : 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          // Ícone de tipo — mesmo padrão da aba Sobre/Status
          SizedBox(
            width: 32,
            child: typeEn.isEmpty
                ? Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16)),
                  )
                : Image.asset(
                    typeIconAsset(typeEn),
                    width: 32, height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 32),
                  ),
          ),
          const SizedBox(width: 6),
          // Ícone de categoria
          Image.asset(
            catName.isEmpty ? 'assets/categories/status.png'
                : 'assets/categories/$catName.png',
            width: 41, height: 18,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                color: catName == 'physical'
                    ? const Color(0xFFE24B4A).withOpacity(0.15)
                    : catName == 'special'
                        ? const Color(0xFF9C27B0).withOpacity(0.15)
                        : const Color(0xFF888888).withOpacity(0.15),
                borderRadius: BorderRadius.circular(3)),
              child: CustomPaint(painter: CatIconPainter(catName)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: BilingualTerm(
            namePt: namePt,
            nameEn: nameEn,
          )),
          SizedBox(width: 36, child: Text(
            power != null ? '$power' : '—',
            style: TextStyle(fontSize: 11,
              color: power == null ? Theme.of(context).colorScheme.onSurfaceVariant : null),
            textAlign: TextAlign.center, maxLines: 1,
          )),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.chevron_right, size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ]),
      ),
    );
  }
}

// ─── MOVE MODAL ──────────────────────────────────────────────────

class MoveModal extends StatelessWidget {
  final Map<String, dynamic> move;
  final Map<String, dynamic>? detail;
  final String descPt;   // já traduzido antes de abrir o modal
  final bool loading;
  final VoidCallback onClose;
  const MoveModal({super.key, required this.move, required this.detail,
    required this.descPt, required this.loading, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final nameEn = move['name'] as String;
    final namePt = translateMove(nameEn);
    final typeEn = detail?['type']?['name'] as String? ?? '';
    final catName = detail?['damage_class']?['name'] as String? ?? '';
    final power = detail?['power'];
    final acc = detail?['accuracy'];
    final pp = detail?['pp'];
    final level = move['level'] as int;
    final method = move['method'] as String;

    // Descrição já traduzida — recebida via descPt do _openMove

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black54,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2)))),
              // Título: respeita a configuração de idioma do usuário via BilingualTerm
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: BilingualTerm(
                  namePt: namePt,
                  nameEn: nameEn,
                  baseStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  secondaryStyle: const TextStyle(fontSize: 13),
                )),
                GestureDetector(onTap: onClose,
                  child: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                // Tipo — TypeBadge padrão do projeto (ícone PNG + cor + nome PT)
                if (typeEn.isNotEmpty) TypeBadge(type: typeEn),
                const SizedBox(width: 8),
                // Categoria — ícone PNG proporcional, sem forma oval
                if (catName.isNotEmpty) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: catName == 'physical' ? const Color(0xFFE24B4A).withOpacity(0.12)
                        : catName == 'special' ? const Color(0xFF9C27B0).withOpacity(0.12)
                        : const Color(0xFF888888).withOpacity(0.12),
                    borderRadius: BorderRadius.zero,
                    border: Border.all(
                      color: catName == 'physical' ? const Color(0xFFE24B4A).withOpacity(0.4)
                          : catName == 'special' ? const Color(0xFF9C27B0).withOpacity(0.4)
                          : const Color(0xFF888888).withOpacity(0.4))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset('assets/categories/$catName.png',
                      width: 41, height: 18, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                    const SizedBox(width: 6),
                    Text(
                      catName == 'physical' ? 'Físico'
                          : catName == 'special' ? 'Especial' : 'Status',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: catName == 'physical' ? const Color(0xFFE24B4A)
                            : catName == 'special' ? const Color(0xFF9C27B0)
                            : const Color(0xFF666666))),
                  ])),
              ]),
              const SizedBox(height: 12),
              if (loading)
                const Center(child: PokeballLoader.small())
              else
                Row(children: [
                  _statBox(context, power != null ? '$power' : '—', 'Poder'),
                  const SizedBox(width: 8),
                  _statBox(context, acc != null ? '$acc%' : '—', 'Precisão'),
                  const SizedBox(width: 8),
                  _statBox(context, pp != null ? '$pp' : '—', 'PP'),
                ]),
              const SizedBox(height: 12),
              if (descPt.isNotEmpty) Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8)),
                child: Text(descPt, style: TextStyle(fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5))),
              const SizedBox(height: 8),
              Text(
                method == 'level-up' && level > 0 ? 'Aprendido no nível $level'
                    : method == 'machine' ? 'Aprendido via MT'
                    : method == 'tutor' ? 'Aprendido via Tutor'
                    : method == 'egg' ? 'Move de Ovo' : '',
                style: TextStyle(fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _statBox(BuildContext ctx, String val, String lbl) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(lbl, style: TextStyle(fontSize: 10,
          color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
      ]),
    ),
  );
}

// ─── ABILITY CARD (compartilhado) ────────────────────────────────

class AbilityCard extends StatelessWidget {
  final String nameEn, namePt, description;
  final bool isHidden;
  const AbilityCard({
    super.key,
    required this.nameEn, required this.namePt,
    required this.description, required this.isHidden,
  });

  String get _displayName => namePt.isNotEmpty ? namePt
      : nameEn[0].toUpperCase() + nameEn.substring(1).replaceAll('-', ' ');
  String get _enLabel =>
      nameEn[0].toUpperCase() + nameEn.substring(1).replaceAll('-', ' ');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hiddenBg   = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFDDDDDD);
    final hiddenText = isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              BilingualTerm(
                namePt: namePt,
                nameEn: nameEn,
                baseStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              if (isHidden) Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: hiddenBg, borderRadius: BorderRadius.circular(4)),
                child: Text('Oculta',
                  style: TextStyle(color: hiddenText, fontSize: 10, fontWeight: FontWeight.w500)),
              ),
            ],
          )),
        ]),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(description, style: TextStyle(fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4)),
        ],
      ]),
    );
  }
}

// ─── EVO CHAIN (compartilhado) ───────────────────────────────────

// ─── MAPA POKEDEX → GAME LABEL ──────────────────────────────────
// Mapeia pokedexId para o label usado no campo 'games' do pokedex_data.json.
// null = sem filtro (nacional).
const Map<String, String?> _pokedexToGame = {
  'red___blue':                     'Red / Blue',
  'gold___silver':                  'Gold / Silver',
  'ruby___sapphire':                'Ruby / Sapphire',
  'firered___leafgreen_(gba)':      'Red / Blue',
  'emerald':                        'Emerald',
  'diamond___pearl':                'Diamond / Pearl',
  'platinum':                       'Platinum',
  'heartgold___soulsilver':         'HeartGold / SoulSilver',
  'black___white':                  'Black / White',
  'black_2___white_2':              'Black 2 / White 2',
  'x___y':                          'X / Y',
  'omega_ruby___alpha_sapphire':    'Ruby / Sapphire',
  'sun___moon':                     'Sun / Moon',
  'ultra_sun___ultra_moon':         'Ultra Sun / Ultra Moon',
  'lets_go_pikachu___eevee':        "Let's Go Pikachu / Eevee",
  'sword___shield':                 'Sword / Shield',
  'brilliant_diamond___shining_pearl': 'Diamond / Pearl',
  'legends_arceus':                 'Legends: Arceus',
  'scarlet___violet':               'Scarlet / Violet',
  'legends_z-a':                    'Scarlet / Violet',
  'pokémon_go':                     'Pokémon GO',
  'pokopia':                        'Pokopia',
  'pokopia_event':                  'Pokopia',
  'nacional':                       null,
};

/// Filtra o evoChain para conter apenas membros disponíveis no jogo ativo.
/// Se pokedexId for 'nacional' ou não mapeado, retorna o chain completo.
List<Map<String, dynamic>> filterEvoChainForGame(
    List<Map<String, dynamic>> chain, String pokedexId) {
  final game = _pokedexToGame[pokedexId];
  if (game == null) return chain; // nacional: sem filtro
  return chain.where((e) {
    final games = PokedexDataService.instance.getGames(e['id'] as int);
    return games.contains(game);
  }).toList();
}

class EvoChainWidget extends StatefulWidget {
  final List<Map<String, dynamic>> chain;
  final String pokedexId;
  const EvoChainWidget({super.key, required this.chain, required this.pokedexId});

  @override
  State<EvoChainWidget> createState() => _EvoChainWidgetState();
}

class _EvoChainWidgetState extends State<EvoChainWidget> {
  // id → lista de tipos EN
  final Map<int, List<String>> _typesCache = {};

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  @override
  void didUpdateWidget(EvoChainWidget old) {
    super.didUpdateWidget(old);
    if (old.chain != widget.chain) _loadTypes();
  }

  Future<void> _loadTypes() async {
    for (final e in widget.chain) {
      final id = e['id'] as int;
      if (_typesCache.containsKey(id) || id == 0) continue;
      // Se o chain já trouxe os tipos (nacional/switch), usa direto
      final preloaded = e['types'];
      if (preloaded is List && preloaded.isNotEmpty) {
        _typesCache[id] = List<String>.from(preloaded);
        continue;
      }
      // Fallback: busca da API (GO, pokopia, etc)
      try {
        final r = await http.get(Uri.parse('$kApiBase/pokemon/$id'));
        if (r.statusCode == 200 && mounted) {
          final d = json.decode(r.body) as Map<String, dynamic>;
          final types = (d['types'] as List<dynamic>)
              .map((t) => t['type']['name'] as String)
              .toList();
          setState(() => _typesCache[id] = types);
        }
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filterEvoChainForGame(widget.chain, widget.pokedexId);
    if (filtered.length <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildWidgets(context, filtered),
    );
  }

  List<Widget> _buildWidgets(BuildContext ctx, List<Map<String, dynamic>> filtered) {
    final ws = <Widget>[];
    for (int i = 0; i < filtered.length; i++) {
      final e = filtered[i];
      final id   = e['id'] as int;
      final name = e['name'] as String;
      final displayName = name[0].toUpperCase() + name.substring(1);
      final numStr = '#${id.toString().padLeft(3, '0')}';
      final sprite = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
          'sprites/pokemon/other/official-artwork/$id.png';
      final types = _typesCache[id] ?? [];

      ws.add(Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              sprite,
              width: 64, height: 64,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.catching_pokemon, size: 48),
            ),
            const SizedBox(height: 4),
            // Número
            Text(numStr, style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w500,
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              letterSpacing: 0.3)),
            const SizedBox(height: 1),
            // Nome
            Text(displayName,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
            const SizedBox(height: 4),
            if (types.isNotEmpty)
              Wrap(
                spacing: 3, runSpacing: 3,
                alignment: WrapAlignment.center,
                children: types.map((t) {
                  final tc = typeColor(t);
                  return SizedBox(
                    width: 72, height: 18,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: tc),
                      child: Row(children: [
                        Image.asset(typeIconAsset(t), width: 18, height: 18),
                        Expanded(child: Text(ptType(t),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9, color: Colors.white,
                            fontWeight: FontWeight.w700))),
                      ]),
                    ),
                  );
                }).toList(),
              )
            else
              const SizedBox(height: 18),
          ],
        ),
      ));

      if (i < filtered.length - 1) {
        final cond = filtered[i + 1]['condition'] as String;
        ws.add(SizedBox(
          width: 32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24), // alinha com o meio do sprite
              Icon(Icons.chevron_right, size: 18,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              if (cond.isNotEmpty)
                Text(cond,
                  style: TextStyle(fontSize: 10,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                  maxLines: 2),
            ],
          ),
        ));
      }
    }
    return ws;
  }
}

// ─── STAT BAR (compartilhada) ────────────────────────────────────

class StatBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const StatBar({super.key, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 88, child: Text(label, style: TextStyle(fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant))),
        SizedBox(width: 34, child: Text('$value',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          textAlign: TextAlign.right)),
        const SizedBox(width: 8),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: LinearProgressIndicator(
            value: value / 255,
            minHeight: 10,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        )),
      ]),
    );
  }
}

// ─── ÍCONE DE CATEGORIA ──────────────────────────────────────────

class CatIconPainter extends CustomPainter {
  final String category;
  const CatIconPainter(this.category);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    if (category == 'physical') {
      final paint = Paint()..color = const Color(0xFFE24B4A);
      canvas.drawPath(Path()
        ..moveTo(cx - 4, cy + 3)..lineTo(cx - 4, cy - 2)
        ..lineTo(cx - 2, cy - 4)..lineTo(cx + 2, cy - 4)
        ..lineTo(cx + 4, cy - 2)..lineTo(cx + 4, cy + 3)..close(), paint);
    } else if (category == 'special') {
      canvas.drawCircle(Offset(cx, cy), 4.5, Paint()..color = const Color(0xFF378ADD));
    } else {
      canvas.drawPath(Path()
        ..moveTo(cx, cy - 5)..lineTo(cx + 4, cy)
        ..lineTo(cx, cy + 5)..lineTo(cx - 4, cy)..close(),
        Paint()..color = const Color(0xFFB8B8D0));
    }
  }

  @override bool shouldRepaint(_) => false;
}

class CatLegendItem extends StatelessWidget {
  final String category, label;
  const CatLegendItem({super.key, required this.category, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 14, height: 14,
        decoration: BoxDecoration(
          color: category == 'physical' ? const Color(0xFFE24B4A).withOpacity(0.15)
              : category == 'special' ? const Color(0xFF9C27B0).withOpacity(0.15)
              : const Color(0xFF888888).withOpacity(0.15),
          borderRadius: BorderRadius.circular(3)),
        child: CustomPaint(painter: CatIconPainter(category)),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 9,
        color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }
}

// ─── TABELA DE FRAQUEZAS ─────────────────────────────────────────

Map<String, double> calculateWeaknesses(List<String> types) {
  const tc = {
    'normal':   {'fighting': 2.0, 'ghost': 0.0},
    'fire':     {'water': 2.0, 'rock': 2.0, 'ground': 2.0, 'fire': 0.5, 'grass': 0.5, 'ice': 0.5, 'bug': 0.5, 'steel': 0.5, 'fairy': 0.5},
    'water':    {'electric': 2.0, 'grass': 2.0, 'fire': 0.5, 'water': 0.5, 'ice': 0.5, 'steel': 0.5},
    'electric': {'ground': 2.0, 'electric': 0.5, 'flying': 0.5, 'steel': 0.5},
    'grass':    {'fire': 2.0, 'ice': 2.0, 'poison': 2.0, 'flying': 2.0, 'bug': 2.0, 'water': 0.5, 'electric': 0.5, 'grass': 0.5, 'ground': 0.5},
    'ice':      {'fire': 2.0, 'fighting': 2.0, 'rock': 2.0, 'steel': 2.0, 'ice': 0.5},
    'fighting': {'flying': 2.0, 'psychic': 2.0, 'fairy': 2.0, 'rock': 0.5, 'bug': 0.5, 'dark': 0.5},
    'poison':   {'ground': 2.0, 'psychic': 2.0, 'fighting': 0.5, 'poison': 0.5, 'bug': 0.5, 'grass': 0.5, 'fairy': 0.5},
    'ground':   {'water': 2.0, 'grass': 2.0, 'ice': 2.0, 'electric': 0.0, 'poison': 0.5, 'rock': 0.5},
    'flying':   {'electric': 2.0, 'ice': 2.0, 'rock': 2.0, 'ground': 0.0, 'fighting': 0.5, 'bug': 0.5, 'grass': 0.5},
    'psychic':  {'bug': 2.0, 'ghost': 2.0, 'dark': 2.0, 'fighting': 0.5, 'psychic': 0.5},
    'bug':      {'fire': 2.0, 'flying': 2.0, 'rock': 2.0, 'fighting': 0.5, 'ground': 0.5, 'grass': 0.5},
    'rock':     {'water': 2.0, 'grass': 2.0, 'fighting': 2.0, 'ground': 2.0, 'steel': 2.0, 'normal': 0.5, 'fire': 0.5, 'poison': 0.5, 'flying': 0.5},
    'ghost':    {'ghost': 2.0, 'dark': 2.0, 'normal': 0.0, 'fighting': 0.0, 'poison': 0.5, 'bug': 0.5},
    'dragon':   {'ice': 2.0, 'dragon': 2.0, 'fairy': 2.0, 'fire': 0.5, 'water': 0.5, 'electric': 0.5, 'grass': 0.5},
    'dark':     {'fighting': 2.0, 'bug': 2.0, 'fairy': 2.0, 'ghost': 0.5, 'dark': 0.5, 'psychic': 0.0},
    'steel':    {'fire': 2.0, 'fighting': 2.0, 'ground': 2.0, 'normal': 0.5, 'grass': 0.5, 'ice': 0.5, 'flying': 0.5, 'psychic': 0.5, 'bug': 0.5, 'rock': 0.5, 'dragon': 0.5, 'steel': 0.5, 'fairy': 0.5, 'poison': 0.0},
    'fairy':    {'poison': 2.0, 'steel': 2.0, 'fighting': 0.5, 'bug': 0.5, 'dark': 0.5, 'dragon': 0.0},
  };
  // Inicializa todos os 18 tipos com ×1 (dano normal)
  const allTypes = ['normal','fire','water','electric','grass','ice','fighting',
    'poison','ground','flying','psychic','bug','rock','ghost','dragon','dark','steel','fairy'];
  final mults = <String, double>{for (final t in allTypes) t: 1.0};
  for (final type in types) {
    for (final entry in (tc[type.toLowerCase()] ?? {}).entries) {
      mults[entry.key] = (mults[entry.key] ?? 1.0) * entry.value;
    }
  }
  return mults;
}

// função com _ para compatibilidade interna
Map<String, double> _calculateWeaknesses(List<String> types) => calculateWeaknesses(types);

// ─── LOCALIZAÇÃO: NOME DO JOGO ────────────────────────────────────

String encounterGameName(String raw) {
  const map = {
    'red': 'Red', 'blue': 'Blue', 'yellow': 'Yellow',
    'Gold': 'Gold', 'Silver': 'Silver', 'crystal': 'Crystal',
    'ruby': 'Ruby', 'sapphire': 'Sapphire', 'firered': 'FireRed',
    'leafgreen': 'LeafGreen', 'emerald': 'Emerald',
    'diamond': 'Diamond', 'pearl': 'Pearl', 'platinum': 'Platinum',
    'heartgold': 'HeartGold', 'soulsilver': 'SoulSilver',
    'black': 'Black', 'white': 'White', 'black2': 'Black 2', 'white2': 'White 2',
    'x': 'X', 'y': 'Y', 'omegaRuby': 'Omega Ruby', 'alphaSapphire': 'Alpha Sapphire',
    'Sun': 'Sun', 'Moon': 'Moon', 'ultraSun': 'Ultra Sun', 'ultraMoon': 'Ultra Moon',
    'letsGoPikachu': "Let's Go Pikachu", 'letsGoEevee': "Let's Go Eevee",
    'Sword': 'Sword', 'Shield': 'Shield',
    'brilliandDiamond': 'Brilliant Diamond', 'shiningPearl': 'Shining Pearl',
    'legendsArceus': 'Legends: Arceus',
    'Scarlet': 'Scarlet', 'Violet': 'Violet',
    'legendsZA': 'Legends: Z-A',
  };
  return map[raw] ?? raw;
}

// ─── LOCALIZAÇÃO: NOME DO MÉTODO ─────────────────────────────────

String encounterMethodPt(String method) {
  const map = {
    // PokéAPI (snake_case)
    'walk': 'Caminhando', 'surf': 'Surfando',
    'old-rod': 'Vara Velha', 'good-rod': 'Vara Boa', 'super-rod': 'Super Vara',
    'gift': 'Presente', 'gift-egg': 'Presente (ovo)', 'only-one': 'Único',
    'rock-smash': 'Quebra-Pedra', 'headbutt': 'Headbutt',
    'pokeradar': 'PokéRadar', 'slot2': 'Slot 2', 'trade': 'Troca',
    'special': 'Especial', 'dark-grass': 'Grama Alta', 'squirt-bottle': 'Regador',
    'grass-spots': 'Grama', 'surf-spots': 'Surf', 'super-rod-spots': 'Super Vara',
    'cave-spots': 'Caverna', 'bridge-spots': 'Ponte', 'rough-terrain': 'Terreno Acidentado',
    'yellow-flowers': 'Flores Amarelas', 'purple-flowers': 'Flores Roxas',
    'red-flowers': 'Flores Vermelhas', 'pokeflute': 'Poké Flauta',
    'wailmer-pail': 'Regador Wailmer', 'seaweed': 'Algas', 'swamp': 'Pântano',
    // CTA Dex (Title Case / sentence)
    'Walking / Grass': 'Grama', 'Walking / Cave': 'Caverna',
    'Walking / Sand': 'Areia', 'Walking / Water': 'Água',
    'Walking / Grass - SOS only': 'Grama (SOS)',
    'Grass': 'Grama', 'Grass - Rare Spawns': 'Grama (Raro)',
    'Tall Grass': 'Grama Alta', 'Shaking Grass': 'Grama Agitada',
    'Shaking Grass - SOS only': 'Grama Agitada (SOS)',
    'Overworld': 'Overworld', 'Wandering': 'Errante',
    'Wandering Surf': 'Surf Errante', 'Roaming': 'Errante',
    'Roaming in Grass': 'Errante (Grama)', 'Roaming in the Cave': 'Errante (Caverna)',
    'Roaming in the Grass': 'Errante (Grama)',
    'Random': 'Aleatório', 'Random Encounter': 'Encontro Aleatório',
    'Static': 'Estático', 'Interact': 'Interação',
    'Surfing': 'Surfando', 'Surf': 'Surfando',
    'Fishing': 'Pescando', 'Fish': 'Pescando',
    'Fish - SOS only': 'Pescando (SOS)', 'Fish Special': 'Pesca Especial',
    'Fish Special - SOS only': 'Pesca Especial (SOS)',
    'Old Rod': 'Vara Velha', 'Good Rod': 'Vara Boa', 'Super Rod': 'Super Vara',
    'Water': 'Água', 'Water - Rare Spawns': 'Água (Raro)',
    'Underground': 'Subterrâneo', 'Curry': 'Curry',
    'Gift': 'Presente', 'Starter Pokémon': 'Inicial', 'Starter Pokemon': 'Inicial',
    'Headbutt': 'Headbutt', 'Headbutt N.': 'Headbutt (Norte)',
    'Headbutt Sp.': 'Headbutt (Especial)', 'Rock Smash': 'Quebra-Pedra',
    'Honey Tree': 'Árvore de Mel', 'Honey Tree - Rare': 'Mel (Raro)',
    'Honey Tree - Very Rare': 'Mel (Muito Raro)', 'Berry Tree': 'Árvore de Fruta',
    'Berry': 'Fruta', 'DexNav': 'DexNav',
    'Swarm': 'Enxame', 'Horde': 'Horda', 'Island Scan': 'Island Scan', 'PokeRadar': 'PokéRadar',
    'Weather SOS Battle': 'Batalha SOS (Clima)', 'Shaking Trees': 'Árvore Agitada',
    'Shaking Trees - SOS only': 'Árvore Agitada (SOS)',
    'In the Sky': 'No Ar', 'In the Sky - Rare Spawns': 'No Ar (Raro)',
    'Flying': 'Voando', 'Wimpod': 'Wimpod', 'Sharpedo': 'Sharpedo',
    'Raid Battle': 'Raid', 'Dynamax Adventure': 'Aventura Dynamax',
    'Mass Outbreak': 'Surto em Massa', 'Alpha': 'Alpha',
    'Trade': 'Troca', 'Evolution': 'Evolução', 'Evolve': 'Evolução',
    'Evolve Charmander': 'Evolução', 'From totem after completion of game': 'Totem',
    'Requires Entei & Raikou': 'Evento', 'Requires Kyogre & Groudon': 'Evento',
    'Requires Dialga & Palkia': 'Evento', 'Requires Tornadus & Thundurus': 'Evento',
    'Requires Reshiram & Zekrom': 'Evento', 'Shaking': 'Agitando',
  };
  if (map.containsKey(method)) return map[method]!;
  if (method.isEmpty) return '';
  return method[0].toUpperCase() + method.substring(1);
}

String normalizeLocationName(String location) {
  var s = location;

  // Route N → Rota N
  s = s.replaceAllMapped(
    RegExp(r'\bRoute\s+(\d+)\b', caseSensitive: false),
    (m) => 'Rota ${m.group(1)}',
  );

  // Hatch from Egg [in/at X]
  s = s.replaceFirstMapped(
    RegExp(r'^Hatch(?:ed)? from [Ee]gg(?:\s+(?:in|at)\s+(.+))?$'),
    (m) => m.group(1) != null ? 'Chocar ovo em ${m.group(1)}' : 'Chocar ovo',
  );

  // Revive from / Revive a X Fossil
  s = s.replaceFirstMapped(
    RegExp(r'^Revive(?:\s+a?)?\s+(.+?)\s+[Ff]ossil$'),
    (m) => 'Reviver: Fóssil ${m.group(1)}',
  );

  // Soaring in the Sky
  s = s.replaceFirst('Soaring in the Sky', 'Voando no Céu');

  // Gift in X
  s = s.replaceFirstMapped(
    RegExp(r'^Gift in (.+)$'),
    (m) => 'Presente em ${m.group(1)}',
  );

  // (Gift - From X) inline
  s = s.replaceAllMapped(
    RegExp(r'\(Gift - From (.+?)\)'),
    (m) => '(Presente de ${m.group(1)})',
  );

  // QR Code Required
  s = s.replaceAll('(QR Code Required)', '(QR Code necessário)');
  s = s.replaceAll('QR Code Required', 'QR Code necessário');

  // Specific Gen-I transfer strings (before generic Transfer from)
  s = s.replaceFirst(
    'Transfer from Red, Green, Blue or Yellow', 'Via Red, Green, Blue ou Yellow');
  s = s.replaceFirst(
    'Transfer from Red, Green, Blue, or Yellow', 'Via Red, Green, Blue ou Yellow');
  s = s.replaceFirst(
    'Transfer from Gold, Silver, or Crystal', 'Via Gold, Silver ou Crystal');

  // Transfer phrases (generic, after specifics)
  s = s.replaceFirst('Transfer or receive from event', 'Transferência ou evento');
  s = s.replaceFirst('Transfer required', 'Transferência necessária');
  s = s.replaceFirst(RegExp(r'^Transfer (?:from|through) '), 'Via ');

  // Migrate from X
  s = s.replaceFirstMapped(
    RegExp(r'^Migrate(?:d)? from (.+)$'),
    (m) => 'Via ${m.group(1)}',
  );

  // Trade in X → Troca em X
  s = s.replaceFirstMapped(
    RegExp(r'^[Tt]rade in (.+)$'),
    (m) => 'Troca em ${m.group(1)}',
  );
  // Trade from X → Troca de X
  s = s.replaceFirstMapped(
    RegExp(r'^[Tt]rade from (.+)$'),
    (m) => 'Troca de ${m.group(1)}',
  );

  // Gift from X in Y (before generic Gift from X)
  s = s.replaceFirstMapped(
    RegExp(r'^Gift from (.+?) in ([^\n]+)'),
    (m) => 'Presente de ${m.group(1)} em ${m.group(2)}',
  );
  // Gift from X
  s = s.replaceFirst(RegExp(r'^Gift from '), 'Presente de ');

  // Event / Receive
  s = s.replaceFirst('Receive from event', 'Recebido por evento');
  if (s == 'Event Only') return 'Somente evento';
  if (s == 'Event Raid') return 'Raid de evento';
  if (s == 'Mystery Gift Quest') return 'Quest de Mystery Gift';
  if (s == 'Pokemon League') return 'Liga Pokémon';

  // Max Raid Battle prefixes
  s = s.replaceAll('Gigantamax Raid Battles:', 'Raids Gigamax:');
  s = s.replaceAll('Max Raid Battles:', 'Raids:');

  // Pokemon proper nouns
  s = s.replaceAll('Pokemon Center', 'Centro Pokémon');
  s = s.replaceFirst('Pokemon Mansion', 'Mansão Pokémon');
  s = s.replaceFirst('Pokemon Tower', 'Torre Pokémon');
  s = s.replaceFirst('Safari Zone', 'Zona Safari');
  s = s.replaceFirst('Pokemon Ranch', 'Fazenda Pokémon');

  // Lake X → Lago X
  s = s.replaceAllMapped(
    RegExp(r'\bLake\s+(\S+)\b'),
    (m) => 'Lago ${m.group(1)}',
  );

  // X Forest → Floresta de X
  s = s.replaceAllMapped(
    RegExp(r'(\S+) Forest\b'),
    (m) => 'Floresta de ${m.group(1)}',
  );

  // Remove sufixos " City" / " Town" — redundantes em nomes de cidades
  s = s.replaceAll(RegExp(r'\s+(City|Town)\b'), '');

  return s;
}

String encounterTimePt(String time) {
  const map = {
    'Day': 'Dia', 'day': 'Dia', 'All Day': 'Dia Todo', 'All': 'Sempre',
    'Morning': 'Manhã', 'morning': 'Manhã', 'Night': 'Noite', 'night': 'Noite',
    'spring': 'Primavera', 'summer': 'Verão', 'autumn': 'Outono', 'winter': 'Inverno',
    'swarm-yes': 'Com Enxame', 'swarm-no': 'Sem Enxame',
    'swarm-no ,morning': 'Sem Enxame (Manhã)', 'swarm-no ,night': 'Sem Enxame (Noite)',
    'radar-on': 'Radar Ativo', 'radar-off': 'Sem Radar',
    'radio-hoenn': 'Rádio Hoenn', 'radio-sinnoh': 'Rádio Sinnoh', 'radio-off': 'Sem Rádio',
    'day ,radio-off': 'Dia (Sem Rádio)', 'morning ,radio-off': 'Manhã (Sem Rádio)',
    'night ,radio-off': 'Noite (Sem Rádio)',
    'slot2-none': 'Slot 2 Vazio', 'slot2-ruby': 'Slot 2: Ruby',
    'slot2-sapphire': 'Slot 2: Sapphire', 'slot2-emerald': 'Slot 2: Emerald',
    'slot2-firered': 'Slot 2: FireRed', 'slot2-leafgreen': 'Slot 2: LeafGreen',
  };
  return map[time] ?? time;
}

String encounterWeatherPt(String weather) {
  const map = {
    'All Weather': '', 'No Weather': '',
    'Day': 'Dia', 'Morning': 'Manhã', 'Night': 'Noite', 'All Day': 'Dia Todo',
    'Beginning': 'Início', 'Defog Obtained': 'Defog Obtido',
    'Fog': 'Névoa', 'Icicle Badge Obtained': 'Medalha Icicle',
    'Intense Sun': 'Sol Intenso', 'Harsh Sunlight': 'Sol Intenso',
    'National Pokedex': 'Pokédex Nacional',
    'Normal Weather': 'Clima Normal', 'Overcast': 'Nublado',
    'Rain': 'Chuva', 'Raining': 'Chuva', 'Rare Spawn': 'Aparição Rara',
    'Sandstorm': 'Tempestade de Areia',
    'Snow': 'Neve', 'Snowing': 'Neve', 'Hail': 'Granizo',
    'Snowstorm': 'Nevasca', 'Strength Obtained': 'Strength Obtido',
    'Sun': 'Sol', 'Clear': 'Limpo',
    'Thunderstorm': 'Tempestade', 'Waterfall Obtained': 'Waterfall Obtida',
    'Windy': 'Ventoso', 'Cloudy': 'Nublado',
  };
  return map[weather] ?? weather;
}

// ─── HELPERS COMPARTILHADOS: chip + sheet ────────────────────────

String _locationChipText(Map<String, dynamic> enc) {
  const giftMethods = {
    'gift', 'Gift', 'gift-egg', 'Gift Egg',
    'Starter Pokemon', 'Starter Pokémon',
  };
  const giftGivers = <String, String>{
    'Starter Pokemon|Lumiose City':     'do Prof. Sycamore',
    'Starter Pokémon|Lumiose City':     'do Prof. Sycamore',
    'Gift|Lumiose City':                'do Prof. Sycamore',
    'Starter Pokemon|Pallet Town':      'do Prof. Oak',
    'Starter Pokémon|Pallet Town':      'do Prof. Oak',
    'Gift|Pallet Town':                 'do Prof. Oak',
    'Starter Pokemon|New Bark Town':    'do Prof. Elm',
    'Starter Pokémon|New Bark Town':    'do Prof. Elm',
    'Starter Pokemon|Littleroot Town':  'do Prof. Birch',
    'Starter Pokémon|Littleroot Town':  'do Prof. Birch',
    'Starter Pokemon|Twinleaf Town':    'do Prof. Rowan',
    'Starter Pokémon|Twinleaf Town':    'do Prof. Rowan',
    'Starter Pokemon|Nuvema Town':      'do Prof. Juniper',
    'Starter Pokémon|Nuvema Town':      'do Prof. Juniper',
    'Starter Pokemon|Aspertia City':    'do Prof. Juniper',
    'Starter Pokémon|Aspertia City':    'do Prof. Juniper',
    'Starter Pokemon|Iki Town':         'do Prof. Kukui',
    'Starter Pokémon|Iki Town':         'do Prof. Kukui',
    'Starter Pokemon|Postwick':         'de Leon',
    'Starter Pokémon|Postwick':         'de Leon',
    'Starter Pokemon|Cabo Poco':        'do Prof. Sada/Turo',
    'Starter Pokémon|Cabo Poco':        'do Prof. Sada/Turo',
  };
  final rawLoc  = enc['location'] as String? ?? '';
  final method  = enc['method']  as String? ?? '';
  final location = normalizeLocationName(rawLoc);
  if (giftMethods.contains(method) && !location.startsWith('Presente')) {
    final giver = giftGivers['$method|$rawLoc'];
    return giver != null ? 'Presente $giver em $location' : 'Presente em $location';
  }
  return location;
}

String _translateMethod(String method) {
  const map = {
    // Genérico
    '':                              'Encontro Selvagem',
    'walk':                          'Grama Alta',
    'Walk':                          'Grama Alta',
    'Grass':                         'Grama Alta',
    'Tall Grass':                    'Grama Alta',
    'grass-spots':                   'Manchas de Grama',
    'dark-grass':                    'Grama Escura',
    'Walking / Grass':               'Grama Alta',
    'Walking / Grass - SOS only':    'Grama Alta (SOS)',
    'Cave':                          'Caverna',
    'cave-spots':                    'Manchas de Caverna',
    'Water':                         'Água',
    'Water - Rare Spawns':           'Água (Raro)',
    'Surf':                          'Surfando',
    'surf':                          'Surfando',
    'Surfing':                       'Surfando',
    'Surf - SOS only':               'Surfando (SOS)',
    'Surf Special':                  'Surf Especial',
    'surf-spots':                    'Manchas de Surf',
    'Wandering Surf':                'Errante (Surf)',
    'Old Rod':                       'Vara Velha',
    'old-rod':                       'Vara Velha',
    'Good Rod':                      'Vara Boa',
    'good-rod':                      'Vara Boa',
    'Super Rod':                     'Super Vara',
    'super-rod':                     'Super Vara',
    'super-rod-spots':               'Manchas de Pesca (Super)',
    'Fish':                          'Pescando',
    'Fishing':                       'Pescando',
    'Fish - SOS only':               'Pescando (SOS)',
    'Fish Special':                  'Pesca Especial',
    'Fish Special - SOS only':       'Pesca Especial (SOS)',
    'Rock Smash':                    'Quebrar Pedra',
    'rock-smash':                    'Quebrar Pedra',
    'Headbutt':                      'Cabeçada',
    'HeadButt':                      'Cabeçada',
    'Headbutt N.':                   'Cabeçada',
    'Headbutt Sp.':                  'Cabeçada (Raro)',
    'Shaking':                       'Grama Agitada',
    'Shaking Grass':                 'Grama Agitada',
    'Shaking Grass - SOS only':      'Grama Agitada (SOS)',
    'Shaking Trees':                 'Sacudir Árvores',
    'Shaking Trees - SOS only':      'Sacudir Árvores (SOS)',
    'Honey Tree':                    'Árvore do Mel',
    'Honey Tree - Rare':             'Árvore do Mel (Raro)',
    'Honey Tree - Very Rare':        'Árvore do Mel (Muito Raro)',
    'Berry':                         'Árvore de Bagas',
    'Berry Tree':                    'Árvore de Bagas',
    'Swarm':                         'Enxame',
    'Horde':                         'Horda',
    'Roaming in Grass':              'Errante na Grama',
    'Roaming in the Grass':          'Errante na Grama',
    'Roaming in the Cave':           'Errante na Caverna',
    'Overworld':                     'Mundo Aberto',
    'Wandering':                     'Errante',
    'Random':                        'Grama Alta',
    'Static':                        'Encontro Fixo',
    'Fixed':                         'Encontro Fixo',
    'only-one':                      'Único',
    'Interact':                      'Interagir',
    'Flying':                        'Voando',
    'In the Sky':                    'No Céu',
    'In the Sky - Rare Spawns':      'No Céu (Raro)',
    'Underground':                   'Gran Subterrâneo',
    'Sand':                          'Areia',
    'Swamp':                         'Pântano',
    'rough-terrain':                 'Terreno Irregular',
    'seaweed':                       'Alga Marinha',
    'bridge-spots':                  'Manchas de Ponte',
    'PokeRadar':                     'Poké Radar',
    'Poke Radar':                    'Poké Radar',
    'DexNav':                        'DexNav',
    'Island Scan':                   'Island Scan',
    'Weather SOS Battle':            'SOS (Clima)',
    'Curry':                         'Curry Dex',
    'Grass - Rare Spawns':           'Grama Alta (Raro)',
    'Gift':                          'Presente',
    'gift':                          'Presente',
    'gift-egg':                      'Ovo Presente',
    'Gift Egg':                      'Ovo Presente',
    'Starter Pokemon':               'Pokémon Inicial',
    'Starter Pokémon':               'Pokémon Inicial',
    'From totem after completion of game': 'Totem (pós-jogo)',
    'Trade':                         'Troca',
    'trade':                         'Troca',
    'Event':                         'Evento',
    'Special':                       'Especial',
    'Max Raid Battle':               'Raid Max',
    'Gigantamax Raid Battle':        'Raid Gigamax',
    'Tera Raid Battle':              'Tera Raid',
    'purple-flowers':                'Flores Roxas',
    'red-flowers':                   'Flores Vermelhas',
    'yellow-flowers':                'Flores Amarelas',
    'squirt-bottle':                 'Garrafa d\'Água',
    'wailmer-pail':                  'Regador Wailmer',
    'pokeflute':                     'Poké Flauta',
    'Wimpod':                        'Fuga do Wimpod',
    'Sharpedo':                      'Surfando no Sharpedo',
    'Requires Dialga & Palkia':      'Requer Dialga & Palkia',
    'Requires Entei & Raikou':       'Requer Entei & Raikou',
    'Requires Kyogre & Groudon':     'Requer Kyogre & Groudon',
    'Requires Reshiram & Zekrom':    'Requer Reshiram & Zekrom',
    'Requires Tornadus & Thundurus': 'Requer Tornadus & Thundurus',
    // Novos métodos do json de referência
    'Walking':                       'Grama Alta',
    'Walking (Overworld)':           'Mundo Aberto',
    'Walking - Overworld':           'Mundo Aberto',
    'Walking (Grass spots)':         'Manchas de Grama',
    'Walking (SOS)':                 'Grama Alta (SOS)',
    'Dark Grass':                    'Grama Escura',
    'Surfing (Overworld)':           'Errante (Surf)',
    'Surfing (Spots)':               'Manchas de Surf',
    'Fishing (Old Rod)':             'Vara Velha',
    'Fishing (Good Rod)':            'Vara Boa',
    'Fishing (Super Rod)':           'Super Vara',
    'Fishing (Super Rod spots)':     'Manchas de Pesca (Super)',
    'Using Good Rod':                'Vara Boa',
    'Using Headbutt':                'Cabeçada',
    'Headbutt (Special)':            'Cabeçada (Raro)',
    'Using Rock Smash':              'Quebrar Pedra',
    'Rocksmash':                     'Quebrar Pedra',
    'Rough Terrain':                 'Terreno Irregular',
    'Flying (Overworld)':            'Voando',
    'Static (Overworld)':            'Encontro Fixo',
    'Max Raid Den':                  'Raid Max Den',
    'Wild Tera':                     'Tera Selvagem',
    'Transfer':                      'Transferência',
    'Time Capsule':                  'Cápsula do Tempo',
    'Berry Pile':                    'Pilha de Bagas',
    'Berry Piles':                   'Pilha de Bagas',
    'Evolve':                        'Evolução',
    'Glitch':                        'Glitch',
    'Pokémon Bank':                  'Pokémon Bank',
  };
  // Ignora entradas que são nomes de locais com método embutido (dados de raid)
  if (method.contains('(Max Raid Battle)') || method.contains('(Max Raid Den)')) {
    return 'Raid Max';
  }
  return map[method] ?? (method.isEmpty ? 'Selvagem' : method);
}

// ─── HELPER: AGRUPAR ENCOUNTERS ──────────────────────────────────

Map<String, List<Map<String, dynamic>>> groupEncounters(
    List<Map<String, dynamic>> entries) {
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final e in entries) {
    final loc = e['location'] as String? ?? '';
    if (loc.startsWith('Unknown') || loc.startsWith('unknown')) continue;
    final key = '$loc|${e['method']}|${e['time']}|${e['weather']}';
    groups.putIfAbsent(key, () => []).add(e);
  }
  return groups;
}

/// Groups encounters by region for multi-region games.
/// Returns ordered map: region → (groupKey → entries).
Map<String, Map<String, List<Map<String, dynamic>>>> groupEncountersByRegion(
    List<Map<String, dynamic>> entries, String dexId) {
  final byRegion = <String, List<Map<String, dynamic>>>{};
  for (final e in entries) {
    final region = locationRegion(e['location'] as String? ?? '', dexId) ?? '';
    byRegion.putIfAbsent(region, () => []).add(e);
  }
  final result = <String, Map<String, List<Map<String, dynamic>>>>{};
  for (final entry in byRegion.entries) {
    result[entry.key] = groupEncounters(entry.value);
  }
  return result;
}

// ─── HELPER: REGIÃO POR JOGO ─────────────────────────────────────

/// Returns the region name for a location in the given dex.
/// Returns null for single-region games (no grouping needed).
String? locationRegion(String location, String dexId) {
  switch (dexId) {
    case 'sword___shield':            return _swShieldRegion(location);
    case 'heartgold___soulsilver':    return _hgssRegion(location);
    case 'firered___leafgreen_(gba)':
    case 'firered___leafgreen':       return _frlgRegion(location);
    case 'legends:_arceus':           return _legendsArceusArea(location);
    case 'scarlet___violet':          return _scarletVioletRegion(location);
    default: return null;
  }
}

String _swShieldRegion(String location) {
  const isle = {
    'Fields of Honor', 'Soothing Wetlands', 'Forest of Focus',
    'Challenge Beach', 'Challenge Road', "Brawlers' Cave", 'Courageous Cavern',
    'Loop Lagoon', 'Warm-Up Tunnel', 'Potbottom Desert', 'Workout Sea',
    'Stepping-Stone Sea', 'Insular Sea', 'Honeycalm Sea', 'Honeycalm Island',
    'Training Lowlands',
  };
  if (isle.any((k) => location.startsWith(k))) return 'Ilha da Armadura';
  if (location.contains('Crown Tundra') || location.contains('Crown Shrine') ||
      location.contains('Dynamax Adventures') || location.contains("Giant's Bed") ||
      location.contains('Ballimere Lake') || location.contains("Giant's Foot") ||
      location.contains('Snowslide Slope') || location.contains('Slippery Slope') ||
      location.contains('Frostpoint Field') || location.contains('Frigid Sea') ||
      location.contains('Dyna Tree Hill') || location.contains('Three-Point Pass') ||
      location.contains('Lakeside Cave') || location.contains('Old Cemetery') ||
      location.contains('Roaring-Sea Caves'))
    return 'Coroa de Tundra';
  return 'Galar';
}

String _hgssRegion(String location) {
  final routeMatch = RegExp(r'^Route (\d+)$').firstMatch(location);
  if (routeMatch != null) {
    final num = int.parse(routeMatch.group(1)!);
    return num <= 28 ? 'Kanto' : 'Johto';
  }
  final seaRouteMatch = RegExp(r'^Sea Route (\d+)$').firstMatch(location);
  if (seaRouteMatch != null) {
    final num = int.parse(seaRouteMatch.group(1)!);
    return num <= 21 ? 'Kanto' : 'Johto';
  }
  const kanto = {
    'Viridian Forest', 'Cerulean Cave', 'Mt. Moon', 'Rock Tunnel',
    'Seafoam Islands', "Diglett's Cave", 'Victory Road',
    'Celadon City', 'Cerulean City', 'Fuchsia City', 'Saffron City',
    'Vermilion City', 'Pallet Town', 'Viridian City', 'Cinnabar Island',
    'Mt. Silver',
  };
  return kanto.contains(location) ? 'Kanto' : 'Johto';
}

String _frlgRegion(String location) {
  const sevii = {
    'One Island', 'Two Island', 'Three Island', 'Four Island',
    'Five Island', 'Six Island', 'Seven Island', 'Kindle Road',
    'Icefall Cave', 'Lost Cave', 'Pattern Bush', 'Ruin Valley',
    'Altering Cave', 'Birth Island', 'Outcast Island', 'Tanoby Ruins',
    'Water Labyrinth', 'Resort Gorgeous', 'Water Path', 'Green Path',
    'Memorial Pillar', 'Fortune Island', 'Quest Island',
  };
  return sevii.contains(location) ? 'Ilhas Sevii' : 'Kanto';
}

String _legendsArceusArea(String location) {
  if (location.contains('Obsidian Fieldlands')) return 'Terras de Obsidiana';
  if (location.contains('Crimson Mirelands'))   return 'Pântanos Carmesim';
  if (location.contains('Cobalt Coastlands'))   return 'Costas de Cobalto';
  if (location.contains('Coronet Highlands'))   return 'Terras Altas do Coronet';
  if (location.contains('Alabaster Icelands'))  return 'Terras de Alabastro';
  return 'Hisui';
}

String _scarletVioletRegion(String location) {
  if (location.startsWith('The Teal Mask')) return 'Kitakami';
  if (location.contains('Blueberry Academy') ||
      location.startsWith('After clearing Area Zero')) return 'Blueberry Academy';
  return 'Paldea';
}

// ─── HELPER: COR DO DEX ──────────────────────────────────────────

/// Retorna a cor primária do jogo, idêntica à usada na barra de seleção da Pokédex.
Color dexColor(String dexId) {
  switch (dexId) {
    case 'red___blue':                        return const Color(0xFFE53935);
    case 'yellow':                            return const Color(0xFFFDD835);
    case 'gold___silver':                     return const Color(0xFFFFCA28);
    case 'crystal':                           return const Color(0xFF29B6F6);
    case 'ruby___sapphire':                   return const Color(0xFFE53935);
    case 'firered___leafgreen_(gba)':         return const Color(0xFFEF5350);
    case 'emerald':                           return const Color(0xFF43A047);
    case 'diamond___pearl':                   return const Color(0xFF90CAF9);
    case 'platinum':                          return const Color(0xFF78909C);
    case 'heartgold___soulsilver':            return const Color(0xFFFFCA28);
    case 'black___white':                     return const Color(0xFF424242);
    case 'black_2___white_2':                 return const Color(0xFF1A237E);
    case 'x___y':                             return const Color(0xFF1565C0);
    case 'omega_ruby___alpha_sapphire':       return const Color(0xFFE53935);
    case 'sun___moon':                        return const Color(0xFFFF8F00);
    case 'ultra_sun___ultra_moon':            return const Color(0xFFFF6F00);
    case "let's_go_pikachu___eevee":          return const Color(0xFFFDD835);
    case 'sword___shield':                    return const Color(0xFF42A5F5);
    case 'brilliant_diamond___shining_pearl': return const Color(0xFF42A5F5);
    case 'legends:_arceus':                   return const Color(0xFFFFCA28);
    case 'scarlet___violet':                  return const Color(0xFFEF6C00);
    case 'legends:_z-a':                      return const Color(0xFF546E7A);
    default:                                  return const Color(0xFF546E7A);
  }
}

String _formatGameVersion(String game) {
  if (game.isEmpty) return '';
  return encounterGameName(game);
}

// ─── WIDGET: LINHA DE LOCALIZAÇÃO (ESTILO MASTERDEX) ─────────────

class LocationRow extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final List<String> pokemonTypes;

  const LocationRow({super.key, required this.entries, required this.pokemonTypes});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first  = entries.first;
    final location = _locationChipText(first);
    final rawMethod = first['method'] as String? ?? '';
    final method    = _translateMethod(rawMethod);
    final time      = encounterTimePt(first['time'] as String? ?? '');
    final weather   = encounterWeatherPt(first['weather'] as String? ?? '');

    // Agrupa versões por (levels, rarity); cada entrada já carrega sua lista de games
    final statGroups = <String, List<String>>{};
    for (final e in entries) {
      final statsKey = '${e['levels']}|${e['rarity']}';
      final gamesList = (e['games'] as List?)?.cast<String>() ?? <String>[];
      statGroups.putIfAbsent(statsKey, () => []);
      for (final g in gamesList) {
        if (g.isNotEmpty && !statGroups[statsKey]!.contains(g)) {
          statGroups[statsKey]!.add(g);
        }
      }
    }

    final subtitleParts = <String>[];
    if (method.isNotEmpty) subtitleParts.add(method);
    if (time.isNotEmpty && time != 'Dia' && time != 'Dia Todo' && time != 'Sempre') {
      subtitleParts.add(time);
    }
    if (weather.isNotEmpty && weather != 'Dia' && weather != 'Dia Todo') {
      subtitleParts.add(weather);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(location,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: scheme.onSurface)),
            if (subtitleParts.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(subtitleParts.join(' · '),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 6),
            ...statGroups.entries.map((sg) {
              final parts   = sg.key.split('|');
              final levels  = parts[0];
              final rarity  = parts[1];
              final games   = sg.value;

              final levelStr  = _formatLevels(levels);
              final rarityStr = _formatRarity(rarity, rawMethod);

              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    if (games.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        children: games.map((g) => _VersionTag(game: g)).toList(),
                      ),
                    if (games.isNotEmpty && (levelStr.isNotEmpty || rarityStr.isNotEmpty))
                      const SizedBox(width: 8),
                    if (levelStr.isNotEmpty)
                      Text(levelStr,
                        style: TextStyle(fontSize: 11, color: scheme.onSurface)),
                    if (levelStr.isNotEmpty && rarityStr.isNotEmpty)
                      Text(' · ',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    if (rarityStr.isNotEmpty)
                      Text(rarityStr,
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

String _formatLevels(String levels) {
  if (levels.isEmpty) return '';
  if (levels.contains('-')) return 'Lv. ${levels.replaceAll('-', '–')}';
  return 'Lv. $levels';
}

const _nonWildMethods = {
  'Gift', 'gift', 'gift-egg', 'Gift Egg', 'Trade', 'trade', 'Transfer',
  'Event', 'Time Capsule', 'Pokémon Bank', 'only-one',
  'Starter Pokemon', 'Starter Pokémon', 'Pokémon Colosseum Bonus Disc (US)\nPokémon Channel (EU)',
  'Floaroma Town (Only one*)',
};

String _formatRarity(String rarity, String method) {
  if (rarity.isEmpty) return '';
  if (_nonWildMethods.contains(method)) return '';
  const textMap = {
    'UNCOMMON': 'Incomum',
    'LIMITED':  'Limitado',
    'COMMON':   'Comum',
    '?':        '?',
  };
  if (textMap.containsKey(rarity)) return textMap[rarity]!;
  final num = double.tryParse(rarity);
  if (num == null) return rarity;
  if (num <= 1) return '';
  return '$rarity%';
}

Color _versionTagColor(String game) {
  switch (game) {
    case 'Sword':             return const Color(0xFF42A5F5);
    case 'Shield':            return const Color(0xFFEF5350);
    case 'Scarlet':           return const Color(0xFFEF6C00);
    case 'Violet':            return const Color(0xFF7B1FA2);
    case 'Legends: Arceus':   return const Color(0xFFFFCA28);
    case 'Legends: Z-A':      return const Color(0xFF546E7A);
    case 'Brilliant Diamond': return const Color(0xFF42A5F5);
    case 'Shining Pearl':     return const Color(0xFFEC407A);
    case 'HeartGold':         return const Color(0xFFFFCA28);
    case 'SoulSilver':        return const Color(0xFFB0BEC5);
    case "Let's Go Pikachu":  return const Color(0xFFFDD835);
    case "Let's Go Eevee":    return const Color(0xFF8D6E63);
    case 'Ultra Sun':         return const Color(0xFFFF6F00);
    case 'Ultra Moon':        return const Color(0xFF4A148C);
    case 'Sun':               return const Color(0xFFFF8F00);
    case 'Moon':              return const Color(0xFF7B1FA2);
    case 'X':                 return const Color(0xFF1565C0);
    case 'Y':                 return const Color(0xFFE53935);
    case 'Omega Ruby':        return const Color(0xFFE53935);
    case 'Alpha Sapphire':    return const Color(0xFF1E88E5);
    case 'Black':             return const Color(0xFF424242);
    case 'White':             return const Color(0xFF78909C);
    case 'Black 2':           return const Color(0xFF1A237E);
    case 'White 2':           return const Color(0xFFBDBDBD);
    case 'Diamond':           return const Color(0xFF90CAF9);
    case 'Pearl':             return const Color(0xFFF48FB1);
    case 'Platinum':          return const Color(0xFF78909C);
    case 'Gold':              return const Color(0xFFFFCA28);
    case 'Silver':            return const Color(0xFFB0BEC5);
    case 'Crystal':           return const Color(0xFF29B6F6);
    case 'FireRed':           return const Color(0xFFEF5350);
    case 'LeafGreen':         return const Color(0xFF43A047);
    case 'Emerald':           return const Color(0xFF43A047);
    case 'Ruby':              return const Color(0xFFE53935);
    case 'Sapphire':          return const Color(0xFF1E88E5);
    case 'Red':               return const Color(0xFFE53935);
    case 'Blue':              return const Color(0xFF1565C0);
    case 'Yellow':            return const Color(0xFFFDD835);
    default:                  return const Color(0xFF546E7A);
  }
}

class _VersionTag extends StatelessWidget {
  final String game;
  const _VersionTag({required this.game});

  @override
  Widget build(BuildContext context) {
    final color = _versionTagColor(game);
    final textColor = color.computeLuminance() > 0.35 ? Colors.black87 : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(game,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        )),
    );
  }
}

// ─── WIDGET: SEÇÃO RECOLHÍVEL POR REGIÃO ─────────────────────────

class ExpandableRegionSection extends StatefulWidget {
  final String region;
  final Map<String, List<Map<String, dynamic>>> groups;
  final List<String> pokemonTypes;
  final bool initiallyExpanded;

  const ExpandableRegionSection({
    super.key,
    required this.region,
    required this.groups,
    required this.pokemonTypes,
    this.initiallyExpanded = false,
  });

  @override
  State<ExpandableRegionSection> createState() => _ExpandableRegionSectionState();
}

class _ExpandableRegionSectionState extends State<ExpandableRegionSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant, width: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.region,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      )),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, thickness: 0.8, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Column(
                children: widget.groups.values
                    .map((g) => LocationRow(entries: g, pokemonTypes: widget.pokemonTypes))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── WIDGET: CHIP CLICÁVEL DE LOCALIZAÇÃO ────────────────────────

class LocationChip extends StatelessWidget {
  final Map<String, dynamic> enc;
  final List<String> pokemonTypes;

  const LocationChip({super.key, required this.enc, required this.pokemonTypes});

  @override
  Widget build(BuildContext context) {
    final scheme  = Theme.of(context).colorScheme;
    final display = _locationChipText(enc);

    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 6),
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scheme.outlineVariant, width: 0.8),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (_) => LocationDetailSheet(
                enc: enc, pokemonTypes: pokemonTypes),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(display,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              )),
          ),
        ),
      ),
    );
  }
}

// ─── WIDGET: SHEET DE DETALHE DE LOCALIZAÇÃO ─────────────────────

class _LocDetailRow {
  final String label, value;
  const _LocDetailRow(this.label, this.value);
}

class LocationDetailSheet extends StatelessWidget {
  final Map<String, dynamic> enc;
  final List<String> pokemonTypes;

  const LocationDetailSheet(
      {super.key, required this.enc, required this.pokemonTypes});

  @override
  Widget build(BuildContext context) {
    final scheme  = Theme.of(context).colorScheme;
    final method  = enc['method']  as String? ?? '';
    final levels  = enc['levels']  as String? ?? '';
    final rarity  = enc['rarity']  as String? ?? '';
    final time    = enc['time']    as String? ?? '';
    final weather = enc['weather'] as String? ?? '';

    final display = _locationChipText(enc);

    final details = <_LocDetailRow>[
      _LocDetailRow('Método', _translateMethod(method)),
    ];
    final lvStr = _formatLevels(levels);
    if (lvStr.isNotEmpty) details.add(_LocDetailRow('Nível', lvStr));
    final rarityStr = _formatRarity(rarity, method);
    if (rarityStr.isNotEmpty) details.add(_LocDetailRow('Raridade', rarityStr));
    final timePt = encounterTimePt(time);
    if (time.isNotEmpty &&
        timePt != 'Dia' && timePt != 'Dia Todo' && timePt != 'Sempre') {
      details.add(_LocDetailRow('Horário', timePt));
    }
    final weatherPt = encounterWeatherPt(weather);
    if (weather.isNotEmpty && weatherPt != 'Dia' && weatherPt != 'Dia Todo') {
      details.add(_LocDetailRow('Clima', weatherPt));
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(display,
            style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: scheme.onSurface)),
          const SizedBox(height: 14),
          ...details.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(width: 80,
                child: Text(d.label,
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant))),
              Expanded(
                child: Text(d.value,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: scheme.onSurface))),
            ]),
          )),
        ],
      ),
    );
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/theme/type_colors.dart';
import 'package:pokedex_tracker/translations.dart';

// ─── UTILITÁRIOS GLOBAIS ─────────────────────────────────────────

const String kApiBase = 'https://pokeapi.co/api/v2';

// ─── ÍCONES DE TIPO ───────────────────────────────────────────────
// SVGs em assets/types/<type>.svg (MIT — duiker101/pokemon-type-svg-icons)
String typeIconAsset(String type) => 'assets/types/${type.toLowerCase()}.png';

// Nomes traduzidos dos tipos
const Map<String, String> typeNamePt = {
  'normal':   'Normal',
  'fire':     'Fogo',
  'water':    'Água',
  'grass':    'Planta',
  'electric': 'Elétrico',
  'ice':      'Gelo',
  'fighting': 'Lutador',
  'poison':   'Veneno',
  'ground':   'Terra',
  'flying':   'Voador',
  'psychic':  'Psíquico',
  'bug':      'Inseto',
  'rock':     'Pedra',
  'ghost':    'Fantasma',
  'dragon':   'Dragão',
  'dark':     'Sombrio',
  'steel':    'Aço',
  'fairy':    'Fada',
};

// ─── MAPEAMENTO pokedexId → version-groups da PokeAPI ─────────────
// Usado para buscar o flavor text do jogo correto em pokemon-species.
// Ordem: prioridade decrescente (primeiros = preferidos para esse jogo).
const Map<String, List<String>> pokedexVersionGroups = {
  'let_s_go_pikachu___eevee':           ['lets-go-pikachu-lets-go-eevee'],
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

String ptType(String en) {
  const m = {
    'normal': 'Normal', 'fire': 'Fogo', 'water': 'Água',
    'electric': 'Elétrico', 'grass': 'Planta', 'ice': 'Gelo',
    'fighting': 'Lutador', 'poison': 'Veneno', 'ground': 'Terreno',
    'flying': 'Voador', 'psychic': 'Psíquico', 'bug': 'Inseto',
    'rock': 'Pedra', 'ghost': 'Fantasma', 'dragon': 'Dragão',
    'dark': 'Sombrio', 'steel': 'Aço', 'fairy': 'Fada',
  };
  return m[en.toLowerCase()] ?? en;
}

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
            nameEn[0].toUpperCase() + nameEn.substring(1).replaceAll('-', ' ');
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
        // both: PT à esquerda, EN à direita com cor secundária
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(child: Text(ptFormatted,
              style: baseStyle ?? const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis, maxLines: 1)),
            const SizedBox(width: 6),
            Flexible(child: Text(enFormatted,
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
const Map<String, Color> typeIconColors = {
  'normal':   Color.fromRGBO(131, 140, 150, 1),
  'fire':     Color.fromRGBO(253, 149,  76, 1),
  'water':    Color.fromRGBO( 64, 135, 210, 1),
  'grass':    Color.fromRGBO( 75, 172,  68, 1),
  'electric': Color.fromRGBO(251, 205,  44, 1),
  'ice':      Color.fromRGBO(103, 195, 180, 1),
  'fighting': Color.fromRGBO(208,  40,  89, 1),
  'poison':   Color.fromRGBO(164,  82, 194, 1),
  'ground':   Color.fromRGBO(216, 118,  74, 1),
  'flying':   Color.fromRGBO(136, 162, 218, 1),
  'psychic':  Color.fromRGBO(252, 114, 121, 1),
  'bug':      Color.fromRGBO(144, 188,  42, 1),
  'rock':     Color.fromRGBO(192, 172, 128, 1),
  'ghost':    Color.fromRGBO( 85, 104, 167, 1),
  'dragon':   Color.fromRGBO(  2,  96, 181, 1),
  'dark':     Color.fromRGBO( 83,  77,  94, 1),
  'steel':    Color.fromRGBO( 77, 125, 144, 1),
  'fairy':    Color.fromRGBO(232, 112, 217, 1),
};

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
          // Fundo colorido com bordas arredondadas
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
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
// Layout: categoria (itálico) → flavor text → Altura/Tipo/Peso com label acima

class AboutHeader extends StatelessWidget {
  final String category;
  final String flavorText;
  final String height;
  final String weight;
  final List<String> types;
  final bool loading;

  const AboutHeader({
    super.key,
    required this.category,
    required this.flavorText,
    required this.height,
    required this.weight,
    required this.types,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final categoryLabel = loading
        ? ''
        : category.isEmpty ? '—' : 'Pokémon $category';

    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      // Categoria centralizada
      if (loading)
        const SizedBox(height: 20,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
      else
        Text(
          categoryLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13, color: secondary, fontStyle: FontStyle.italic),
        ),

      const SizedBox(height: 12),

      // Flavor text
      if (loading)
        const SizedBox(height: 40,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
      else
        Text(
          flavorText.isEmpty ? '—' : flavorText,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, height: 1.5),
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
                  child: Text(loading ? '—' : height,
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
                if (loading)
                  const SizedBox(height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2))
                else
                  ...types.map((t) => Padding(
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
                  child: Text(loading ? '—' : weight,
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

    final primaryTypePt = pokemonTypes.isNotEmpty
        ? ptType(pokemonTypes[0])
        : 'Normal';
    final typeColor = TypeColors.fromType(primaryTypePt);

    final cardBg = isDark
        ? typeColor.withOpacity(0.08)
        : typeColor.withOpacity(0.06);

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
            border: Border.all(color: typeColor.withOpacity(0.3), width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: loading
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2)))
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
                border: Border.all(color: typeColor, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: typeColor,
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
  // Estados dos toggles — independentes e combináveis
  bool _isHome   = false;
  bool _isShiny  = false;
  bool _isFemale = false;
  bool _isPixel  = false;

  @override
  void initState() {
    super.initState();
    // Lê do notifier global — já inicializado no main(), sem async
    final sprite = defaultSpriteNotifier.value;
    _isPixel = sprite == 'pixel';
    _isHome  = sprite == 'home';
  }

  /// URL do sprite atual baseado nos estados ativos
  String get _spriteUrl {
    final p = widget.pokemon;
    final id = p.id;
    const base = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';

    if (_isHome) {
      if (_isShiny && _isFemale) return p.spriteHomeShinyUrl ?? p.spriteHomeUrl ?? p.spriteUrl;
      if (_isShiny)  return p.spriteHomeShinyUrl ?? p.spriteUrl;
      if (_isFemale) return p.spriteHomeFemaleUrl ?? p.spriteHomeUrl ?? p.spriteUrl;
      return p.spriteHomeUrl ?? p.spriteUrl;
    }
    if (_isPixel) {
      if (_isShiny && _isFemale) return p.spritePixelShinyUrl ?? p.spritePixelUrl ?? p.spriteUrl;
      if (_isShiny)  return p.spritePixelShinyUrl ?? p.spritePixelUrl ?? p.spriteUrl;
      if (_isFemale) return p.spritePixelFemaleUrl ?? p.spritePixelUrl ?? p.spriteUrl;
      return p.spritePixelUrl ?? p.spriteUrl;
    }
    // Official artwork
    if (_isShiny)  return p.spriteShinyUrl ?? p.spriteUrl;
    if (_isFemale) return p.spritePixelFemaleUrl ?? '$base/front_female/${p.id}.png';
    return p.spriteUrl;
  }

  // Quando HOME é ativado, pixel é desativado (e vice-versa)
  void _toggleHome()  {
    setState(() { _isHome = !_isHome; if (_isHome) _isPixel = false; });
  }
  void _togglePixel() {
    setState(() { _isPixel = !_isPixel; if (_isPixel) _isHome = false; });
  }
  void _toggleShiny()  => setState(() => _isShiny  = !_isShiny);
  void _toggleFemale() => setState(() => _isFemale = !_isFemale);

  @override
  Widget build(BuildContext context) {
    final p = widget.pokemon;
    final pt = p.types.isNotEmpty ? p.types[0] : 'normal';
    // Suaviza a cor do tipo misturando com branco — mantém identidade mas reduz saturação
    final rawC1 = TypeColors.fromType(ptType(pt));
    final rawC2 = p.types.length > 1 ? TypeColors.fromType(ptType(p.types[1])) : rawC1;
    final c1 = Color.lerp(rawC1, Colors.white, 0.28)!;
    final c2 = Color.lerp(rawC2, Colors.white, 0.28)!;

    // Pokébola: vermelha = capturado, branca translúcida = não capturado
    final pokeballColor = widget.caught
        ? const Color(0xFFE24B4A)
        : Colors.white.withOpacity(0.75);

    // Shiny disponível em algum dos modos ativos
    final hasShinyNow = _isHome
        ? p.spriteHomeShinyUrl != null
        : _isPixel
            ? p.spritePixelShinyUrl != null
            : p.spriteShinyUrl != null;

    // Feminino: só existe na camada pixel (front_female). Ocultar em artwork e HOME
    // a menos que o HOME tenha versão feminina explícita
    final hasFemaleNow = _isHome
        ? p.spriteHomeFemaleUrl != null
        : _isPixel
            ? p.spritePixelFemaleUrl != null
            : false; // artwork oficial não tem versão feminina

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
                    // Sprite
                    Expanded(
                      child: Image.network(
                        _spriteUrl,
                        fit: BoxFit.contain,
                        filterQuality: _isPixel ? FilterQuality.none : FilterQuality.medium,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.catching_pokemon, size: 100, color: Colors.white),
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
                                  Text('#${p.id.toString().padLeft(3, '0')}',
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
                        // 2. HOME render (se disponível)
                        if (p.hasHome)
                          _HeaderIconButton(
                            icon: Icons.view_in_ar,
                            active: _isHome,
                            activeColor: Colors.lightBlueAccent,
                            onTap: _toggleHome,
                          ),
                        // 3. Pixel art (se disponível)
                        if (p.hasPixel)
                          _HeaderIconButton(
                            icon: Icons.grid_on,
                            active: _isPixel,
                            activeColor: Colors.orangeAccent,
                            onTap: _togglePixel,
                          ),
                        // 4. Shiny (só mostra se existe no modo atual)
                        if (hasShinyNow)
                          _HeaderIconButton(
                            icon: Icons.auto_awesome,
                            active: _isShiny,
                            activeColor: const Color(0xFFFFD700),
                            onTap: _toggleShiny,
                          ),
                        // 5. Feminino (só mostra se existe no modo atual)
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
    final typeColor = p.types.isNotEmpty
        ? TypeColors.fromType(ptType(p.types[0]))
        : Theme.of(context).colorScheme.primary;

    // Grupos de dano
    final quad   = wk.entries.where((e) => e.value == 4.0).toList();
    final fraq   = wk.entries.where((e) => e.value == 2.0).toList();
    final half   = wk.entries.where((e) => e.value == 0.5).toList();
    final quart  = wk.entries.where((e) => e.value == 0.25).toList();
    final imun   = wk.entries.where((e) => e.value == 0.0).toList();

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
            // Abas Base / Mín / Máx — tamanho compacto alinhado ao card
            Align(
              alignment: Alignment.center,
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: typeColor.withOpacity(0.25), width: 1),
                ),
                child: IntrinsicWidth(
                  child: TabBar(
                    controller: _tabController,
                    labelColor: typeColor,
                    unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    indicator: BoxDecoration(
                      color: typeColor.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                    unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    tabAlignment: TabAlignment.center,
                    isScrollable: true,
                    padding: const EdgeInsets.all(3),
                    tabs: const [
                      Tab(text: 'Base', height: 28),
                      Tab(text: 'Mín',  height: 28),
                      Tab(text: 'Máx',  height: 28),
                    ],
                  ),
                ),
              ),
            ),
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
              if (quad.isNotEmpty)   _DamageGroup(label: 'Fraqueza ×4',    entries: quad,  opacity: 1.0),
              if (fraq.isNotEmpty)   _DamageGroup(label: 'Fraqueza ×2',    entries: fraq,  opacity: 0.9),
              if (half.isNotEmpty)   _DamageGroup(label: 'Resistência ×½', entries: half,  opacity: 0.75),
              if (quart.isNotEmpty)  _DamageGroup(label: 'Resistência ×¼', entries: quart, opacity: 0.6),
              if (imun.isNotEmpty)   _DamageGroup(label: 'Imunidade ×0',   entries: imun,  opacity: 0.45),
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

// Grupo de tipos por relação de dano (estilo do exemplo)
class _DamageGroup extends StatelessWidget {
  final String label;
  final List<MapEntry<String, double>> entries;
  final double opacity;

  const _DamageGroup({
    super.key,
    required this.label,
    required this.entries,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: entries.map((e) {
              final tc = TypeColors.fromType(ptType(e.key));
              final bg = tc.withOpacity(opacity);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      typeIconAsset(e.key),
                      width: 14,
                      height: 14,
                      color: typeTextColor(bg),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      ptType(e.key),
                      style: TextStyle(
                        color: typeTextColor(bg),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
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
    if (loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

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
        final c1 = types.isNotEmpty ? TypeColors.fromType(ptType(types[0])) : Colors.grey;
        final c2 = types.length > 1 ? TypeColors.fromType(ptType(types[1])) : c1;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final gameBg   = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFDDDDDD);
        final gameText = isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666);

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
                final tc = TypeColors.fromType(ptType(t));
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: tc, borderRadius: BorderRadius.circular(4)),
                  child: Text(ptType(t), style: TextStyle(
                    fontSize: 8, color: typeTextColor(tc), fontWeight: FontWeight.w700)),
                );
              }).toList()),
              if (game != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: gameBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(game,
                    style: TextStyle(fontSize: 8, color: gameText,
                      fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }

  void _showFormModal(BuildContext context, int id, String name,
      List<String> types, String? game, String sprite) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gameBg   = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFDDDDDD);
    final gameText = isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666);
    final c1 = types.isNotEmpty ? TypeColors.fromType(ptType(types[0])) : Colors.grey;
    final c2 = types.length > 1 ? TypeColors.fromType(ptType(types[1])) : c1;

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
              final tc = TypeColors.fromType(ptType(t));
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: tc, borderRadius: BorderRadius.circular(4)),
                child: Text(ptType(t), style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: typeTextColor(tc))),
              );
            }).toList()),
          // Jogo
          if (game != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: gameBg, borderRadius: BorderRadius.circular(4)),
              child: Text(game, style: TextStyle(
                fontSize: 11, color: gameText, fontWeight: FontWeight.w500)),
            ),
          ],
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
  const MovesTab({
    super.key,
    required this.level, required this.mt,
    required this.tutor, required this.egg,
  });

  @override
  State<MovesTab> createState() => _MovesTabState();
}

class _MovesTabState extends State<MovesTab> {
  String _method = 'level';
  Map<String, dynamic>? _selectedMove;
  Map<String, dynamic>? _moveDetail;
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
    setState(() { _selectedMove = move; _loadingMove = true; _moveDetail = null; });
    try {
      final r = await http.get(Uri.parse(move['url'] as String));
      if (r.statusCode == 200 && mounted) {
        setState(() { _moveDetail = json.decode(r.body); _loadingMove = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMove = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Column(children: [
        // Chips de método
        SizedBox(height: 44, child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          children: [
            for (final e in [('level','Nível'),('mt','MT'),('tutor','Tutor'),('egg','Ovo')])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _method = e.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: _method == e.$1
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Text(e.$2, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: _method == e.$1
                          ? Theme.of(context).colorScheme.surface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
                  ),
                ),
              ),
          ],
        )),
        // Legenda ANTES do cabeçalho
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(children: [
            CatLegendItem(category: 'physical', label: 'Físico'),
            const SizedBox(width: 12),
            CatLegendItem(category: 'special', label: 'Especial'),
            const SizedBox(width: 12),
            CatLegendItem(category: 'status', label: 'Status'),
          ]),
        ),
        Divider(height: 0.5, color: Theme.of(context).colorScheme.outlineVariant),
        // Cabeçalho de colunas
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(children: [
            SizedBox(
              width: _method == 'level' ? 32 : 40,
              child: Text(_method == 'level' ? 'NV' : _method == 'mt' ? 'MT' : '',
                style: const TextStyle(fontSize: 9, color: Color(0xFF888888),
                  letterSpacing: 0.06, fontWeight: FontWeight.w500),
                textAlign: TextAlign.right),
            ),
            const SizedBox(width: 8),
            const SizedBox(width: 42,
              child: Text('TIPO', style: TextStyle(fontSize: 9, color: Color(0xFF888888),
                letterSpacing: 0.06, fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
            const SizedBox(width: 8),
            const SizedBox(width: 16),
            const SizedBox(width: 8),
            const Expanded(child: Text('MOVE', style: TextStyle(fontSize: 9,
              color: Color(0xFF888888), letterSpacing: 0.06, fontWeight: FontWeight.w500))),
            const SizedBox(width: 36,
              child: Text('PODER', style: TextStyle(fontSize: 9, color: Color(0xFF888888),
                letterSpacing: 0.06, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
            const SizedBox(width: 18),
          ]),
        ),
        Divider(height: 0.5, color: Theme.of(context).colorScheme.outlineVariant),
        if (_currentMoves.isEmpty)
          Expanded(child: Center(child: Text(
            widget.level.isEmpty ? 'Carregando...' : 'Nenhum move',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          )))
        else
          Expanded(child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _currentMoves.length,
            separatorBuilder: (_, __) => Divider(
              height: 0.5, color: Theme.of(context).colorScheme.outlineVariant),
            itemBuilder: (ctx, i) => MoveRow(
              move: _currentMoves[i],
              method: _method,
              onTap: () => _openMove(_currentMoves[i]),
            ),
          )),
      ]),
      if (_selectedMove != null)
        MoveModal(
          move: _selectedMove!,
          detail: _moveDetail,
          loading: _loadingMove,
          onClose: () => setState(() { _selectedMove = null; _moveDetail = null; }),
        ),
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
    final typePt = ptType(typeEn);
    final typeColor = TypeColors.fromType(typePt);
    final catName = _detail?['damage_class']?['name'] as String? ?? '';
    final power = _detail?['power'] as int?;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          SizedBox(
            width: widget.method == 'level' ? 32 : 40,
            child: Text(
              widget.method == 'level' ? (level > 0 ? '$level' : '1')
                  : widget.method == 'mt' ? level.toString().padLeft(3, '0') : '',
              style: TextStyle(fontSize: widget.method == 'level' ? 11 : 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: typeEn.isEmpty ? Colors.grey.withOpacity(0.2) : typeColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(typeEn.isEmpty ? '···' : typePt,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                color: typeEn.isEmpty ? Colors.grey : typeTextColor(typeColor)),
              textAlign: TextAlign.center),
          ),
          const SizedBox(width: 8),
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              color: catName == 'physical' ? const Color(0xFFE24B4A).withOpacity(0.15)
                  : catName == 'special' ? const Color(0xFF9C27B0).withOpacity(0.15)
                  : const Color(0xFF888888).withOpacity(0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: CustomPaint(painter: CatIconPainter(catName)),
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
            textAlign: TextAlign.right, maxLines: 1,
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
  final bool loading;
  final VoidCallback onClose;
  const MoveModal({super.key, required this.move, required this.detail,
    required this.loading, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final nameEn = move['name'] as String;
    final namePt = translateMove(nameEn);
    final typeEn = detail?['type']?['name'] as String? ?? '';
    final typePt = ptType(typeEn);
    final typeColor = TypeColors.fromType(typePt);
    final catName = detail?['damage_class']?['name'] as String? ?? '';
    final power = detail?['power'];
    final acc = detail?['accuracy'];
    final pp = detail?['pp'];
    final level = move['level'] as int;
    final method = move['method'] as String;

    String desc = '';
    if (detail != null) {
      final flavors = detail!['flavor_text_entries'] as List<dynamic>? ?? [];
      String ptDesc = '', enDesc = '';
      for (final e in flavors) {
        final lang = e['language']['name'] as String;
        if (lang == 'pt-BR' && ptDesc.isEmpty) ptDesc = (e['flavor_text'] as String? ?? '').replaceAll('\n', ' ').trim();
        else if (lang == 'en' && enDesc.isEmpty) enDesc = (e['flavor_text'] as String? ?? '').replaceAll('\n', ' ').trim();
      }
      if (ptDesc.isNotEmpty) desc = ptDesc;
      else if (enDesc.isNotEmpty) desc = enDesc;
      else {
        for (final e in (detail!['effect_entries'] as List<dynamic>? ?? [])) {
          if ((e['language']['name'] as String) == 'en') {
            desc = (e['short_effect'] as String? ?? '').trim(); break;
          }
        }
      }
    }

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
                if (typeEn.isNotEmpty) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: typeColor, borderRadius: BorderRadius.circular(4)),
                  child: Text(typePt, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: typeTextColor(typeColor)))),
                const SizedBox(width: 8),
                if (catName.isNotEmpty) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: catName == 'physical' ? const Color(0xFFE24B4A).withOpacity(0.15)
                        : catName == 'special' ? const Color(0xFF9C27B0).withOpacity(0.15)
                        : const Color(0xFF888888).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: catName == 'physical' ? const Color(0xFFE24B4A).withOpacity(0.4)
                          : catName == 'special' ? const Color(0xFF9C27B0).withOpacity(0.4)
                          : const Color(0xFF888888).withOpacity(0.4),
                      width: 0.5)),
                  child: Text(
                    catName == 'physical' ? 'Ataque Físico'
                        : catName == 'special' ? 'Ataque Especial' : 'Ataque de Status',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                      color: catName == 'physical' ? const Color(0xFFE24B4A)
                          : catName == 'special' ? const Color(0xFF9C27B0)
                          : const Color(0xFF666666)))),
              ]),
              const SizedBox(height: 12),
              if (loading)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else
                Row(children: [
                  _statBox(context, power != null ? '$power' : '—', 'Poder'),
                  const SizedBox(width: 8),
                  _statBox(context, acc != null ? '$acc%' : '—', 'Precisão'),
                  const SizedBox(width: 8),
                  _statBox(context, pp != null ? '$pp' : '—', 'PP'),
                ]),
              const SizedBox(height: 12),
              if (desc.isNotEmpty) Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8)),
                child: Text(desc, style: TextStyle(fontSize: 12,
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

class EvoChainWidget extends StatefulWidget {
  final List<Map<String, dynamic>> chain;
  const EvoChainWidget({super.key, required this.chain});

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildWidgets(context),
    );
  }

  List<Widget> _buildWidgets(BuildContext ctx) {
    final ws = <Widget>[];
    for (int i = 0; i < widget.chain.length; i++) {
      final e = widget.chain[i];
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
            // Badges de tipo
            if (types.isNotEmpty)
              Wrap(
                spacing: 3, runSpacing: 3,
                alignment: WrapAlignment.center,
                children: types.map((t) {
                  final tc = TypeColors.fromType(ptType(t));
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tc, borderRadius: BorderRadius.circular(4)),
                    child: Text(ptType(t), style: TextStyle(
                      fontSize: 8, fontWeight: FontWeight.w700,
                      color: typeTextColor(tc))),
                  );
                }).toList(),
              )
            else
              // Placeholder enquanto carrega
              const SizedBox(height: 16),
          ],
        ),
      ));

      if (i < widget.chain.length - 1) {
        final cond = widget.chain[i + 1]['condition'] as String;
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
                  style: TextStyle(fontSize: 8,
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
          borderRadius: BorderRadius.circular(4),
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
  final mults = <String, double>{};
  for (final type in types) {
    for (final entry in (tc[type.toLowerCase()] ?? {}).entries) {
      final k = entry.key; // mantém em EN — ptType() aplicado na UI
      mults[k] = (mults[k] ?? 1.0) * entry.value;
    }
  }
  return mults;
}

// função com _ para compatibilidade interna
Map<String, double> _calculateWeaknesses(List<String> types) => calculateWeaknesses(types);
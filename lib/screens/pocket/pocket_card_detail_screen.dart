import 'package:flutter/material.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart'
    show PokeballLoader, translateFlavorText;
import 'package:pokedex_tracker/services/tcg_pocket_service.dart';
import 'package:pokedex_tracker/screens/pocket/pocket_rarity_widget.dart';
import 'package:pokedex_tracker/screens/pocket/pocket_energy_icon.dart';

class PocketCardDetailScreen extends StatefulWidget {
  final PocketCardBrief card;
  final String          setId;
  final int?            totalCards; // total de cartas do set

  const PocketCardDetailScreen({
    super.key,
    required this.card,
    required this.setId,
    this.totalCards,
  });

  @override
  State<PocketCardDetailScreen> createState() => _PocketCardDetailScreenState();
}

class _PocketCardDetailScreenState extends State<PocketCardDetailScreen> {
  PocketCardDetail?    _detail;
  bool                 _loadingDetail = true;
  Map<String, String>  _pt            = {};
  String?              _descriptionPt;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    try {
      String localId = widget.card.localId;
      final imgUrl = widget.card.imageUrlLow;
      if (imgUrl != null) {
        final parts = imgUrl.split('/');
        if (parts.length >= 2) localId = parts[parts.length - 2];
      }

      // 1. Buscar dados da carta
      final detail = await TcgPocketService.fetchCard(
          widget.card.id, setId: widget.setId, localId: localId);

      if (detail == null) {
        if (mounted) setState(() => _loadingDetail = false);
        return;
      }

      // 2. Traduzir descrição usando translateFlavorText (Google Translate + MyMemory)
      //    Sempre retorna algo — nunca fica em loop
      String? descPt;
      final descEn = detail.description;
      if (descEn != null && descEn.isNotEmpty) {
        descPt = await translateFlavorText(descEn);
        // translateFlavorText retorna o texto original se ambas as APIs falharem
        // Nesse caso omitimos — só exibimos se a tradução foi bem-sucedida
        if (descPt == descEn) descPt = null;
      }

      // 3. Traduzir habilidades — nome e efeito via translateFlavorText
      final Map<String, String> pt = {};
      for (int i = 0; i < detail.abilities.length; i++) {
        final ab = detail.abilities[i];
        if (ab.name.isNotEmpty) {
          final namePt = await translateFlavorText(ab.name);
          if (namePt != ab.name) pt['ability_name_$i'] = namePt;
        }
        if (ab.effect != null && ab.effect!.isNotEmpty) {
          final effPt = await translateFlavorText(ab.effect!);
          if (effPt != ab.effect) pt['ability_effect_$i'] = effPt;
        }
      }

      // 4. Traduzir ataques — mapa estático primeiro, translateFlavorText para os que faltam
      for (int i = 0; i < detail.attacks.length; i++) {
        final atk = detail.attacks[i];

        // Nome: mapa estático → tradução via translateFlavorText
        final nameStatic = _PocketTranslations.translateAttackName(atk.name);
        if (nameStatic == atk.name && atk.name.isNotEmpty) {
          final namePt = await translateFlavorText(atk.name);
          if (namePt != atk.name) pt['attack_$i'] = namePt;
        }

        // Efeito: mapa estático → tradução via translateFlavorText
        if (atk.effect != null && atk.effect!.isNotEmpty) {
          final effStatic = _PocketTranslations.translateAttackEffect(atk.effect);
          if (effStatic == atk.effect) {
            final effPt = await translateFlavorText(atk.effect!);
            if (effPt != atk.effect) pt['attackEffect_$i'] = effPt;
          }
        }
      }

      if (mounted) setState(() {
        _detail        = detail;
        _pt            = pt;
        _descriptionPt = descPt;
        _loadingDetail = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }



  String? get _highUrl {
    final low = widget.card.imageUrlLow;
    if (low == null) return null;
    return low.replaceAll('/low.webp', '/high.webp');
  }

  // Nome do Pokémon: PT se disponível, senão EN
  String get _displayName => _pt['name'] ?? widget.card.name;

  // Descrição em PT (via /pt/ API ou MyMemory com cache local)
  String? get _displayDescription => _descriptionPt;

  // Nome do ataque: PT se disponível, senão EN
  String _attackName(int i, PocketAttack atk) =>
      _pt['attack_$i'] ?? _PocketTranslations.translateAttackName(atk.name);

  // Efeito do ataque: PT via API > tradução manual > EN
  String? _attackEffect(int i, PocketAttack atk) {
    final pt = _pt['attackEffect_$i'];
    if (pt != null && pt.isNotEmpty) return pt;
    return _PocketTranslations.translateAttackEffect(atk.effect);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_displayName),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Imagem ────────────────────────────────────────────
            Container(
              color: scheme.surfaceContainerLow,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: AspectRatio(
                    aspectRatio: 0.714,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _highUrl != null
                          ? Image.network(
                              _highUrl!,
                              fit: BoxFit.cover,
                              // Enquanto a high carrega, exibe a low já em cache
                              frameBuilder: (ctx, child, frame, wasSynchronouslyLoaded) {
                                if (wasSynchronouslyLoaded || frame != null) return child;
                                // high ainda carregando — mostrar low do cache
                                final low = widget.card.imageUrlLow;
                                return low != null
                                    ? Image.network(low, fit: BoxFit.cover)
                                    : Container(
                                        color: scheme.surfaceContainerHigh,
                                        child: Center(child: PokeballLoader.small()),
                                      );
                              },
                              errorBuilder: (_, __, ___) => Container(
                                color: scheme.surfaceContainerHigh,
                                child: Icon(Icons.style_outlined, size: 48,
                                    color: scheme.onSurfaceVariant.withOpacity(0.3)),
                              ),
                            )
                          : Container(
                              color: scheme.surfaceContainerHigh,
                              child: Icon(Icons.style_outlined, size: 48,
                                  color: scheme.onSurfaceVariant.withOpacity(0.3)),
                            ),
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Nome + ícone(s) de tipo (junto ao nome) ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _displayName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      if (_detail != null && _detail!.types.isNotEmpty)
                        ...(_detail!.types.map((t) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: PocketEnergyIcon(type: t, size: 26),
                        ))),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // ── Nome do set ───────────────────────────────
                  Text(
                    kPocketSetMeta[widget.setId]?.namePt ?? widget.setId,
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                  ),

                  // ── Pacotes onde a carta é encontrada ─────────
                  if (_detail != null && _detail!.boosters.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Pacotes: ${_detail!.boosters.join(', ')}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Tabela stats ──────────────────────────────
                  _buildStatsTable(scheme, isDark),

                  const SizedBox(height: 16),

                  // ── Loading ───────────────────────────────────
                  if (_loadingDetail)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        PokeballLoader.small(),
                        const SizedBox(width: 8),
                        Text('Carregando detalhes...',
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      ]),
                    ),

                  // ── Habilidades ───────────────────────────────
                  if (_detail != null && _detail!.abilities.isNotEmpty) ...[
                    _buildAbilities(scheme),
                    const SizedBox(height: 16),
                  ],

                  // ── Ataques ───────────────────────────────────
                  if (_detail != null && _detail!.attacks.isNotEmpty) ...[
                    _buildAttacks(scheme, isDark),
                    const SizedBox(height: 16),
                  ],

                  // ── Descrição do Pokédex ──────────────────────
                  if (_displayDescription != null && _displayDescription!.isNotEmpty) ...[
                    Text('Descrição da Pokédex',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text(
                      _displayDescription!,
                      style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic,
                          color: scheme.onSurfaceVariant, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Trainer ───────────────────────────────────
                  if (_detail != null &&
                      _detail!.category == 'Trainer' &&
                      _detail!.trainerEffect != null &&
                      _detail!.trainerEffect!.isNotEmpty) ...[
                    Text(_trainerLabel(_detail!.trainerType),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.teal.withOpacity(0.3)),
                      ),
                      child: Text(_detail!.trainerEffect!,
                          style: TextStyle(fontSize: 13, height: 1.5,
                              color: scheme.onSurface.withOpacity(0.85))),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tabela de stats ──────────────────────────────────────────
  Widget _buildStatsTable(ColorScheme scheme, bool isDark) {
    // Linha 1: Número | Raridade | Evolução
    final row1 = <_Cell>[
      _Cell(
        label: 'Número',
        value: widget.totalCards != null
            ? '${widget.card.localId}/${widget.totalCards.toString().padLeft(3, "0")}'
            : widget.card.localId,
      ),
    ];
    // Raridade vem após Número, antes da Evolução (tratada como widget inline)
    // Evolução adicionada por último
    final stageValue = _detail?.stage != null ? _stageLabel(_detail!.stage!) : null;

    // Linha 2: HP | Fraqueza | Custo de Recuo
    Widget? hpWidget;
    if (_detail?.hp != null) {
      hpWidget = Text('${_detail!.hp}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700));
    }

    Widget? weakWidget;
    if (_detail?.weaknessType != null) {
      final val = _detail!.weaknessValue != null ? '+${_detail!.weaknessValue}' : '';
      weakWidget = Row(mainAxisSize: MainAxisSize.min, children: [
        PocketEnergyIcon(type: _detail!.weaknessType!, size: 20),
        const SizedBox(width: 4),
        Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ]);
    }

    Widget? retreatWidget;
    if (_detail?.retreat != null && _detail!.retreat! > 0) {
      retreatWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_detail!.retreat!.clamp(0, 5), (_) => Padding(
          padding: const EdgeInsets.only(right: 3),
          child: PocketEnergyIcon(type: 'Colorless', size: 16),
        )),
      );
    } else if (_detail?.retreat == 0) {
      retreatWidget = const Text('0',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700));
    }

    final hasRow2 = hpWidget != null || weakWidget != null || retreatWidget != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        children: [
          // Linha 1: Número | Raridade | Evolução
          IntrinsicHeight(
            child: Row(children: [
              // Número
              for (int i = 0; i < row1.length; i++) ...[
                if (i > 0) VerticalDivider(width: 1, thickness: 0.5, color: scheme.outlineVariant),
                Expanded(child: _buildStatCell(
                  label: row1[i].label,
                  value: row1[i].value,
                  scheme: scheme,
                )),
              ],
              // Raridade
              if ((_detail?.rarity ?? widget.card.rarity) != null) ...[
                VerticalDivider(width: 1, thickness: 0.5, color: scheme.outlineVariant),
                Expanded(child: _buildStatCellWidget(
                  label: 'Raridade',
                  widget: PocketRarityBadge(
                    rarity: _detail?.rarity ?? widget.card.rarity!,
                    expanded: true,
                  ),
                  scheme: scheme,
                )),
              ],
              // Evolução
              if (stageValue != null) ...[
                VerticalDivider(width: 1, thickness: 0.5, color: scheme.outlineVariant),
                Expanded(child: _buildStatCell(
                  label: 'Evolução',
                  value: stageValue,
                  scheme: scheme,
                )),
              ],
            ]),
          ),
          // Linha 2: HP | Fraqueza | Custo de Recuo
          if (hasRow2) ...[
            Divider(height: 1, thickness: 0.5, color: scheme.outlineVariant),
            IntrinsicHeight(
              child: Row(children: [
                if (hpWidget != null) ...[
                  Expanded(child: _buildStatCellWidget(
                      label: 'HP', widget: hpWidget, scheme: scheme)),
                  if (weakWidget != null || retreatWidget != null)
                    VerticalDivider(width: 1, thickness: 0.5, color: scheme.outlineVariant),
                ],
                if (weakWidget != null) ...[
                  Expanded(child: _buildStatCellWidget(
                      label: 'Fraqueza', widget: weakWidget, scheme: scheme)),
                  if (retreatWidget != null)
                    VerticalDivider(width: 1, thickness: 0.5, color: scheme.outlineVariant),
                ],
                if (retreatWidget != null)
                  Expanded(child: _buildStatCellWidget(
                      label: 'Custo de Recuo', widget: retreatWidget, scheme: scheme)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCell({
    required String label, required String value, required ColorScheme scheme}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: scheme.onSurface)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _buildStatCellWidget({
    required String label, required Widget widget, required ColorScheme scheme}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: scheme.onSurface)),
        const SizedBox(height: 4),
        widget,
      ]),
    );
  }

  // ── Habilidades ──────────────────────────────────────────────
  Widget _buildAbilities(ColorScheme scheme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Habilidade${_detail!.abilities.length > 1 ? 's' : ''}',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      ...List.generate(_detail!.abilities.length, (i) {
        final a = _detail!.abilities[i];
        final namePt   = _pt['ability_name_$i']   ?? a.name;
        final effectPt = _pt['ability_effect_$i']  ?? a.effect;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.purple.withOpacity(0.25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.purple.shade600,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(a.type ?? 'Habilidade',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(namePt, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700))),
            ]),
            if (effectPt != null && effectPt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(effectPt, style: TextStyle(fontSize: 13, height: 1.4,
                  color: scheme.onSurface.withOpacity(0.8))),
            ],
          ]),
        );
      }),
    ]);
  }

  // ── Ataques ──────────────────────────────────────────────────
  Widget _buildAttacks(ColorScheme scheme, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Ataques', style: TextStyle(fontSize: 13,
          fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: scheme.outlineVariant, width: 0.5),
        ),
        child: Column(children: [
          for (int i = 0; i < _detail!.attacks.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  // Ícones de energia do custo
                  if (_detail!.attacks[i].cost.isNotEmpty) ...[
                    ..._detail!.attacks[i].cost.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: PocketEnergyIcon(type: c, size: 20),
                    )),
                    const SizedBox(width: 6),
                  ],
                  // Nome (PT ou EN)
                  Expanded(child: Text(_attackName(i, _detail!.attacks[i]),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700))),
                  // Dano
                  if (_detail!.attacks[i].damage != null &&
                      _detail!.attacks[i].damage!.isNotEmpty)
                    Text(_detail!.attacks[i].damage!,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                ]),
                // Efeito (PT ou EN)
                if (_attackEffect(i, _detail!.attacks[i]) != null &&
                    _attackEffect(i, _detail!.attacks[i])!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(_attackEffect(i, _detail!.attacks[i])!,
                      style: TextStyle(fontSize: 12, height: 1.4,
                          color: scheme.onSurface.withOpacity(0.7))),
                ],
              ]),
            ),
          ],
        ]),
      ),
    ]);
  }

  String _stageLabel(String s) {
    switch (s.toLowerCase()) {
      case 'basic':  return 'Básico';
      case 'stage1': return 'Estágio 1';
      case 'stage2': return 'Estágio 2';
      default:       return s;
    }
  }

  String _trainerLabel(String? t) {
    switch (t?.toLowerCase()) {
      case 'item':      return 'Item';
      case 'supporter': return 'Suporte';
      case 'stadium':   return 'Estádio';
      case 'tool':      return 'Ferramenta';
      default:          return t ?? 'Efeito';
    }
  }
}


class _Cell {
  final String label;
  final String value;
  const _Cell({required this.label, required this.value});
}

// ─── Traduções manuais TCG Pocket ────────────────────────────────
class _PocketTranslations {
  static const Map<String, String> attackNames = {
    "Vine Whip":       "Chicote de Cipó",
    "Razor Leaf":      "Folha Navalha",
    "Mega Drain":      "Megassução",
    "Solar Beam":      "Raio Solar",
    "Petal Dance":     "Dança de Pétalas",
    "Seed Bomb":       "Bomba de Semente",
    "Leech Seed":      "Semente Parasita",
    "Scratch":         "Arranhão",
    "Ember":           "Brasa",
    "Flamethrower":    "Lança-Chamas",
    "Fire Spin":       "Rodoflama",
    "Heat Blast":      "Explosão de Calor",
    "Inferno":         "Inferno",
    "Tail Whip":       "Chicote de Cauda",
    "Water Gun":       "Pistola d'Água",
    "Bubble":          "Bolha",
    "Surf":            "Surfada",
    "Hydro Pump":      "Hidrobomba",
    "Thunder Shock":   "Trovão",
    "Thunder":         "Raio",
    "Thunderbolt":     "Trovoada",
    "Quick Attack":    "Ataque Rápido",
    "Tackle":          "Investida",
    "Pound":           "Soco",
    "Bite":            "Mordida",
    "Slash":           "Corte",
    "Body Slam":       "Golpe Duplo",
    "Headbutt":        "Cabeçada",
    "Hyper Beam":      "Hiperraio",
    "Psybeam":         "Psicoraio",
    "Confusion":       "Confusão",
    "Psychic":         "Psíquico",
    "Night Slash":     "Corte Noturno",
    "Shadow Ball":     "Bola Sombria",
    "Poison Sting":    "Ferrão Venenoso",
    "Sludge":          "Lodo",
    "Dig":             "Cavar",
    "Earthquake":      "Terremoto",
    "Rock Throw":      "Arremesso de Pedra",
    "Rock Slide":      "Avalanche",
    "Karate Chop":     "Golpe Caratê",
    "Low Kick":        "Pontapé Baixo",
    "Ice Beam":        "Raio de Gelo",
    "Blizzard":        "Nevasca",
    "Dragon Rage":     "Ira do Dragão",
    "Leer":            "Olhar Feroz",
    "Growl":           "Grunhido",
    "Feint Attack":    "Ataque Fingido",
    "Whirlpool":       "Redemoinho",
    "Smash":           "Esmagamento",
    "Double Slap":     "Tapa Duplo",
    "Stomp":           "Pisão",
    "Horn Attack":     "Ataque de Chifre",
    "Flame Charge":    "Carga Ígnea",
    "Burn Out":        "Esgotamento",
    "Power Whip":      "Chicote Poderoso",
    "Leaf Blade":      "Folha Espada",
    "Gnaw":            "Roer",
    "Fury Swipes":     "Garras Furiosas",
    "Electro Ball":    "Bola Elétrica",
    "Ion Deluge":      "Dilúvio de Íons",
    "Spark":           "Faísca",
    "Tail Smash":      "Cauda Destruidora",
    "Feelin' Fine":    "Me Sentindo Bem",
    "Poisonpowder":    "Pó Venenoso",
    "Sleep Powder":    "Pó do Sono",
    "Bullet Seed":     "Semente Bala",
    "Energy Ball":     "Bola de Energia",
    "Flash Cannon":    "Canhão de Luz",
    "Metal Claw":      "Garra Metálica",
    "Iron Tail":       "Cauda de Ferro",
    "Mud Slap":        "Tapa de Lama",
    "Muddy Water":     "Água Turva",
    "Wing Attack":     "Ataque-Asa",
    "Aerial Ace":      "Ás Aéreo",
    "Drill Peck":      "Bicada Perfurante",
    "Fury Attack":     "Ataque Furioso",
    "Peck":            "Bicada",
    "Sand Attack":     "Areia nos Olhos",
    "Double-Edge":     "Choque do Destino",
    "Take Down":       "Derrubar",
    "Return":          "Retribuir",
    "Outrage":         "Fúria",
    "Hyper Fang":      "Presa Suprema",
    "Super Fang":      "Superfresa",
    "Bind":            "Amarrar",
    "Wrap":            "Enrolar",
    "Glare":           "Olhar Intimidador",
    "Smokescreen":     "Cortina de Fumaça",
    "Lunge":           "Arremetida",
    "String Shot":     "Fio de Seda",
    "Bug Bite":        "Mordida de Inseto",
    "Signal Beam":     "Raio Sinal",
    "Struggle Bug":    "Resistência",
    "Thunder Wave":    "Onda Trovão",
    "Discharge":       "Descarga",
    "Zap Cannon":      "Canhão Elétrico",
    "Charm":           "Encanto",
    "Moonblast":       "Luablast",
    "Dazzling Gleam":  "Brilho Ofuscante",
    "Gust":            "Rajada",
    "Whirlwind":       "Vento Giratório",
    "Sky Attack":      "Ataque Aéreo",
    "Leafage":         "Foliagem",
    "Pounce":          "Salto",
    "Flare":           "Clarão",
  };

  static const Map<String, String> attackEffects = {
    "Flip a coin. If tails, this attack does nothing.":
        "Lance uma moeda. Se der coroa, este ataque não faz nada.",
    "Flip a coin. If heads, this attack does nothing.":
        "Lance uma moeda. Se der cara, este ataque não faz nada.",
    "Draw 3 cards.": "Compre 3 cartas.",
    "Draw 2 cards.": "Compre 2 cartas.",
    "Your opponent's Active Pokemon is now Poisoned.":
        "O Pokémon Ativo do oponente fica Envenenado.",
    "Your opponent's Active Pokemon is now Paralyzed.":
        "O Pokémon Ativo do oponente fica Paralisado.",
    "Your opponent's Active Pokemon is now Asleep.":
        "O Pokémon Ativo do oponente fica Adormecido.",
    "Your opponent's Active Pokemon is now Burned.":
        "O Pokémon Ativo do oponente fica Queimado.",
    "Discard a random Energy from your opponent's Active Pokemon.":
        "Descarte uma Energia aleatória do Pokémon Ativo do oponente.",
    "Heal 20 damage from this Pokemon.": "Cure 20 de dano deste Pokémon.",
    "Heal 30 damage from this Pokemon.": "Cure 30 de dano deste Pokémon.",
    "Heal 20 damage from this Pokémon.": "Cure 20 de dano deste Pokémon.",
    "Heal 30 damage from this Pokémon.": "Cure 30 de dano deste Pokémon.",
  };

  static String translateAttackName(String name) =>
      attackNames[name] ?? name;

  static String? translateAttackEffect(String? effect) {
    if (effect == null || effect.isEmpty) return effect;
    return attackEffects[effect] ?? effect;
  }
}

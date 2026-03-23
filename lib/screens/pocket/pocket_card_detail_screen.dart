import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    try {
      final imgUrl = widget.card.imageUrlLow;
      String localId = widget.card.localId;
      if (imgUrl != null) {
        final parts = imgUrl.split('/');
        if (parts.length >= 2) localId = parts[parts.length - 2];
      }

      // Buscar EN e PT em paralelo com tipos corretos
      final detailFuture = TcgPocketService.fetchCard(
        widget.card.id, setId: widget.setId, localId: localId);
      final ptFuture = TcgPocketService.fetchCardPt(
        widget.card.id, setId: widget.setId, localId: localId);

      final detail = await detailFuture;
      final pt     = await ptFuture;

      if (mounted) setState(() {
        _detail        = detail;
        _pt            = pt;
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

  // Descrição: PT via API > EN (flavor texts são específicos por carta,
  // não há dicionário viável — mostrar em EN com label correto)
  String? get _displayDescription {
    final pt = _pt['description'];
    if (pt != null && pt.isNotEmpty) return pt;
    return _detail?.description;
  }

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
                              loadingBuilder: (_, child, p) => p == null
                                  ? child
                                  : Container(
                                      color: scheme.surfaceContainerHigh,
                                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    ),
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

                  // ── Raridade ──────────────────────────────────
                  if (widget.card.rarity != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      PocketRarityBadge(rarity: widget.card.rarity!, expanded: true),
                      const SizedBox(width: 6),
                      Text(widget.card.rarity!,
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ]),
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
                        SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: scheme.onSurfaceVariant)),
                        const SizedBox(width: 8),
                        Text('Carregando detalhes...',
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      ]),
                    ),

                  // ── Descrição do Pokédex ──────────────────────
                  if (_displayDescription != null && _displayDescription!.isNotEmpty) ...[
                    Text('Descrição do Pokédex',
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
    final cells = <_Cell>[
      _Cell(
        label: 'Número',
        value: widget.totalCards != null
            ? '${widget.card.localId}/${widget.totalCards.toString().padLeft(3, "0")}'
            : widget.card.localId,
      ),
    ];
    if (_detail?.stage != null)
      cells.add(_Cell(label: 'Evolução', value: _stageLabel(_detail!.stage!)));
    if (_detail?.hp != null)
      cells.add(_Cell(label: 'HP', value: '${_detail!.hp}'));

    // Fraqueza: ícone + valor
    Widget? weakWidget;
    if (_detail?.weaknessType != null) {
      final val = _detail!.weaknessValue != null ? '+${_detail!.weaknessValue}' : '';
      weakWidget = Row(mainAxisSize: MainAxisSize.min, children: [
        PocketEnergyIcon(type: _detail!.weaknessType!, size: 20),
        const SizedBox(width: 4),
        Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ]);
    }

    // Recuo: ícones Colorless
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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        children: [
          // Linha 1: células de texto
          IntrinsicHeight(
            child: Row(children: [
              for (int i = 0; i < cells.length; i++) ...[
                if (i > 0) VerticalDivider(width: 1, thickness: 0.5, color: scheme.outlineVariant),
                Expanded(child: _buildStatCell(
                  label: cells[i].label,
                  value: cells[i].value,
                  scheme: scheme,
                )),
              ],
            ]),
          ),
          // Linha 2: fraqueza + recuo (se disponíveis)
          if (weakWidget != null || retreatWidget != null) ...[
            Divider(height: 1, thickness: 0.5, color: scheme.outlineVariant),
            IntrinsicHeight(
              child: Row(children: [
                if (weakWidget != null) ...[
                  Expanded(child: _buildStatCellWidget(
                      label: 'Fraqueza', widget: weakWidget, scheme: scheme)),
                ],
                if (weakWidget != null && retreatWidget != null)
                  VerticalDivider(width: 1, thickness: 0.5, color: scheme.outlineVariant),
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
      ..._detail!.abilities.map((a) => Container(
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
            Expanded(child: Text(a.name, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700))),
          ]),
          if (a.effect != null && a.effect!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(a.effect!, style: TextStyle(fontSize: 13, height: 1.4,
                color: scheme.onSurface.withOpacity(0.8))),
          ],
        ]),
      )),
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
// Usadas como fallback quando a API /pt/ não retorna dados
class _PocketTranslations {
  // Nomes de ataques comuns
  static const Map<String, String> attackNames = {
    'Vine Whip': 'Chicote de Cipó',
    'Razor Leaf': 'Folha Navalha',
    'Mega Drain': 'Megassução',
    'Solar Beam': 'Raio Solar',
    'Petal Dance': 'Dança de Pétalas',
    'Seed Bomb': 'Bomba de Semente',
    'Leech Seed': 'Semente Parasita',
    'Scratch': 'Arranhão',
    'Ember': 'Brasa',
    'Flamethrower': 'Lança-Chamas',
    'Fire Spin': 'Rodoflama',
    'Heat Blast': 'Explosão de Calor',
    'Inferno': 'Inferno',
    'Tail Whip': 'Chicote de Cauda',
    'Water Gun': 'Pistola d'Água',
    'Bubble': 'Bolha',
    'Surf': 'Surfada',
    'Hydro Pump': 'Hidrobomba',
    'Thunder Shock': 'Trovão',
    'Thunder': 'Raio',
    'Thunderbolt': 'Trovoada',
    'Quick Attack': 'Ataque Rápido',
    'Tackle': 'Investida',
    'Pound': 'Soco',
    'Bite': 'Mordida',
    'Slash': 'Corte',
    'Body Slam': 'Golpe Duplo',
    'Headbutt': 'Cabeçada',
    'Hyper Beam': 'Hiperraio',
    'Psybeam': 'Psicoraio',
    'Confusion': 'Confusão',
    'Psychic': 'Psíquico',
    'Night Slash': 'Corte Noturno',
    'Shadow Ball': 'Bola Sombria',
    'Poison Sting': 'Ferrão Venenoso',
    'Sludge': 'Lodo',
    'Dig': 'Cavar',
    'Earthquake': 'Terremoto',
    'Rock Throw': 'Arremesso de Pedra',
    'Rock Slide': 'Avalanche',
    'Karate Chop': 'Golpe Caratê',
    'Low Kick': 'Pontapé Baixo',
    'Ice Beam': 'Raio de Gelo',
    'Blizzard': 'Nevasca',
    'Dragon Rage': 'Ira do Dragão',
    'Leer': 'Olhar Feroz',
    'Growl': 'Grunhido',
    'Feint Attack': 'Ataque Fingido',
    'Whirlpool': 'Redemoinho',
    'Smash': 'Esmagamento',
    'Double Slap': 'Tapa Duplo',
    'Stomp': 'Pisão',
    'Horn Attack': 'Ataque de Chifre',
    'Flame Charge': 'Carga Ígnea',
    'Burn Out': 'Esgotamento',
    'Power Whip': 'Chicote Poderoso',
    'Leaf Blade': 'Folha Espada',
    'Gnaw': 'Roer',
    'Fury Swipes': 'Garras Furiosas',
    'Electro Ball': 'Bola Elétrica',
    'Ion Deluge': 'Dilúvio de Íons',
    'Spark': 'Faísca',
    'Tail Smash': 'Cauda Destruidora',
    'Feelin' Fine': 'Me Sentindo Bem',
    'Poisonpowder': 'Pó Venenoso',
    'Sleep Powder': 'Pó do Sono',
    'Bullet Seed': 'Semente Bala',
    'Energy Ball': 'Bola de Energia',
    'Flash Cannon': 'Canhão de Luz',
    'Metal Claw': 'Garra Metálica',
    'Iron Tail': 'Cauda de Ferro',
    'Mud Slap': 'Tapa de Lama',
    'Muddy Water': 'Água Turva',
    'Wing Attack': 'Ataqueasa',
    'Aerial Ace': 'Ás Aéreo',
    'Drill Peck': 'Bicada Perfurante',
    'Fury Attack': 'Ataque Furioso',
    'Peck': 'Bicada',
    'Sand Attack': 'Areia nos Olhos',
    'Double-Edge': 'Choque do Destino',
    'Take Down': 'Derrubar',
    'Return': 'Retribuir',
    'Outrage': 'Fúria',
    'Hyper Fang': 'Presa Suprema',
    'Super Fang': 'Superfresa',
    'Bind': 'Amarrar',
    'Wrap': 'Enrolar',
    'Glare': 'Olhar Intimidador',
    'Smokescreen': 'Cortina de Fumaça',
    'Lunge': 'Arremetida',
    'String Shot': 'Fio de Seda',
    'Bug Bite': 'Mordida de Inseto',
    'Signal Beam': 'Raio Sinal',
    'Struggle Bug': 'Resistência',
    'Thunder Wave': 'Onda Trovão',
    'Discharge': 'Descarga',
    'Zap Cannon': 'Canhão Elétrico',
    'Charm': 'Encanto',
    'Moonblast': 'Luablast',
    'Dazzling Gleam': 'Brilho Ofuscante',
    'Gust': 'Rajada',
    'Whirlwind': 'Vento Giratório',
    'Sky Attack': 'Ataque Aéreo',
  };

  // Efeitos de ataques comuns
  static const Map<String, String> attackEffects = {
    'Flip a coin. If tails, this attack does nothing.':
        'Lance uma moeda. Se der coroa, este ataque não faz nada.',
    'Flip a coin. If heads, this attack does nothing.':
        'Lance uma moeda. Se der cara, este ataque não faz nada.',
    'Draw 3 cards.': 'Compre 3 cartas.',
    'Draw 2 cards.': 'Compre 2 cartas.',
    'Your opponent's Active Pokémon is now Poisoned.':
        'O Pokémon Ativo do oponente fica Envenenado.',
    'Your opponent's Active Pokémon is now Paralyzed.':
        'O Pokémon Ativo do oponente fica Paralisado.',
    'Your opponent's Active Pokémon is now Asleep.':
        'O Pokémon Ativo do oponente fica Adormecido.',
    'Your opponent's Active Pokémon is now Burned.':
        'O Pokémon Ativo do oponente fica Queimado.',
    'Discard a random Energy from your opponent's Active Pokémon.':
        'Descarte uma Energia aleatória do Pokémon Ativo do oponente.',
    'Heal 20 damage from this Pokémon.':
        'Cure 20 de dano deste Pokémon.',
    'Heal 30 damage from this Pokémon.':
        'Cure 30 de dano deste Pokémon.',
    'During your opponent's next turn, this Pokémon takes −20 damage from attacks.':
        'Durante o próximo turno do oponente, este Pokémon recebe −20 de dano de ataques.',
  };

  static String translateAttackName(String name) =>
      attackNames[name] ?? name;

  static String? translateAttackEffect(String? effect) {
    if (effect == null || effect.isEmpty) return effect;
    return attackEffects[effect] ?? effect;
  }
}

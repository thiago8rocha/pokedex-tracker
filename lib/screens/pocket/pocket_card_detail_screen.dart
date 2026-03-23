import 'package:flutter/material.dart';
import 'package:pokedex_tracker/services/tcg_pocket_service.dart';
import 'package:pokedex_tracker/screens/pocket/pocket_rarity_widget.dart';

class PocketCardDetailScreen extends StatefulWidget {
  final String cardId;
  final String setId;
  final String localId;

  const PocketCardDetailScreen({
    super.key,
    required this.cardId,
    required this.setId,
    required this.localId,
  });

  @override
  State<PocketCardDetailScreen> createState() => _PocketCardDetailScreenState();
}

class _PocketCardDetailScreenState extends State<PocketCardDetailScreen> {
  PocketCardDetail? _card;
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCard();
  }

  Future<void> _loadCard() async {
    setState(() { _loading = true; _error = null; });
    try {
      final localId0 = widget.localId;
      final n        = int.tryParse(localId0);
      final localId1 = n != null ? n.toString() : localId0;

      // Montar as URLs que serão tentadas
      const base = 'https://api.tcgdex.net/v2/en';
      final url0 = '$base/sets/${widget.setId}/$localId0';
      final url1 = '$base/sets/${widget.setId}/$localId1';

      PocketCardDetail? card;

      card = await TcgPocketService.fetchCard(
        widget.cardId,
        setId:   widget.setId,
        localId: localId0,
      );

      if (card == null && localId0 != localId1) {
        card = await TcgPocketService.fetchCard(
          '${widget.setId}-$localId1',
          setId:   widget.setId,
          localId: localId1,
        );
      }

      if (mounted) {
        setState(() {
          _card    = card;
          _loading = false;
          if (card == null) {
            _error = 'Não encontrada. Tente novamente.';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Exceção: ${e.runtimeType}\n${e.toString().substring(0, e.toString().length.clamp(0, 200))}';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_card?.name ?? 'Carta #${widget.localId}'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const _DetailSkeleton()
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadCard)
              : _CardDetailBody(card: _card!),
    );
  }
}

// ─── Corpo do detalhe ─────────────────────────────────────────────

class _CardDetailBody extends StatelessWidget {
  final PocketCardDetail card;
  const _CardDetailBody({required this.card});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Imagem da carta ──────────────────────────────────
          _CardImage(card: card),
          const SizedBox(height: 20),

          // ── 2. Nome, tipo(s) e raridade ─────────────────────────
          _NameTypeRarity(card: card),
          const SizedBox(height: 16),

          // ── 3. Número, estágio, HP, fraqueza ────────────────────
          if (card.category == 'Pokemon') ...[
            _StatsRow(card: card),
            const SizedBox(height: 16),
          ],

          // ── 4. Descrição (flavor text) ───────────────────────────
          if (card.description != null && card.description!.isNotEmpty) ...[
            _DescriptionCard(text: card.description!),
            const SizedBox(height: 16),
          ],

          // ── 5. Habilidades ───────────────────────────────────────
          if (card.abilities.isNotEmpty) ...[
            _AbilitiesSection(abilities: card.abilities),
            const SizedBox(height: 16),
          ],

          // ── 6. Ataques ───────────────────────────────────────────
          if (card.attacks.isNotEmpty) ...[
            _AttacksSection(attacks: card.attacks),
            const SizedBox(height: 16),
          ],

          // ── 7. Efeito (Trainer) ──────────────────────────────────
          if (card.category == 'Trainer' &&
              card.trainerEffect != null &&
              card.trainerEffect!.isNotEmpty) ...[
            _TrainerEffectCard(
              effect:      card.trainerEffect!,
              trainerType: card.trainerType,
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

// ─── Imagem da carta ─────────────────────────────────────────────

class _CardImage extends StatelessWidget {
  final PocketCardDetail card;
  const _CardImage({required this.card});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: AspectRatio(
          aspectRatio: 0.714, // proporção padrão de carta TCG (63×88mm)
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12), // carta TCG tem cantos arredondados
              child: card.imageUrlHigh != null
                  ? Image.network(
                      card.imageUrlHigh!,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: scheme.surfaceContainerHigh,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: scheme.surfaceContainerHigh,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              size: 48,
                              color: scheme.onSurfaceVariant.withOpacity(0.4),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              card.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      color: scheme.surfaceContainerHigh,
                      child: Center(
                        child: Icon(
                          Icons.style_outlined,
                          size: 64,
                          color: scheme.onSurfaceVariant.withOpacity(0.3),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Nome, tipo(s) e raridade ─────────────────────────────────────

class _NameTypeRarity extends StatelessWidget {
  final PocketCardDetail card;
  const _NameTypeRarity({required this.card});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Nome
        Text(
          card.name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Tipos (usando as cores do TypeColors do projeto)
        if (card.types.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: card.types.map<Widget>((t) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _TypeChip(typeName: t),
            )).toList(),
          ),

        const SizedBox(height: 8),

        // Raridade
        if (card.rarity != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PocketRarityBadge(rarity: card.rarity!, expanded: true),
              const SizedBox(width: 6),
              Text(
                card.rarity!,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ─── Chip de tipo (compatível com o projeto) ──────────────────────

class _TypeChip extends StatelessWidget {
  final String typeName; // nome em inglês vindo da API (Fire, Water...)
  const _TypeChip({required this.typeName});

  // Mesmas cores do type_colors.dart do projeto
  static const Map<String, Color> _typeColors = {
    'Normal':      Color(0xFFA8A878),
    'Fire':        Color(0xFFF08030),
    'Water':       Color(0xFF6890F0),
    'Grass':       Color(0xFF78C850),
    'Electric':    Color(0xFFF8D030),
    'Ice':         Color(0xFF98D8D8),
    'Fighting':    Color(0xFFC03028),
    'Poison':      Color(0xFFA040A0),
    'Ground':      Color(0xFFE0C068),
    'Flying':      Color(0xFFA890F0),
    'Psychic':     Color(0xFFF85888),
    'Bug':         Color(0xFFA8B820),
    'Rock':        Color(0xFFB8A038),
    'Ghost':       Color(0xFF705898),
    'Dragon':      Color(0xFF7038F8),
    'Dark':        Color(0xFF705848),
    'Steel':       Color(0xFFB8B8D0),
    'Fairy':       Color(0xFFEE99AC),
    'Colorless':   Color(0xFFA8A878),
    'Darkness':    Color(0xFF705848),
    'Metal':       Color(0xFFB8B8D0),
    'Lightning':   Color(0xFFF8D030),
  };

  // Nomes traduzidos para PT
  static const Map<String, String> _namePt = {
    'Normal':    'Normal',
    'Fire':      'Fogo',
    'Water':     'Água',
    'Grass':     'Planta',
    'Electric':  'Elétrico',
    'Lightning': 'Elétrico',
    'Ice':       'Gelo',
    'Fighting':  'Lutador',
    'Poison':    'Veneno',
    'Ground':    'Terra',
    'Flying':    'Voador',
    'Psychic':   'Psíquico',
    'Bug':       'Inseto',
    'Rock':      'Pedra',
    'Ghost':     'Fantasma',
    'Dragon':    'Dragão',
    'Dark':      'Sombrio',
    'Darkness':  'Sombrio',
    'Steel':     'Aço',
    'Metal':     'Aço',
    'Fairy':     'Fada',
    'Colorless': 'Incolor',
  };

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[typeName] ?? const Color(0xFFA8A878);
    final label = _namePt[typeName] ?? typeName;

    // Usa o mesmo asset de ícone de tipo já existente no projeto
    final iconAsset = 'assets/types/${typeName.toLowerCase()}.png';

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            iconAsset,
            width: 18,
            height: 18,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(width: 18),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Linha de stats (número, estágio, HP, fraqueza) ──────────────

class _StatsRow extends StatelessWidget {
  final PocketCardDetail card;
  const _StatsRow({required this.card});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = <_StatItem>[];

    // Número da carta
    items.add(_StatItem(label: 'Número', value: '#${card.localId}'));

    // Estágio de evolução
    if (card.stage != null) {
      final stageLabel = _stageLabel(card.stage!);
      items.add(_StatItem(label: 'Estágio', value: stageLabel));
    }

    // HP
    if (card.hp != null) {
      items.add(_StatItem(label: 'HP', value: '${card.hp}'));
    }

    // Fraqueza
    if (card.weaknessType != null) {
      final val = card.weaknessValue != null ? '+${card.weaknessValue}' : '';
      items.add(_StatItem(label: 'Fraqueza', value: '${card.weaknessType}$val'));
    }

    // Retreat
    if (card.retreat != null) {
      items.add(_StatItem(label: 'Recuo', value: '${card.retreat}'));
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: items
            .map<Widget>((item) => _StatCell(item: item, scheme: scheme))
            .toList(),
      ),
    );
  }

  String _stageLabel(String stage) {
    switch (stage.toLowerCase()) {
      case 'basic':  return 'Básico';
      case 'stage1': return 'Estágio 1';
      case 'stage2': return 'Estágio 2';
      default:       return stage;
    }
  }
}

class _StatItem {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});
}

class _StatCell extends StatelessWidget {
  final _StatItem   item;
  final ColorScheme scheme;
  const _StatCell({required this.item, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          item.label,
          style: TextStyle(
            fontSize: 10,
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ─── Descrição / flavor text ──────────────────────────────────────

class _DescriptionCard extends StatelessWidget {
  final String text;
  const _DescriptionCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: scheme.onSurfaceVariant,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─── Seção de habilidades ─────────────────────────────────────────

class _AbilitiesSection extends StatelessWidget {
  final List<PocketAbility> abilities;
  const _AbilitiesSection({required this.abilities});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SectionCard(
      title: 'Habilidade${abilities.length > 1 ? 's' : ''}',
      titleColor: Colors.purple.shade400,
      child: Column(
        children: abilities
            .map<Widget>((a) => _AbilityRow(ability: a, scheme: scheme, isDark: isDark))
            .toList(),
      ),
    );
  }
}

class _AbilityRow extends StatelessWidget {
  final PocketAbility ability;
  final ColorScheme   scheme;
  final bool          isDark;
  const _AbilityRow({required this.ability, required this.scheme, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ability.type ?? 'Habilidade',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ability.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (ability.effect != null && ability.effect!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              ability.effect!,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withOpacity(0.85),
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Seção de ataques ─────────────────────────────────────────────

class _AttacksSection extends StatelessWidget {
  final List<PocketAttack> attacks;
  const _AttacksSection({required this.attacks});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SectionCard(
      title: 'Ataques',
      titleColor: Theme.of(context).colorScheme.primary,
      child: Column(
        children: [
          for (int i = 0; i < attacks.length; i++) ...[
            _AttackRow(attack: attacks[i], scheme: scheme, isDark: isDark),
            if (i < attacks.length - 1)
              Divider(height: 20, color: scheme.outlineVariant),
          ],
        ],
      ),
    );
  }
}

class _AttackRow extends StatelessWidget {
  final PocketAttack attack;
  final ColorScheme  scheme;
  final bool         isDark;
  const _AttackRow({required this.attack, required this.scheme, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nome + custo + dano
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Custo (ícones de energia)
            if (attack.cost.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...attack.cost.map<Widget>((c) => Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: _EnergyCost(type: c),
                  )),
                  const SizedBox(width: 8),
                ],
              ),

            // Nome do ataque
            Expanded(
              child: Text(
                attack.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            // Dano
            if (attack.damage != null && attack.damage!.isNotEmpty)
              Text(
                attack.damage!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),

        // Efeito do ataque
        if (attack.effect != null && attack.effect!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            attack.effect!,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withOpacity(0.8),
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Ícone de custo de energia ────────────────────────────────────

class _EnergyCost extends StatelessWidget {
  final String type;
  const _EnergyCost({required this.type});

  static const Map<String, Color> _energyColors = {
    'Fire':       Color(0xFFF08030),
    'Water':      Color(0xFF6890F0),
    'Grass':      Color(0xFF78C850),
    'Electric':   Color(0xFFF8D030),
    'Lightning':  Color(0xFFF8D030),
    'Psychic':    Color(0xFFF85888),
    'Fighting':   Color(0xFFC03028),
    'Darkness':   Color(0xFF705848),
    'Dark':       Color(0xFF705848),
    'Metal':      Color(0xFFB8B8D0),
    'Steel':      Color(0xFFB8B8D0),
    'Colorless':  Color(0xFFA8A878),
    'Dragon':     Color(0xFF7038F8),
  };

  @override
  Widget build(BuildContext context) {
    final color = _energyColors[type] ?? const Color(0xFFA8A878);
    final iconAsset = 'assets/types/${type.toLowerCase()}.png';

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 0.5),
      ),
      child: ClipOval(
        child: Image.asset(
          iconAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              type.substring(0, 1),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Efeito Trainer ───────────────────────────────────────────────

class _TrainerEffectCard extends StatelessWidget {
  final String  effect;
  final String? trainerType;
  const _TrainerEffectCard({required this.effect, this.trainerType});

  @override
  Widget build(BuildContext context) {
    final label = trainerType != null
        ? _trainerTypeLabel(trainerType!)
        : 'Efeito';

    return _SectionCard(
      title: label,
      titleColor: Colors.teal.shade400,
      child: Text(
        effect,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
          height: 1.5,
        ),
      ),
    );
  }

  String _trainerTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'item':      return 'Item';
      case 'supporter': return 'Suporte';
      case 'stadium':   return 'Estádio';
      case 'tool':      return 'Ferramenta';
      default:          return type;
    }
  }
}

// ─── SectionCard local (segue o padrão visual do projeto) ─────────
// Versão simplificada sem depender do pokemonTypes do detail_shared

class _SectionCard extends StatelessWidget {
  final String  title;
  final Color   titleColor;
  final Widget  child;

  const _SectionCard({
    required this.title,
    required this.titleColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme      = Theme.of(context).colorScheme;
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg  = Theme.of(context).scaffoldBackgroundColor;
    final cardBg      = isDark
        ? titleColor.withOpacity(0.08)
        : titleColor.withOpacity(0.06);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Card
        Container(
          margin: const EdgeInsets.only(top: 14),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border.all(color: titleColor.withOpacity(0.3), width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: child,
        ),
        // Badge do título
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: scaffoldBg,
                border: Border.all(color: titleColor, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Skeleton loader ─────────────────────────────────────────────

class _DetailSkeleton extends StatefulWidget {
  const _DetailSkeleton();
  @override
  State<_DetailSkeleton> createState() => _DetailSkeletonState();
}

class _DetailSkeletonState extends State<_DetailSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>    _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmer = scheme.onSurface.withOpacity(_anim.value * 0.12);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            children: [
              // Card placeholder
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: AspectRatio(
                    aspectRatio: 0.714,
                    child: Container(
                      decoration: BoxDecoration(
                        color: shimmer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Nome placeholder
              Container(height: 24, width: 180, color: shimmer),
              const SizedBox(height: 12),
              // Tipo placeholder
              Container(height: 32, width: 100, color: shimmer),
              const SizedBox(height: 16),
              // Stats placeholder
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: shimmer,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              // Ataques placeholder
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: shimmer,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Error view ──────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontSize: 13), textAlign: TextAlign.center, softWrap: true),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

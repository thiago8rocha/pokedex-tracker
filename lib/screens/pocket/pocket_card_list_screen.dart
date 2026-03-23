import 'package:flutter/material.dart';
import 'package:pokedex_tracker/services/tcg_pocket_service.dart';
import 'package:pokedex_tracker/screens/pocket/pocket_card_detail_screen.dart';
import 'package:pokedex_tracker/screens/pocket/pocket_rarity_widget.dart';

class PocketCardListScreen extends StatefulWidget {
  final String setId;
  final String setName;

  const PocketCardListScreen({
    super.key,
    required this.setId,
    required this.setName,
  });

  @override
  State<PocketCardListScreen> createState() => _PocketCardListScreenState();
}

class _PocketCardListScreenState extends State<PocketCardListScreen> {
  PocketSet? _set;
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSet();
  }

  Future<void> _loadSet() async {
    setState(() { _loading = true; _error = null; });
    try {
      final set = await TcgPocketService.fetchSet(widget.setId);
      if (mounted) {
        setState(() {
          _set     = set;
          _loading = false;
          if (set == null) _error = 'Erro ao carregar coleção';
        });
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'Erro ao carregar coleção'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.setName),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_set != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_set!.cards.length} cartas',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const _ListSkeleton()
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadSet)
              : _CardGrid(set: _set!, setId: widget.setId),
    );
  }
}

// ─── Grid de cartas ───────────────────────────────────────────────

class _CardGrid extends StatelessWidget {
  final PocketSet set;
  final String    setId;
  const _CardGrid({required this.set, required this.setId});

  @override
  Widget build(BuildContext context) {
    if (set.cards.isEmpty) {
      return const Center(child: Text('Nenhuma carta encontrada'));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 8,
        mainAxisSpacing:  8,
      ),
      itemCount: set.cards.length,
      itemBuilder: (context, i) => _CardTile(card: set.cards[i], setId: setId),
    );
  }
}

// ─── Tile individual de carta ─────────────────────────────────────

class _CardTile extends StatelessWidget {
  final PocketCardBrief card;
  final String          setId;
  const _CardTile({required this.card, required this.setId});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PocketCardDetailScreen(
            cardId:  card.id,
            setId:   setId,
            localId: card.localId,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Imagem da carta ──
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: card.imageUrlLow != null
                    ? Image.network(
                        card.imageUrlLow!,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: scheme.surfaceContainerHighest,
                            child: Center(
                              child: Icon(
                                Icons.style_outlined,
                                size: 24,
                                color: scheme.onSurfaceVariant.withOpacity(0.3),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: scheme.surfaceContainerHighest,
                          child: Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 24,
                              color: scheme.onSurfaceVariant.withOpacity(0.3),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: scheme.surfaceContainerHighest,
                        child: Center(
                          child: Icon(
                            Icons.style_outlined,
                            size: 24,
                            color: scheme.onSurfaceVariant.withOpacity(0.3),
                          ),
                        ),
                      ),
              ),
            ),

            // ── Rodapé: número + nome + raridade ──
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Número da carta
                  Text(
                    '#${card.localId}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 1),
                  // Nome
                  Text(
                    card.name,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (card.rarity != null) ...[
                    const SizedBox(height: 3),
                    PocketRarityBadge(rarity: card.rarity!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton loader ─────────────────────────────────────────────

class _ListSkeleton extends StatefulWidget {
  const _ListSkeleton();
  @override
  State<_ListSkeleton> createState() => _ListSkeletonState();
}

class _ListSkeletonState extends State<_ListSkeleton>
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
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:   3,
            childAspectRatio: 0.65,
            crossAxisSpacing: 8,
            mainAxisSpacing:  8,
          ),
          itemCount: 18,
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              color: shimmer,
              borderRadius: BorderRadius.circular(8),
            ),
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
          Text(message, style: const TextStyle(fontSize: 15)),
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

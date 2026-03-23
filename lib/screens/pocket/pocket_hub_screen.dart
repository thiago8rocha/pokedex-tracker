import 'package:flutter/material.dart';
import 'package:pokedex_tracker/services/tcg_pocket_service.dart';
import 'package:pokedex_tracker/screens/pocket/pocket_card_list_screen.dart';

class PocketHubScreen extends StatefulWidget {
  const PocketHubScreen({super.key});

  @override
  State<PocketHubScreen> createState() => _PocketHubScreenState();
}

class _PocketHubScreenState extends State<PocketHubScreen> {
  List<PocketSet> _sets = [];
  bool   _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSets();
  }

  Future<void> _loadSets() async {
    setState(() { _loading = true; _error = null; });
    try {
      final sets = await TcgPocketService.fetchSeries();
      if (mounted) setState(() { _sets = sets; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Erro ao carregar coleções'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TCG Pocket'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () {
              TcgPocketService.clearCache();
              _loadSets();
            },
          ),
        ],
      ),
      body: _loading
          ? const _HubSkeleton()
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadSets)
              : _SetGrid(sets: _sets),
    );
  }
}

// ─── Grid de coleções ─────────────────────────────────────────────

class _SetGrid extends StatelessWidget {
  final List<PocketSet> sets;
  const _SetGrid({required this.sets});

  @override
  Widget build(BuildContext context) {
    if (sets.isEmpty) {
      return const Center(child: Text('Nenhuma coleção encontrada'));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   2,
        childAspectRatio: 0.82,
        crossAxisSpacing: 12,
        mainAxisSpacing:  12,
      ),
      itemCount: sets.length,
      itemBuilder: (context, i) => _SetBox(set: sets[i]),
    );
  }
}

// ─── Caixa de coleção ─────────────────────────────────────────────

class _SetBox extends StatelessWidget {
  final PocketSet set;
  const _SetBox({required this.set});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // URL do logo do set como imagem de fundo da caixa
    final boosterUrl = TcgPocketService.boosterImageUrl(set.id);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PocketCardListScreen(setId: set.id, setName: set.name),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.outlineVariant,
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Área da imagem do booster (fundo da caixa) ──
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Fundo degradê sutil
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end:   Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  scheme.primaryContainer.withOpacity(0.3),
                                  scheme.secondaryContainer.withOpacity(0.2),
                                ]
                              : [
                                  scheme.primaryContainer.withOpacity(0.5),
                                  scheme.secondaryContainer.withOpacity(0.3),
                                ],
                        ),
                      ),
                    ),
                    // Logo do booster
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.network(
                        boosterUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: Icon(
                              Icons.style_outlined,
                              size: 40,
                              color: scheme.onSurfaceVariant.withOpacity(0.4),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(
                            Icons.style_outlined,
                            size: 40,
                            color: scheme.onSurfaceVariant.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                    // ID do set (canto superior direito)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.surface.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          set.id,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Rodapé com nome e total de cartas ──
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? scheme.surfaceContainerHighest
                      : scheme.surfaceContainerHigh,
                  border: Border(
                    top: BorderSide(color: scheme.outlineVariant, width: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      set.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (set.releaseDate != null) ...[
                          Text(
                            set.releaseDate!.substring(0, 4),
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            ' · ',
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                        Text(
                          'Ver cartas',
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Skeleton loader ─────────────────────────────────────────────

class _HubSkeleton extends StatefulWidget {
  const _HubSkeleton();
  @override
  State<_HubSkeleton> createState() => _HubSkeletonState();
}

class _HubSkeletonState extends State<_HubSkeleton>
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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmer = scheme.onSurface.withOpacity(_anim.value * 0.15);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:   2,
            childAspectRatio: 0.82,
            crossAxisSpacing: 12,
            mainAxisSpacing:  12,
          ),
          itemCount: 6,
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              color: shimmer,
              borderRadius: BorderRadius.circular(12),
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

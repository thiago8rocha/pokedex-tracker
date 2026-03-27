import 'package:flutter/material.dart';
import 'package:pokedex_tracker/services/tcg_pocket_service.dart';
import 'package:pokedex_tracker/screens/pocket/pocket_card_list_screen.dart';

const Set<String> _kPromoSets = {'P-A', 'P-B'};

class PocketHubScreen extends StatefulWidget {
  const PocketHubScreen({super.key});

  @override
  State<PocketHubScreen> createState() => _PocketHubScreenState();
}

class _PocketHubScreenState extends State<PocketHubScreen> {
  List<PocketSet> _sets = [];
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSets();
  }

  Future<void> _loadSets() async {
    setState(() { _loading = true; _error = null; });

    // Warm-up das 3 coleções mais recentes em background enquanto carrega o hub
    // Na segunda visita já estão em cache — abertura instantânea
    TcgPocketService.warmupRecentSets(count: 3);

    try {
      final sets = await TcgPocketService.fetchSeries();
      if (!mounted) return;

      // Precache dos assets de booster ANTES do setState
      // Quando a grid renderizar, as imagens já estão decodificadas
      await Future.wait(
        sets.map((s) => precacheImage(
          AssetImage('assets/pocket/boosters/${s.id}.png'), context,
        ).catchError((_) => null)),
      );

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
      ),
      body: _loading
          ? const _HubSkeleton()
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadSets)
              : _SetGrid(sets: _sets),
    );
  }
}

// ─── Grid ─────────────────────────────────────────────────────────

class _SetGrid extends StatelessWidget {
  final List<PocketSet> sets;
  const _SetGrid({required this.sets});

  @override
  Widget build(BuildContext context) {
    if (sets.isEmpty) return const Center(child: Text('Nenhuma coleção encontrada'));
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.82,
        crossAxisSpacing: 12, mainAxisSpacing: 12,
      ),
      itemCount: sets.length,
      itemBuilder: (_, i) => _SetBox(set: sets[i]),
    );
  }
}

// ─── Caixa de coleção ─────────────────────────────────────────────

class _SetBox extends StatelessWidget {
  final PocketSet set;
  const _SetBox({required this.set});

  @override
  Widget build(BuildContext context) {
    final meta    = kPocketSetMeta[set.id];
    final color1  = Color(meta?.color1 ?? 0xFF1A1A2E);
    final color2  = Color(meta?.color2 ?? 0xFF16213E);
    final isPromo = _kPromoSets.contains(set.id);
    final assetPath = 'assets/pocket/boosters/${set.id}.png';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => PocketCardListScreen(setId: set.id, setName: set.name),
      )),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [color1, color2],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Imagem de fundo ──────────────────────────────────
              if (isPromo)
                _PromoBackground(assetPath: assetPath)
              else
                _BoosterBackground(assetPath: assetPath),

              // ── Overlay: topo escuro para texto + base para cortar ──
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.32, 0.58, 0.80, 1.0],
                      colors: [
                        Colors.black.withOpacity(0.72),
                        Colors.black.withOpacity(0.08),
                        Colors.black.withOpacity(0.22),
                        Colors.black.withOpacity(0.50),
                        Colors.black.withOpacity(0.78),
                      ],
                    ),
                  ),
                ),
              ),

              // ── ID + Nome ─────────────────────────────────────────
              Positioned(
                top: 10, left: 10, right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      set.id,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.6,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 6),
                          Shadow(color: Colors.black, blurRadius: 14),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      set.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                          Shadow(color: Colors.black, blurRadius: 10),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

// ─── Booster vertical ─────────────────────────────────────────────
// Estratégia: BoxFit.cover preenche a caixa inteira.
// Transform.scale centralizado amplia DEPOIS do clip — zoom real sem
// deslocar a imagem para fora, cortando simetricamente em todos os lados.

class _BoosterBackground extends StatelessWidget {
  final String assetPath;
  const _BoosterBackground({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Transform.scale(
        scale: 1.55,
        alignment: Alignment.center,
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          // color + blendMode em vez de Opacity — evita saveLayer, muito mais eficiente
          color: Colors.white.withOpacity(0.55),
          colorBlendMode: BlendMode.modulate,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// ─── Promo: logo com fundo sólido, BoxFit.cover centralizado ──────
// As imagens das promos já foram pré-processadas (fundo opaco, recortadas)
// então funcionam como qualquer outro PNG sem transparência.

class _PromoBackground extends StatelessWidget {
  final String assetPath;
  const _PromoBackground({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        color: Colors.white.withOpacity(0.55),
        colorBlendMode: BlendMode.modulate,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

// ─── Skeleton ────────────────────────────────────────────────────

class _HubSkeleton extends StatefulWidget {
  const _HubSkeleton();
  @override State<_HubSkeleton> createState() => _HubSkeletonState();
}

class _HubSkeletonState extends State<_HubSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>    _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: 0.82,
          crossAxisSpacing: 12, mainAxisSpacing: 12,
        ),
        itemCount: 8,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: scheme.onSurface.withOpacity(_anim.value * 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

// ─── Error view ──────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
      const SizedBox(height: 12),
      Text(message),
      const SizedBox(height: 16),
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
        onPressed: onRetry,
        child: const Text('Tentar novamente'),
      ),
    ]),
  );
}

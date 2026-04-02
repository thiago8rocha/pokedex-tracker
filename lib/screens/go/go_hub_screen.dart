import 'package:flutter/material.dart';
import 'package:dexcurator/screens/pokedex_screen.dart';
import 'package:dexcurator/screens/go/go_cp_calculator_screen.dart';
import 'package:dexcurator/screens/go/go_raids_screen.dart';
import 'package:dexcurator/screens/go/go_mega_screen.dart';
import 'package:dexcurator/screens/go/go_gigantamax_screen.dart';
import 'package:dexcurator/screens/go/go_regional_forms_screen.dart';
import 'package:dexcurator/screens/pocket/pocket_hub_screen.dart';
import 'package:dexcurator/screens/pokopia/pokopia_hub_screen.dart';
import 'package:dexcurator/screens/menu/moves_list_screen.dart';
import 'package:dexcurator/screens/menu/abilities_list_screen.dart';
import 'package:dexcurator/screens/menu/natures_list_screen.dart';
import 'package:dexcurator/screens/menu/teams_screen.dart';
import 'package:dexcurator/screens/menu/items_list_screen.dart';
import 'package:dexcurator/screens/settings_screen.dart';

class GoHubScreen extends StatelessWidget {
  const GoHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    // Definição dos cards do hub
    // sprite: ID nacional do Pokémon representativo (usa assets/sprites/artwork/)
    // color: cor de fundo suave, não saturada
    final cards = [
      _CardDef(
        title:    'Pokédex GO',
        subtitle: 'Registre seus Pokémon capturados',
        spriteId: 133, // Eevee — representa a diversidade do GO
        color:    isDark ? const Color(0xFF1A3A2A) : const Color(0xFFE8F5E9),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const PokedexScreen(
            pokedexId:    'pokémon_go',
            pokedexName:  'Pokémon GO',
            totalPokemon: 941,
          ),
        )),
      ),
      _CardDef(
        title:    'Calculadora de CP',
        subtitle: 'Calcule CP por IVs e nível',
        spriteId: 147, // Dratini — represents CP math
        color:    isDark ? const Color(0xFF1A2A3A) : const Color(0xFFE3F2FD),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const GoCpCalculatorScreen(),
        )),
      ),
      _CardDef(
        title:    'Raids Ativos',
        subtitle: 'Chefes de raid disponíveis agora',
        spriteId: 249, // Lugia — lendário icônico de raids
        color:    isDark ? const Color(0xFF2A1A3A) : const Color(0xFFEDE7F6),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const GoRaidsScreen(),
        )),
      ),
      _CardDef(
        title:    'Mega Evoluções',
        subtitle: 'Megas disponíveis no GO',
        spriteId: 6,   // Charizard — ícone mais famoso de Mega
        color:    isDark ? const Color(0xFF3A1A1A) : const Color(0xFFFFEBEE),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const GoMegaScreen(),
        )),
      ),
      _CardDef(
        title:    'Gigantamax',
        subtitle: 'Formas Gigantamax no GO',
        spriteId: 143, // Snorlax — primeiro Gigantamax do GO
        color:    isDark ? const Color(0xFF2A2A1A) : const Color(0xFFFFFDE7),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const GoGigantamaxScreen(),
        )),
      ),
      _CardDef(
        title:    'Formas Regionais',
        subtitle: 'Alola, Galar, Hisui e variantes',
        spriteId: 26,  // Raichu de Alola (ID 26 = Raichu, forma Alola no GO)
        color:    isDark ? const Color(0xFF1A3A3A) : const Color(0xFFE0F7FA),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const GoRegionalFormsScreen(),
        )),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokémon GO'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      endDrawer: _buildGoDrawer(context),
      bottomNavigationBar: _GoBottomNav(),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   2,
          crossAxisSpacing: 12,
          mainAxisSpacing:  12,
          childAspectRatio: 1.0,
        ),
        itemCount: cards.length,
        itemBuilder: (context, i) => _HubCard(def: cards[i]),
      ),
    );
  }
}

// ─── Definição de card ────────────────────────────────────────────

class _CardDef {
  final String        title;
  final String        subtitle;
  final int           spriteId;
  final Color         color;
  final VoidCallback  onTap;

  const _CardDef({
    required this.title,
    required this.subtitle,
    required this.spriteId,
    required this.color,
    required this.onTap,
  });
}

// ─── Widget do card ───────────────────────────────────────────────

class _HubCard extends StatelessWidget {
  final _CardDef def;
  const _HubCard({required this.def});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: def.onTap,
      child: Container(
        decoration: BoxDecoration(
          color:        def.color,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(
            color: scheme.outlineVariant.withOpacity(0.5),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Sprite como imagem de fundo
              Positioned(
                right: -12,
                bottom: -8,
                child: Opacity(
                  opacity: 0.22,
                  child: Image.asset(
                    'assets/sprites/artwork/${def.spriteId}.webp',
                    width: 110,
                    height: 110,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 110, height: 110),
                  ),
                ),
              ),

              // Conteúdo de texto
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      def.subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withOpacity(0.6),
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: scheme.onSurface.withOpacity(0.4),
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

// ─── Drawer lateral ───────────────────────────────────────────────

Widget _buildGoDrawer(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return Drawer(child: SafeArea(child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Text('Menu', style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      Divider(color: scheme.outlineVariant),
      ListTile(
        leading: const Icon(Icons.sports_martial_arts_outlined, size: 22),
        title: const Text('Golpes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20), dense: true,
        onTap: () { Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MovesListScreen())); }),
      ListTile(
        leading: const Icon(Icons.auto_awesome_outlined, size: 22),
        title: const Text('Habilidades', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20), dense: true,
        onTap: () { Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AbilitiesListScreen())); }),
      ListTile(
        leading: const Icon(Icons.psychology_outlined, size: 22),
        title: const Text('Naturezas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20), dense: true,
        onTap: () { Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const NaturesListScreen())); }),
      Divider(color: scheme.outlineVariant),
      ListTile(
        leading: const Icon(Icons.groups_2_outlined, size: 22),
        title: const Text('Times', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20), dense: true,
        onTap: () { Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamsScreen())); }),
      ListTile(
        leading: const Icon(Icons.inventory_2_outlined, size: 22),
        title: const Text('Itens', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20), dense: true,
        onTap: () { Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ItemsListScreen())); }),
      const Spacer(),
      Divider(color: scheme.outlineVariant),
      ListTile(
        leading: const Icon(Icons.settings_outlined, size: 22),
        title: const Text('Configurações', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20), dense: true,
        onTap: () async { Navigator.pop(context);
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); }),
      const SizedBox(height: 8),
    ],
  )));
}

// ─── Bottom Nav (mesmo padrão do PokedexScreen) ───────────────────

class _GoBottomNav extends StatelessWidget {
  const _GoBottomNav();

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Container(
      height: 62,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant, width: 0.5))),
      child: Row(children: [
        // Início — pop de volta à raiz
        Expanded(child: InkWell(
          onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.home_outlined, size: 22,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 2),
            Text('Início', style: TextStyle(fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        )),
        // Pocket
        Expanded(child: InkWell(
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PocketHubScreen())),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.style_outlined, size: 22,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 2),
            Text('Pocket', style: TextStyle(fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        )),
        // GO — ativo
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.public_outlined, size: 22,
            color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 2),
          Text('GO', style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary)),
        ])),
        // Pokopia
        Expanded(child: InkWell(
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PokopiaHubScreen())),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.nature_people_outlined, size: 22,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 2),
            Text('Pokopia', style: TextStyle(fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        )),
        // Menu
        Expanded(child: Builder(builder: (ctx) => InkWell(
          onTap: () => Scaffold.of(ctx).openEndDrawer(),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.menu, size: 22,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 2),
            Text('Menu', style: TextStyle(fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ))),
      ]),
    ));
  }
}

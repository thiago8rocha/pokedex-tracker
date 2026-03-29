import 'package:flutter/material.dart';
import 'package:pokedex_tracker/screens/disclaimer_screen.dart';
import 'package:pokedex_tracker/theme/app_theme.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart'
    show bilingualModeNotifier, defaultSpriteNotifier, PokeballLoader;

// ─── MODELO DE POKEDEX ────────────────────────────────────────────

class _PokedexOption {
  final String id;
  final String name;
  final String year;
  const _PokedexOption({required this.id, required this.name, required this.year});
}

// ─── TELA PRINCIPAL DE CONFIGURAÇÕES ─────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          _SectionHeader(label: 'APARÊNCIA'),
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Tema',
            subtitle: 'Personalizar cores do app',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ThemePickerScreen())),
          ),

          _SectionHeader(label: 'IDIOMA E EXIBIÇÃO'),
          _SettingsTile(
            icon: Icons.language_outlined,
            title: 'Idioma da Interface',
            subtitle: 'Português (BR) — outros idiomas em breve',
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.translate_outlined,
            title: 'Idioma dos Dados',
            subtitle: 'Nomes de moves e habilidades em PT / EN',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BilingualSettingsScreen())),
          ),
          _SettingsTile(
            icon: Icons.language_outlined,
            title: 'Idioma do Pokopia',
            subtitle: 'Traduzir nomes de habitats, receitas, relíquias e fósseis',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PokopiaTranslationScreen())),
          ),

          _SectionHeader(label: 'POKEDEX'),
          _SettingsTile(
            icon: Icons.catching_pokemon_outlined,
            title: 'Gerenciar Pokedex',
            subtitle: 'Ativar ou desativar Pokedex exibidas',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ManagePokedexScreen())),
          ),
          _SettingsTile(
            icon: Icons.image_outlined,
            title: 'Sprite padrão',
            subtitle: 'Escolher o tipo de imagem exibida por padrão',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SpriteSettingsScreen())),
          ),

          _SectionHeader(label: 'DADOS'),
          _SettingsTile(
            icon: Icons.upload_outlined,
            title: 'Exportar backup',
            subtitle: 'Salvar arquivo local com todos os dados',
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.download_outlined,
            title: 'Importar backup',
            subtitle: 'Restaurar de um arquivo',
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.delete_outline,
            title: 'Limpar dados do app',
            subtitle: 'Remove capturas e times salvos',
            titleColor: Theme.of(context).colorScheme.error,
            onTap: () => _confirmClearData(context),
          ),

          _SectionHeader(label: 'APP'),
          _SettingsTile(
            icon: Icons.copyright_outlined,
            title: 'Conteúdo e direitos autorais',
            subtitle: 'App não oficial, fan-made, sem fins lucrativos',
            onTap: () => _showDisclaimer(context, tab: 0),
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Termos e Condições',
            subtitle: 'Termos de uso do DexCurator',
            onTap: () => _showDisclaimer(context, tab: 1),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Política de Privacidade',
            subtitle: 'Como seus dados são tratados',
            onTap: () => _showDisclaimer(context, tab: 2),
          ),

          const SizedBox(height: 32),
          Center(child: Text('DexCurator',
            style: TextStyle(fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showDisclaimer(BuildContext context, {int tab = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, __) => DisclaimerScreen(
          isFromSettings: true,
          initialTab: tab,
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Em breve'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ));
  }

  void _confirmClearData(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar dados'),
        content: const Text(
          'Esta ação remove todas as capturas e times salvos. Não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await StorageService().clearAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Dados removidos'),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            child: Text('Limpar',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}

// ─── TELA DE TEMA ─────────────────────────────────────────────────

class ThemePickerScreen extends StatefulWidget {
  const ThemePickerScreen({super.key});
  @override
  State<ThemePickerScreen> createState() => _ThemePickerScreenState();
}

class _ThemePickerScreenState extends State<ThemePickerScreen> {
  final _storage = StorageService();
  String _themeId = 'system';
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _themeId = appThemeController.themeId;
    _isDark   = appThemeController.themeMode == ThemeMode.dark;
  }

  Future<void> _selectTheme(AppThemeDefinition def) async {
    final mode = _isDark ? ThemeMode.dark : ThemeMode.light;
    setState(() => _themeId = def.id);
    await _storage.setThemeId(def.id);
    appThemeController.setTheme(def.id, mode);
  }

  Future<void> _toggleDark(bool val) async {
    setState(() => _isDark = val);
    final mode = val ? ThemeMode.dark : ThemeMode.light;
    appThemeController.setTheme(_themeId, mode);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = scheme.outlineVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tema'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Toggle claro/escuro — sempre disponível
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: 0.5),
            ),
            child: Row(children: [
              Icon(Icons.dark_mode_outlined, size: 20,
                color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(child: const Text('Modo escuro',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
              Switch(value: _isDark, onChanged: _toggleDark),
            ]),
          ),
          const SizedBox(height: 20),
          Text('Cor do tema',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              letterSpacing: 0.8, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),

          // Grid de temas — Wrap com IntrinsicHeight para alturas iguais por linha
          LayoutBuilder(builder: (ctx, constraints) {
            const gap = 10.0;
            final cardW = (constraints.maxWidth - gap) / 2;
            final items = AppThemes.all;
            final rows = <Widget>[];
            for (int i = 0; i < items.length; i += 2) {
              final left  = items[i];
              final right = i + 1 < items.length ? items[i + 1] : null;
              rows.add(IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: cardW, child: _ThemeCard(
                      def: left, isActive: _themeId == left.id,
                      onTap: () => _selectTheme(left))),
                    const SizedBox(width: gap),
                    SizedBox(width: cardW, child: right != null
                        ? _ThemeCard(def: right, isActive: _themeId == right.id,
                            onTap: () => _selectTheme(right))
                        : const SizedBox.shrink()),
                  ],
                ),
              ));
              if (i + 2 < items.length) rows.add(const SizedBox(height: 10));
            }
            return Column(mainAxisSize: MainAxisSize.min, children: rows);
          }),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final AppThemeDefinition def;
  final bool isActive;
  final VoidCallback onTap;
  const _ThemeCard({required this.def, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? scheme.primary : scheme.outlineVariant,
            width: isActive ? 2.0 : 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Preview: 3 swatches coloridos
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: def.previewColors.map((c) =>
                  Container(width: 28, height: 28, color: c),
                ).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Text(def.label, textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? scheme.primary : scheme.onSurface,
              )),
            if (isActive) ...[
              const SizedBox(height: 2),
              Icon(Icons.check_circle, size: 14, color: scheme.primary),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── TERMOS BILÍNGUES ─────────────────────────────────────────────
// Chaves salvas no storage: 'bilingual_mode' → 'pt' | 'en' | 'both'

class BilingualSettingsScreen extends StatefulWidget {
  const BilingualSettingsScreen({super.key});
  @override
  State<BilingualSettingsScreen> createState() => _BilingualSettingsScreenState();
}

class _BilingualSettingsScreenState extends State<BilingualSettingsScreen> {
  final _storage = StorageService();
  String _mode = 'both'; // 'pt', 'en', 'both'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await _storage.getBilingualMode();
    if (mounted) setState(() => _mode = m);
  }

  Future<void> _select(String mode) async {
    setState(() => _mode = mode);
    await _storage.setBilingualMode(mode);
    // Atualiza o notifier global — reflete imediatamente em todos os widgets abertos
    bilingualModeNotifier.value = mode;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Idioma dos Dados'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Configura como nomes de moves e habilidades são exibidos.',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // Preview visual do formato
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant, width: 0.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Prévia', style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              _BilingualPreview(mode: _mode),
            ]),
          ),
          const SizedBox(height: 16),

          // Opções
          _BilingualOption(
            label: 'Português',
            desc: 'Investida',
            value: 'pt',
            groupValue: _mode,
            onTap: () => _select('pt'),
          ),
          const SizedBox(height: 8),
          _BilingualOption(
            label: 'Inglês',
            desc: 'Tackle',
            value: 'en',
            groupValue: _mode,
            onTap: () => _select('en'),
          ),
          const SizedBox(height: 8),
          _BilingualOption(
            label: 'Português + Inglês',
            desc: 'Investida  Tackle',
            value: 'both',
            groupValue: _mode,
            onTap: () => _select('both'),
            showDualColor: true,
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant, width: 0.5),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Outros idiomas serão adicionados em uma versão futura.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              )),
            ]),
          ),
        ],
      ),
    );
  }
}

class _BilingualPreview extends StatelessWidget {
  final String mode;
  const _BilingualPreview({required this.mode});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (mode == 'pt') {
      return Text('Investida', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500));
    }
    if (mode == 'en') {
      return Text('Tackle', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500));
    }
    // both
    return Row(children: [
      Text('Investida', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(width: 8),
      Text('Tackle', style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w400,
        color: scheme.onSurfaceVariant)),
    ]);
  }
}

class _BilingualOption extends StatelessWidget {
  final String label;
  final String desc;
  final String value;
  final String groupValue;
  final VoidCallback onTap;
  final bool showDualColor;

  const _BilingualOption({
    required this.label, required this.desc, required this.value,
    required this.groupValue, required this.onTap, this.showDualColor = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isActive = value == groupValue;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? scheme.primary : scheme.outlineVariant,
            width: isActive ? 1.5 : 0.5,
          ),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: isActive ? scheme.primary : null)),
            const SizedBox(height: 2),
            if (showDualColor)
              Row(children: [
                Text('Investida', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Text('Tackle', style: TextStyle(fontSize: 12,
                  color: scheme.onSurfaceVariant)),
              ])
            else
              Text(desc, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ])),
          Radio<String>(
            value: value, groupValue: groupValue,
            onChanged: (_) => onTap(),
          ),
        ]),
      ),
    );
  }
}

// ─── SPRITE PADRÃO ───────────────────────────────────────────────

class SpriteSettingsScreen extends StatefulWidget {
  const SpriteSettingsScreen({super.key});
  @override
  State<SpriteSettingsScreen> createState() => _SpriteSettingsScreenState();
}

class _SpriteSettingsScreenState extends State<SpriteSettingsScreen> {
  final _storage = StorageService();
  String _selected = 'artwork';

  static const _options = [
    (id: 'artwork', label: 'Artwork oficial',
      desc: 'Imagem 2D de alta qualidade. Padrão da maioria dos jogos.',
      icon: Icons.image_outlined),
    (id: 'pixel', label: 'Pixel art',
      desc: 'Sprites clássicos dos jogos principais.',
      icon: Icons.grid_on_outlined),
    (id: 'home', label: 'Pokémon HOME',
      desc: 'Renders 3D do Pokémon HOME.',
      icon: Icons.view_in_ar_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _storage.getDefaultSprite();
    if (mounted) setState(() => _selected = s);
  }

  Future<void> _select(String id) async {
    setState(() => _selected = id);
    await _storage.setDefaultSprite(id);
    defaultSpriteNotifier.value = id;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sprite padrão'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Escolha o tipo de imagem exibida por padrão. '
            'Você pode mudar individualmente na tela de detalhes.',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ..._options.map((opt) {
            final isActive = _selected == opt.id;
            return GestureDetector(
              onTap: () => _select(opt.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? scheme.primary : scheme.outlineVariant,
                    width: isActive ? 1.5 : 0.5,
                  ),
                ),
                child: Row(children: [
                  Icon(opt.icon, size: 24,
                    color: isActive ? scheme.primary : scheme.onSurfaceVariant),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(opt.label, style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: isActive ? scheme.primary : null)),
                      const SizedBox(height: 2),
                      Text(opt.desc, style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  )),
                  if (isActive)
                    Icon(Icons.check_circle, size: 20, color: scheme.primary),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── GERENCIAR POKEDEX ───────────────────────────────────────────

class ManagePokedexScreen extends StatefulWidget {
  const ManagePokedexScreen({super.key});
  @override
  State<ManagePokedexScreen> createState() => _ManagePokedexScreenState();
}

class _ManagePokedexScreenState extends State<ManagePokedexScreen> {
  final _storage = StorageService();

  // Todos os jogos com Pokedex, em ordem de lançamento. Nacional não aparece.
  static const _allPokedex = [
    // Geração I
    _PokedexOption(id: 'red___blue',                    name: 'Red / Blue',                       year: '1996'),
    _PokedexOption(id: 'yellow',                        name: 'Yellow',                           year: '1998'),
    // Geração II
    _PokedexOption(id: 'gold___silver',                 name: 'Gold / Silver',                    year: '1999'),
    _PokedexOption(id: 'crystal',                       name: 'Crystal',                          year: '2000'),
    // Geração III
    _PokedexOption(id: 'ruby___sapphire',               name: 'Ruby / Sapphire',                  year: '2002'),
    _PokedexOption(id: 'firered___leafgreen_gba',       name: 'FireRed / LeafGreen (GBA)',        year: '2004'),
    _PokedexOption(id: 'emerald',                       name: 'Emerald',                          year: '2004'),
    // Geração IV
    _PokedexOption(id: 'diamond___pearl',               name: 'Diamond / Pearl',                  year: '2006'),
    _PokedexOption(id: 'platinum',                      name: 'Platinum',                         year: '2008'),
    _PokedexOption(id: 'heartgold___soulsilver',        name: 'HeartGold / SoulSilver',           year: '2009'),
    // Geração V
    _PokedexOption(id: 'black___white',                 name: 'Black / White',                    year: '2010'),
    _PokedexOption(id: 'black_2___white_2',             name: 'Black 2 / White 2',                year: '2012'),
    // Geração VI
    _PokedexOption(id: 'x___y',                         name: 'X / Y',                            year: '2013'),
    _PokedexOption(id: 'omega_ruby___alpha_sapphire',   name: 'Omega Ruby / Alpha Sapphire',      year: '2014'),
    // Geração VII
    _PokedexOption(id: 'sun___moon',                    name: 'Sun / Moon',                       year: '2016'),
    _PokedexOption(id: 'ultra_sun___ultra_moon',        name: 'Ultra Sun / Ultra Moon',           year: '2017'),
    // Mobile
    _PokedexOption(id: 'pokémon_go',                    name: 'Pokémon GO',                       year: '2016'),
    // Switch
    _PokedexOption(id: 'lets_go_pikachu___eevee',       name: "Let's Go Pikachu / Eevee",         year: '2018'),
    _PokedexOption(id: 'sword___shield',                name: 'Sword / Shield',                   year: '2019'),
    _PokedexOption(id: 'brilliant_diamond___shining_pearl', name: 'Brilliant Diamond / Shining Pearl', year: '2021'),
    _PokedexOption(id: 'legends:_arceus',               name: 'Legends: Arceus',                  year: '2022'),
    _PokedexOption(id: 'scarlet___violet',              name: 'Scarlet / Violet',                 year: '2022'),
    _PokedexOption(id: 'legends:_z-a',                  name: 'Legends: Z-A',                     year: '2025'),
    _PokedexOption(id: 'firered___leafgreen',            name: 'FireRed / LeafGreen (Switch)',     year: '2026'),
    _PokedexOption(id: 'pokopia',                       name: 'Pokopia',                          year: '2026'),
  ];

  Set<String> _activeIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final active = await _storage.getActivePokedexIds();
    if (mounted) {
      setState(() {
        _activeIds = active ?? _allPokedex.map((p) => p.id).toSet();
        _loading = false;
      });
    }
  }

  Future<void> _toggle(String id) async {
    final newSet = Set<String>.from(_activeIds);
    if (newSet.contains(id)) newSet.remove(id); else newSet.add(id);
    setState(() => _activeIds = newSet);
    await _storage.setActivePokedexIds(newSet);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Pokedex'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: PokeballLoader.small())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  'A Pokedex Nacional está sempre ativa e não pode ser desativada.',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: border, width: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: _allPokedex.asMap().entries.map((e) {
                      final isLast = e.key == _allPokedex.length - 1;
                      final p = e.value;
                      final isActive = _activeIds.contains(p.id);
                      return Container(
                        decoration: isLast ? null : BoxDecoration(
                          border: Border(bottom: BorderSide(color: border, width: 0.5))),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500,
                                color: isActive ? null : scheme.onSurfaceVariant)),
                              Text(p.year, style: TextStyle(
                                fontSize: 12, color: scheme.onSurfaceVariant)),
                            ],
                          )),
                          Switch(value: isActive, onChanged: (_) => _toggle(p.id)),
                        ]),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── WIDGETS AUXILIARES ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(label, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon, required this.title,
    required this.subtitle, required this.onTap, this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: border, width: 0.5))),
        child: Row(children: [
          Icon(icon, size: 20,
            color: titleColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: titleColor)),
              Text(subtitle, style: TextStyle(
                fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          )),
          if (onTap != null)
            Icon(Icons.chevron_right, size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}
// ─── POKOPIA TRANSLATION ──────────────────────────────────────────

class PokopiaTranslationScreen extends StatefulWidget {
  const PokopiaTranslationScreen({super.key});

  @override
  State<PokopiaTranslationScreen> createState() =>
      _PokopiaTranslationScreenState();
}

class _PokopiaTranslationScreenState
    extends State<PokopiaTranslationScreen> {
  // Por ora os toggles são locais; podem ser migrados para SharedPreferences
  bool _habitats = false;
  bool _recipes = false;
  bool _relics = false;
  bool _specialties = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Idioma do Pokopia'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant, width: 0.5),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Por padrão, o conteúdo do Pokopia é exibido em inglês (idioma original do jogo). '
                  'Ative abaixo as seções que você prefere ver traduzidas para o português.',
                  style: TextStyle(fontSize: 12,
                      color: scheme.onSurfaceVariant, height: 1.4))),
              ]),
            ),
          ),
          SwitchListTile(
            title: const Text('Habitats'),
            subtitle: const Text('Nomes e condições dos habitats'),
            value: _habitats,
            onChanged: (v) => setState(() => _habitats = v),
          ),
          SwitchListTile(
            title: const Text('Receitas'),
            subtitle: const Text('Nomes das receitas e ingredientes'),
            value: _recipes,
            onChanged: (v) => setState(() => _recipes = v),
          ),
          SwitchListTile(
            title: const Text('Relíquias e Fósseis'),
            subtitle: const Text('Nomes das relíquias perdidas e fósseis'),
            value: _relics,
            onChanged: (v) => setState(() => _relics = v),
          ),
          SwitchListTile(
            title: const Text('Especialidades'),
            subtitle: const Text('Nomes das especialidades dos Pokémon'),
            value: _specialties,
            onChanged: (v) => setState(() => _specialties = v),
          ),
        ],
      ),
    );
  }
}
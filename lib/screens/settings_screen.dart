import 'package:flutter/material.dart';
import 'package:pokedex_tracker/theme/app_theme.dart';
import 'package:pokedex_tracker/services/storage_service.dart';

// ─── MODELO DE POKEDEX ────────────────────────────────────────────

class _PokedexOption {
  final String id;
  final String name;
  final String year;

  const _PokedexOption({
    required this.id,
    required this.name,
    required this.year,
  });
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
          // ── Aparência ──────────────────────────────────────────
          _SectionHeader(label: 'APARÊNCIA'),
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Tema',
            subtitle: 'Personalizar cores do app',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ThemePickerScreen())),
          ),

          // ── Idioma e exibição ──────────────────────────────────
          _SectionHeader(label: 'IDIOMA E EXIBIÇÃO'),
          _SettingsTile(
            icon: Icons.language_outlined,
            title: 'Idioma',
            subtitle: 'Português (BR) — outros idiomas em breve',
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.translate_outlined,
            title: 'Termos bilíngues (Moves)',
            subtitle: 'Exibir nomes de moves em PT / EN',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BilingualSettingsScreen())),
          ),

          // ── Pokedex ────────────────────────────────────────────
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

          // ── Dados ──────────────────────────────────────────────
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

          const SizedBox(height: 32),
          Center(child: Text('Pokedex Tracker',
            style: TextStyle(fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant))),
          const SizedBox(height: 24),
        ],
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

// ─── TELA DE SELEÇÃO DE TEMA ─────────────────────────────────────
// Preview visual das cores reais de cada tema

class ThemePickerScreen extends StatefulWidget {
  const ThemePickerScreen({super.key});

  @override
  State<ThemePickerScreen> createState() => _ThemePickerScreenState();
}

class _ThemePickerScreenState extends State<ThemePickerScreen> {
  final _storage = StorageService();
  String _currentThemeId = 'system';
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _currentThemeId = appThemeController.themeId;
    _isDarkMode = appThemeController.themeMode == ThemeMode.dark;
    _load();
  }

  Future<void> _load() async {
    final id = await _storage.getThemeId();
    if (mounted) setState(() => _currentThemeId = id);
  }

  Future<void> _selectTheme(AppThemeDefinition def) async {
    // Determina ThemeMode: 'system' → system; demais → light por padrão a menos
    // que o toggle de dark mode esteja ativo
    final mode = def.id == 'system'
        ? ThemeMode.system
        : (_isDarkMode ? ThemeMode.dark : ThemeMode.light);

    setState(() => _currentThemeId = def.id);
    await _storage.setThemeId(def.id);
    appThemeController.setTheme(def.id, mode);
  }

  Future<void> _toggleDark(bool val) async {
    setState(() => _isDarkMode = val);
    final mode = _currentThemeId == 'system'
        ? ThemeMode.system
        : (val ? ThemeMode.dark : ThemeMode.light);
    appThemeController.setTheme(_currentThemeId, mode);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tema'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Toggle claro/escuro
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(Icons.dark_mode_outlined, size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(child: Text('Modo escuro',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                Switch(
                  value: _isDarkMode,
                  onChanged: _currentThemeId == 'system' ? null : _toggleDark,
                ),
              ],
            ),
          ),
          if (_currentThemeId == 'system')
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'No tema Sistema, o modo claro/escuro é controlado pelo dispositivo.',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 20),
          Text('Cor do tema',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              letterSpacing: 0.8, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          // Grid de temas — 2 colunas
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.7,
            ),
            itemCount: AppThemes.all.length,
            itemBuilder: (ctx, i) {
              final def = AppThemes.all[i];
              final isActive = _currentThemeId == def.id;
              return GestureDetector(
                onTap: () => _selectTheme(def),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isActive ? scheme.primary : scheme.outlineVariant,
                      width: isActive ? 2.0 : 0.5,
                    ),
                    color: scheme.surface,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Preview: 3 swatches coloridos lado a lado
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: def.previewColors.map((c) =>
                            Container(width: 26, height: 26, color: c),
                          ).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(def.label,
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
            },
          ),
        ],
      ),
    );
  }
}

// ─── TELA DE SPRITE PADRÃO ────────────────────────────────────────

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
    (id: 'pixel',   label: 'Pixel art',
      desc: 'Sprites clássicos dos jogos principais.',
      icon: Icons.grid_on_outlined),
    (id: 'home',    label: 'Pokémon HOME',
      desc: 'Renders 3D do Pokémon HOME. Disponível para a maioria dos Pokémon.',
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
            'Escolha o tipo de imagem exibida por padrão ao abrir um Pokémon. '
            'Você pode sempre mudar individualmente na tela de detalhes.',
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
                  color: isActive
                      ? scheme.primaryContainer.withOpacity(0.4)
                      : scheme.surfaceContainerLow,
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
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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

// ─── TELA DE TERMOS BILÍNGUES ─────────────────────────────────────

class BilingualSettingsScreen extends StatefulWidget {
  const BilingualSettingsScreen({super.key});

  @override
  State<BilingualSettingsScreen> createState() => _BilingualSettingsScreenState();
}

class _BilingualSettingsScreenState extends State<BilingualSettingsScreen> {
  // Por ora: toggle simples — se ativo, moves aparecem "Nome PT (EN)"
  bool _showBilingual = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termos bilíngues'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Configura como nomes de moves são exibidos na aba Moves de cada Pokémon.',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant, width: 0.5),
            ),
            child: Column(children: [
              _BilingualTile(
                title: 'Mostrar nome em PT e EN',
                subtitle: 'Ex: "Investida (Tackle)"',
                value: _showBilingual,
                onChanged: (v) => setState(() => _showBilingual = v),
              ),
              Divider(height: 0.5, color: scheme.outlineVariant),
              _BilingualTile(
                title: 'Somente Português',
                subtitle: 'Ex: "Investida"',
                value: !_showBilingual,
                onChanged: (v) => setState(() => _showBilingual = !v),
              ),
            ]),
          ),
          const SizedBox(height: 20),
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
                'Outros idiomas (EN, ES, JP, etc.) serão adicionados em uma versão futura.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              )),
            ]),
          ),
        ],
      ),
    );
  }
}

class _BilingualTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BilingualTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            Text(subtitle, style: TextStyle(fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
          Radio<bool>(
            value: true,
            groupValue: value,
            onChanged: (_) => onChanged(true),
          ),
        ]),
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

  // Ordenadas por data de lançamento. Nacional removida (sempre ativa).
  static const _allPokedex = [
    _PokedexOption(id: 'pokémon_go',                        name: 'Pokémon GO',                     year: '2016'),
    _PokedexOption(id: 'lets_go_pikachu___eevee',           name: "Let's Go Pikachu / Eevee",       year: '2018'),
    _PokedexOption(id: 'sword___shield',                    name: 'Sword / Shield',                 year: '2019'),
    _PokedexOption(id: 'brilliant_diamond___shining_pearl', name: 'Brilliant Diamond / Shining Pearl', year: '2021'),
    _PokedexOption(id: 'legends:_arceus',                   name: 'Legends: Arceus',                year: '2022'),
    _PokedexOption(id: 'scarlet___violet',                  name: 'Scarlet / Violet',               year: '2022'),
    _PokedexOption(id: 'legends:_z-a',                      name: 'Legends: Z-A',                   year: '2025'),
    _PokedexOption(id: 'firered___leafgreen',               name: 'FireRed / LeafGreen',            year: '2026'),
    _PokedexOption(id: 'pokopia',                           name: 'Pokopia',                        year: '2026'),
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
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                        child: Row(children: [
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500,
                                color: isActive ? null : scheme.onSurfaceVariant,
                              )),
                              Text(p.year, style: TextStyle(
                                fontSize: 12, color: scheme.onSurfaceVariant)),
                            ],
                          )),
                          Switch(
                            value: isActive,
                            onChanged: (_) => _toggle(p.id),
                          ),
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
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      )),
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
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
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
              Text(title, style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.w500, color: titleColor)),
              Text(subtitle, style: TextStyle(fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
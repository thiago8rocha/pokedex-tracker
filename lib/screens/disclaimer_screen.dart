import 'package:flutter/material.dart';
import 'package:dexcurator/core/app_constants.dart';
import 'package:dexcurator/services/storage_service.dart';
import 'package:dexcurator/screens/pokedex_screen.dart';

// ─── ENTRY POINT ─────────────────────────────────────────────────
// Chamado no primeiro acesso. Exibe aviso de app não oficial + links
// para Termos e Política. Também acessível via Settings.

class DisclaimerScreen extends StatefulWidget {
  /// Se true, exibe como bottom sheet (via Settings).
  /// Se false, exibe como tela completa (primeiro acesso).
  final bool isFromSettings;

  /// Aba inicial: 0 = Aviso, 1 = Termos, 2 = Privacidade
  final int initialTab;

  const DisclaimerScreen({
    super.key,
    this.isFromSettings = false,
    this.initialTab = 0,
  });

  @override
  State<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends State<DisclaimerScreen> {
  // Qual aba está ativa: 0 = Sobre / Aviso, 1 = Termos, 2 = Privacidade
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  void _confirm() async {
    if (!widget.isFromSettings) {
      await StorageService().setDisclaimerSeen();
      if (!mounted) return;
      // É a tela raiz — navega direto para a Pokédex principal.
      final lastId = await StorageService().getLastPokedexId();
      final id = lastId ?? 'nacional';
      const nameMap = <String, String>{
        'nacional': 'Nacional', 'pokémon_go': 'Pokémon GO', 'pokopia': 'Pokopia',
      };
      final name = nameMap[id] ?? 'Nacional';
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PokedexScreen(
            pokedexId: id,
            pokedexName: name,
            totalPokemon: id == 'nacional' ? 1025
                : id == 'pokémon_go' ? 941
                : id == 'pokopia' ? 304
                : 0,
          ),
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isFromSettings) {
      // Bottom sheet — sem AppBar, com handle
      return _buildSheetBody(scheme, isDark);
    }

    // Tela completa — primeiro acesso
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(child: _buildSheetBody(scheme, isDark)),
    );
  }

  Widget _buildSheetBody(ColorScheme scheme, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle (só no sheet)
        if (widget.isFromSettings)
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

        // Tab bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              _TabButton(label: 'Aviso', index: 0, current: _tab,
                  onTap: (i) => setState(() => _tab = i)),
              const SizedBox(width: 8),
              _TabButton(label: 'Termos', index: 1, current: _tab,
                  onTap: (i) => setState(() => _tab = i)),
              const SizedBox(width: 8),
              _TabButton(label: 'Privacidade', index: 2, current: _tab,
                  onTap: (i) => setState(() => _tab = i)),
            ],
          ),
        ),

        const SizedBox(height: 8),
        const Divider(height: 1),

        // Conteúdo com scroll
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: _tab == 0
                ? _buildAbout(scheme)
                : _tab == 1
                    ? _buildTerms(scheme)
                    : _buildPrivacy(scheme),
          ),
        ),

        // Botão fechar / confirmar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                side: BorderSide(color: scheme.primary, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _confirm,
              child: Text(
                widget.isFromSettings ? 'Fechar' : 'Entendi',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: scheme.primary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── ABA 0: AVISO ────────────────────────────────────────────────

  Widget _buildAbout(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(text: 'Conteúdo e direitos autorais'),
        _BodyText(
            text:
                'Este é um aplicativo não oficial, fan-made e gratuito que contém '
                'informações detalhadas sobre Pokémon, jogos, golpes, habilidades, '
                'localização e muito mais.'),
        const SizedBox(height: 12),
        _BodyText(
            text:
                'Artes, visuais e nomes são propriedade da Game Freak, Nintendo '
                'e The Pokémon Company.'),
        const SizedBox(height: 12),
        _BodyText(
            text:
                'Este app não é oficial e não possui vínculo com as empresas citadas. '
                'Algumas imagens utilizadas são protegidas por direitos autorais e pertencem '
                'à Nintendo, GAME FREAK ou The Pokémon Company. Elas são usadas neste app '
                'em conformidade com os princípios de Fair Use. '
                'Nenhuma violação de direitos autorais é intencional.'),
        const SizedBox(height: 12),
        _CopyrightLine(text: '© 2002–2026 Pokémon'),
        _CopyrightLine(
            text: '© 1995–2026 Nintendo/Creatures Inc./GAME FREAK Inc.'),
        const SizedBox(height: 20),
        _SectionTitle(text: 'Licença do conteúdo'),
        _BodyText(
            text:
                'O conteúdo original do DexCurator é licenciado sob os termos '
                'indicados no repositório público do projeto:'),
        const SizedBox(height: 8),
        _LinkText(
            text: kRepoUrl,
            scheme: scheme),
        const SizedBox(height: 20),
        _SectionTitle(text: 'Fontes de dados'),
        _BodyText(text: 'As principais fontes de dados utilizadas neste app são:'),
        const SizedBox(height: 8),
        _SourceItem(
            text: 'PokéAPI (dados de Pokémon, golpes, habilidades)',
            scheme: scheme),
        _SourceItem(
            text: 'Bulbapedia (informações gerais)',
            scheme: scheme),
        _SourceItem(
            text: 'Serebii (informações gerais)',
            scheme: scheme),
        _SourceItem(
            text: 'PokeSprite (sprites e ícones)',
            scheme: scheme),
        const SizedBox(height: 12),
        _BodyText(
            text:
                'Se houver alguma menção ausente, entre em contato pelo '
                'repositório do projeto.'),
        const SizedBox(height: 8),
      ],
    );
  }

  // ─── ABA 1: TERMOS ───────────────────────────────────────────────

  Widget _buildTerms(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(text: 'Termos e Condições de Uso'),
        _BodyText(
            text:
                'Ao utilizar o DexCurator, o usuário declara ter lido e aceito '
                'integralmente estes Termos.'),
        const SizedBox(height: 16),

        _SubTitle(text: '1. Natureza do Aplicativo'),
        _BodyText(
            text:
                'O DexCurator é um app fan-made, não oficial, gratuito, sem fins '
                'lucrativos e de código aberto. Não possui vínculo com Nintendo, '
                'Game Freak, Creatures Inc. ou The Pokémon Company.'),
        const SizedBox(height: 12),

        _SubTitle(text: '2. Uso Permitido'),
        _BodyText(
            text:
                'O app é disponibilizado exclusivamente para uso pessoal e não '
                'comercial. É proibido utilizá-lo para fins comerciais, distribuir '
                'seu conteúdo sem autorização ou realizar engenharia reversa.'),
        const SizedBox(height: 12),

        _SubTitle(text: '3. Dados Locais'),
        _BodyText(
            text:
                'Todos os dados gerados pelo usuário (capturas, configurações, '
                'progresso) são armazenados exclusivamente no dispositivo. '
                'O desenvolvedor não tem acesso a essas informações.'),
        const SizedBox(height: 12),

        _SubTitle(text: '4. Propriedade Intelectual'),
        _BodyText(
            text:
                'Nomes, sprites e demais ativos da franquia Pokémon são propriedade '
                'de seus respectivos titulares e são usados sob os princípios de '
                'Fair Use (art. 46, Lei n.º 9.610/1998 e 17 U.S.C. § 107).'),
        const SizedBox(height: 12),

        _SubTitle(text: '5. Isenção de Garantias'),
        _BodyText(
            text:
                'O app é fornecido "no estado em que se encontra", sem garantias '
                'de funcionamento contínuo ou ausência de erros. Pode ser '
                'descontinuado sem aviso prévio.'),
        const SizedBox(height: 12),

        _SubTitle(text: '6. Lei Aplicável'),
        _BodyText(
            text:
                'Estes Termos são regidos pela legislação brasileira, em especial '
                'a LGPD (Lei n.º 13.709/2018), o Marco Civil da Internet '
                '(Lei n.º 12.965/2014) e o Código de Defesa do Consumidor '
                '(Lei n.º 8.078/1990).'),
        const SizedBox(height: 12),

        _SubTitle(text: '7. Contato'),
        _LinkText(
            text: kRepoUrl,
            scheme: scheme),
        const SizedBox(height: 8),

        _DateText(text: 'Vigência: Abril de 2026'),
        const SizedBox(height: 8),
      ],
    );
  }

  // ─── ABA 2: PRIVACIDADE ──────────────────────────────────────────

  Widget _buildPrivacy(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(text: 'Política de Privacidade'),
        _BodyText(
            text:
                'Esta Política descreve como o DexCurator trata as informações '
                'do usuário, em conformidade com a LGPD (Lei n.º 13.709/2018).'),
        const SizedBox(height: 16),

        // Destaque: nenhum dado coletado
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: scheme.primary.withOpacity(0.3), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Nenhum dado pessoal é coletado ou enviado. '
                  'Sem conta, sem analytics, sem anúncios.',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _SubTitle(text: '1. Dados Coletados'),
        _BodyText(
            text:
                'O DexCurator não coleta, processa, transmite nem armazena '
                'remotamente qualquer dado pessoal. Sem coleta de nome, e-mail, '
                'localização, IP, analytics ou rastreamento de qualquer natureza.'),
        const SizedBox(height: 12),

        _SubTitle(text: '2. Dados Locais'),
        _BodyText(
            text:
                'O app armazena no dispositivo do usuário, via SharedPreferences '
                'do Android: progresso de capturas, preferências e configurações. '
                'Esses dados ficam sob controle exclusivo do usuário.'),
        const SizedBox(height: 12),

        _SubTitle(text: '3. Sem Analytics'),
        _BodyText(
            text:
                'Nenhum SDK de analytics, crash reporting ou publicidade está '
                'integrado ao app (sem Firebase, Google Analytics, AdMob etc.). '
                'Dados agregados e anônimos de instalações são fornecidos pelo '
                'Google Play Console nativamente, sem SDK no app.'),
        const SizedBox(height: 12),

        _SubTitle(text: '4. Conformidade com a LGPD'),
        _BodyText(
            text:
                'Por não realizar tratamento de dados pessoais, as obrigações '
                'de consentimento da LGPD não se aplicam. Os direitos do art. 18 '
                '(acesso, correção, exclusão) são exercidos diretamente pelo '
                'usuário nas configurações do Android.'),
        const SizedBox(height: 12),

        _SubTitle(text: '5. Crianças e Adolescentes'),
        _BodyText(
            text:
                'O app está em conformidade com o art. 14 da LGPD. Por não '
                'coletar dados de nenhum usuário, é seguro para uso por '
                'crianças e adolescentes sem necessidade de consentimento '
                'dos pais para fins de tratamento de dados.'),
        const SizedBox(height: 12),

        _SubTitle(text: '6. Transparência'),
        _BodyText(
            text:
                'O código-fonte é público e pode ser auditado para verificar '
                'estas afirmações:'),
        const SizedBox(height: 6),
        _LinkText(
            text: kRepoUrl,
            scheme: scheme),
        const SizedBox(height: 12),

        _SubTitle(text: '7. Contato'),
        _BodyText(
            text:
                'Para dúvidas sobre esta Política, entre em contato via '
                'GitHub Issues no repositório do projeto.'),
        const SizedBox(height: 8),

        _DateText(text: 'Vigência: Abril de 2026'),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── WIDGETS AUXILIARES ──────────────────────────────────────────

class _TabButton extends StatelessWidget {
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  const _TabButton({
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active ? scheme.primary : scheme.outlineVariant,
            width: active ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _SubTitle extends StatelessWidget {
  final String text;
  const _SubTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;
  const _BodyText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.55,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _CopyrightLine extends StatelessWidget {
  final String text;
  const _CopyrightLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _LinkText extends StatelessWidget {
  final String text;
  final ColorScheme scheme;
  const _LinkText({required this.text, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: scheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: scheme.primary,
      ),
    );
  }
}

class _SourceItem extends StatelessWidget {
  final String text;
  final ColorScheme scheme;
  const _SourceItem({required this.text, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ',
              style: TextStyle(
                  fontSize: 13, color: scheme.onSurfaceVariant)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateText extends StatelessWidget {
  final String text;
  const _DateText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context)
            .colorScheme
            .onSurfaceVariant
            .withOpacity(0.6),
      ),
    );
  }
}

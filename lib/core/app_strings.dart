/// Strings da interface do usuário — Português (Brasil).
///
/// ARQUITETURA DE INTERNACIONALIZAÇÃO
/// ────────────────────────────────────────────────────────────────
/// Este arquivo é a base para suporte a múltiplos idiomas.
///
/// Padrão adotado: classe estática simples (sem flutter_localizations por ora).
/// Quando chegar a hora de publicar e adicionar idiomas:
///
///   1. Crie `app_strings_en.dart` com a mesma estrutura.
///   2. Crie `app_strings_es.dart`, etc.
///   3. Substitua `AppStrings` por um provider que retorna a
///      implementação correta baseada em `Localizations.localeOf(context)`.
///   4. Nenhuma string de UI precisará ser alterada — só o provider.
///
/// REGRAS:
///   - Toda string visível ao usuário deve ter uma constante aqui.
///   - Nomes de Pokémon NÃO entram aqui (ficam nos dados).
///   - Tipos de Pokémon têm mapeamento próprio em type_colors.dart.
///   - Chaves de SharedPreferences e IDs internos NÃO entram aqui.

class AppStrings {
  AppStrings._();

  // ── Geral ──────────────────────────────────────────────────────
  static const String appName       = 'DexCurator';
  static const String loading        = 'Carregando...';
  static const String retry          = 'Tentar novamente';
  static const String apply          = 'Aplicar';
  static const String clear          = 'Limpar';
  static const String close          = 'Fechar';
  static const String confirm        = 'Confirmar';
  static const String cancel         = 'Cancelar';
  static const String search         = 'Buscar';
  static const String error          = 'Erro';
  static const String noResults      = 'Nenhum resultado';
  static const String yes            = 'Sim';
  static const String no             = 'Não';

  // ── Pokédex / Home ─────────────────────────────────────────────
  static const String pokedex             = 'Pokédex';
  static const String pokedexTitle        = 'Pokédex';
  static const String loadingPokemon      = 'Carregando Pokémon...';
  static const String searchHint         = 'Nome, número ou tipo...';
  static const String selectGame         = 'Selecionar Jogo';
  static const String filters            = 'Filtros';
  static const String status             = 'Status';
  static const String sortBy             = 'Ordenar por';
  static const String ascending          = 'Crescente';
  static const String descending         = 'Decrescente';
  static const String generation         = 'Geração';
  static const String selectUpToTwo     = 'Selecione até dois tipos diferentes';
  static const String specialties        = 'Especialidades';
  static const String all                = 'Todos';
  static const String caught             = 'Capturados';
  static const String notCaught         = 'Não capturados';
  static String generationN(int n)       => 'Geração $n';
  static String selectedCount(int n)     => '$n selecionado(s)';
  static String selectedFraction(int n, int max) => '$n/$max selecionado(s)';
  static String dlcLabel(String label)   => '$label (DLC)';

  // ── Bottom Nav ─────────────────────────────────────────────────
  static const String navHome      = 'Início';
  static const String navPocket    = 'Pocket';
  static const String navGo        = 'GO';
  static const String navPokopia   = 'Pokopia';
  static const String navMenu      = 'Menu';

  // ── Drawer ────────────────────────────────────────────────────
  static const String drawerMoves       = 'Golpes';
  static const String drawerAbilities   = 'Habilidades';
  static const String drawerNatures     = 'Naturezas';
  static const String drawerTeams       = 'Times';
  static const String drawerItems       = 'Itens';
  static const String drawerSettings    = 'Configurações';
  static const String menu              = 'Menu';

  // ── Detalhe do Pokémon ─────────────────────────────────────────
  static const String tabAbout          = 'Sobre';
  static const String tabStats          = 'Status';
  static const String tabMoves          = 'Golpes';
  static const String tabForms          = 'Formas';
  static const String baseStats         = 'Status Base';
  static const String typeEffectiveness = 'Efetividade de Tipos';
  static const String weakTo            = 'Fraco a';
  static const String veryWeakTo       = 'Muito fraco a';
  static const String resistantTo      = 'Resistente a';
  static const String veryResistantTo  = 'Muito resistente a';
  static const String immuneTo         = 'Imune a';
  static const String statMin          = 'Mínimo';
  static const String statMax          = 'Máximo';
  static const String statBase         = 'Base';
  static const String height           = 'Altura';
  static const String weight           = 'Peso';
  static const String abilities        = 'Habilidades';
  static const String hiddenAbility    = 'Habilidade Oculta';
  static const String evolutionChain   = 'Cadeia Evolutiva';
  static const String noEvolution      = 'Sem evolução';
  static const String level            = 'Nível';
  static const String happiness        = 'Amizade';
  static const String evolve           = 'Evoluir';

  // ── Golpes ─────────────────────────────────────────────────────
  static const String movesLevel       = 'Nível';
  static const String movesTm          = 'MT';
  static const String movesTutor       = 'Tutor';
  static const String movesEgg         = 'Ovo';
  static const String movePower        = 'Poder';
  static const String moveAccuracy     = 'Precisão';
  static const String movePp           = 'PP';
  static const String moveType         = 'Tipo';
  static const String moveCategory     = 'Categoria';
  static const String moveEffect       = 'Efeito';
  static const String noMoves          = 'Nenhum golpe nesta categoria';

  // ── Configurações ─────────────────────────────────────────────
  static const String settings         = 'Configurações';
  static const String theme            = 'Tema';
  static const String defaultSprite    = 'Sprite padrão';
  static const String bilingualMode    = 'Modo bilíngue';
  static const String managePokedex    = 'Gerenciar Pokédex';
  static const String clearData        = 'Limpar dados';
  static const String clearDataConfirm = 'Tem certeza? Isso apagará todo o progresso.';
  static const String otherLanguages   = 'Outros idiomas serão adicionados em uma versão futura.';
  static const String spriteArtwork    = 'Artwork';
  static const String spriteHome       = 'Home';
  static const String spritePixel      = 'Pixel';

  // ── Disclaimer / Legal ─────────────────────────────────────────
  static const String disclaimerTitle     = 'Aviso';
  static const String termsTitle          = 'Termos';
  static const String privacyTitle        = 'Privacidade';
  static const String disclaimerConfirm   = 'Entendi e aceito';

  // ── GO Hub ────────────────────────────────────────────────────
  static const String goHub          = 'Pokémon GO';
  static const String goRaids        = 'Raids';
  static const String goCpCalc       = 'Calculadora de CP';
  static const String goRegionalForms = 'Formas Regionais';
  static const String goMegas        = 'Mega Evoluções';
  static const String goGigantamax   = 'Gigantamax';

  // ── Pocket Hub ────────────────────────────────────────────────
  static const String pocketHub      = 'TCG Pocket';
  static const String pocketCards    = 'Cartas';

  // ── Pokopia Hub ───────────────────────────────────────────────
  static const String pokopiaHub      = 'Pokopia';
  static const String pokopiaFriends  = 'Amigos';
  static const String pokopiaHabitats = 'Habitats';
  static const String pokopiaRelics   = 'Relíquias';
  static const String pokopiaFlavors  = 'Receitas';
  static const String pokopiaFossils  = 'Fósseis';

  // ── Erros / Feedback ──────────────────────────────────────────
  static const String errorLoadingRaids = 'Não foi possível carregar as raids';
  static const String errorLoadingData  = 'Não foi possível carregar os dados';
  static const String errorNoData       = 'Sem dados disponíveis';
}

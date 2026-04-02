/// Constantes globais do DexCurator.
///
/// Centraliza URLs, identificadores e valores fixos usados em múltiplos
/// arquivos. Para adicionar uma constante nova, sempre coloque aqui —
/// nunca repita strings literais em mais de um arquivo.

// ─── IDENTIFICAÇÃO DO APP ──────────────────────────────────────────

/// Nome público do aplicativo.
const String kAppName = 'DexCurator';

/// URL do repositório público (usada em Disclaimer, créditos, etc.).
const String kRepoUrl = 'github.com/thiago8rocha/DexCurator';

/// Application ID do Android (não alterar após publicar na Play Store).
const String kApplicationId = 'com.thiago8rocha.dexcurator';

// ─── POKÉAPI ───────────────────────────────────────────────────────

/// Base URL da PokéAPI v2.
/// Usada por: PokeApiService, PokedexDownloadService,
///            PokedexSilentRefreshService, GoCpCalculatorScreen.
const String kPokeApiBase = 'https://pokeapi.co/api/v2';

// ─── SPRITES (PokeAPI GitHub) ──────────────────────────────────────

/// Base dos sprites no repositório oficial da PokéAPI.
/// Usada por: SpriteService, GoCpCalculatorScreen.
const String kSpriteBase =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';

// ─── TCG DEX ──────────────────────────────────────────────────────

/// Base da API TCGdex (cartas do TCG Pocket).
const String kTcgDexBase = 'https://api.tcgdex.net/v2/en';

/// Base dos assets de imagem TCGdex.
const String kTcgDexAssets = 'https://assets.tcgdex.net/en';

// ─── TRADUÇÃO ─────────────────────────────────────────────────────

/// API MyMemory — tradução gratuita sem chave.
const String kMyMemoryBase = 'https://api.mymemory.translated.net/get';

// ─── POKÉMON ──────────────────────────────────────────────────────

/// Total de Pokémon na Pokédex Nacional (Gen 1–9).
const int kTotalPokemon = 1025;

/// Total de Pokémon disponíveis no Pokémon GO.
const int kTotalPokemonGo = 941;

/// Total de Pokémon no Pokopia.
const int kTotalPokopia = 304;

// ─── USER-AGENT ───────────────────────────────────────────────────

/// User-Agent padrão para requisições HTTP do app.
/// Identifica o DexCurator sem se passar por browser anônimo.
const String kUserAgent = 'DexCurator/1.0 (Android; github.com/thiago8rocha/DexCurator)';

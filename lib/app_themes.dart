import 'package:flutter/material.dart';

enum BackgroundScene { original, hills, snowyHills, image }

enum BackgroundEffect { none, petals, clouds, leaves, snow }

@immutable
class BackgroundDesign {
  const BackgroundDesign({
    this.scene = BackgroundScene.hills,
    this.effect = BackgroundEffect.none,
    required this.sky,
    required this.ground,
    this.horizon = const Color(0xFFFFFCF7),
    this.particle = const Color(0x99FFFFFF),
    this.secondaryParticle = const Color(0x99FFFFFF),
    this.speed = 1,
    this.density = 1,
    this.imageAsset,
  }) : assert(speed > 0),
       assert(density > 0),
       assert(scene != BackgroundScene.image || imageAsset != null);
  final BackgroundScene scene;
  final BackgroundEffect effect;
  final Color sky, horizon, ground, particle, secondaryParticle;
  final double speed, density;
  final String? imageAsset;
  bool get animated => effect != BackgroundEffect.none;
}

@immutable
class AppThemeDefinition {
  const AppThemeDefinition({
    required this.id,
    required this.nameKo,
    required this.nameEn,
    required this.group,
    required this.background,
    required this.accent,
    required this.chrome,
    required this.tonal,
    required this.ink,
    required this.page,
    this.surface = Colors.white,
    this.brightness = Brightness.light,
  });
  final String id, nameKo, nameEn, group;
  final BackgroundDesign background;
  final Color accent, chrome, tonal, ink, page, surface;
  final Brightness brightness;

  ThemeData buildTheme() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          primary: accent,
          onPrimary: brightness == Brightness.light
              ? Colors.white
              : Colors.black,
          primaryContainer: tonal,
          onPrimaryContainer: accent,
          surface: surface,
          onSurface: ink,
          surfaceContainerLow: chrome,
          surfaceContainerHighest: tonal,
          outlineVariant: accent.withValues(alpha: 0.16),
        );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansKR',
      colorScheme: scheme,
      scaffoldBackgroundColor: page,
      appBarTheme: AppBarTheme(
        backgroundColor: chrome,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: scheme.onPrimary,
          elevation: 1,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: chrome,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerColor: scheme.outlineVariant,
    );
  }
}

// Register new themes here. IDs are persisted: never rename/reuse an existing ID.
class AppThemes {
  static const all = <AppThemeDefinition>[
    AppThemeDefinition(
      id: 'spring',
      nameKo: '봄',
      nameEn: 'Spring',
      group: 'season',
      accent: Color(0xFF8C5062),
      chrome: Color(0xFFFBF3F5),
      tonal: Color(0xFFF3E4E9),
      ink: Color(0xFF453840),
      page: Color(0xFFFFFAFB),
      background: BackgroundDesign(
        sky: Color(0xFFFFF0F3),
        ground: Color(0xFFDCE8D3),
        effect: BackgroundEffect.petals,
        particle: Color(0x99E9A8BA),
        secondaryParticle: Color(0x99E9A8BA),
      ),
    ),
    AppThemeDefinition(
      id: 'summer',
      nameKo: '여름',
      nameEn: 'Summer',
      group: 'season',
      accent: Color(0xFF346C73),
      chrome: Color(0xFFF0F7F8),
      tonal: Color(0xFFE0EFF0),
      ink: Color(0xFF30464A),
      page: Color(0xFFF7FBFB),
      background: BackgroundDesign(
        sky: Color(0xFFEAF5FA),
        horizon: Color(0xFFF9FCF4),
        ground: Color(0xFFD7E8CD),
        effect: BackgroundEffect.clouds,
      ),
    ),
    AppThemeDefinition(
      id: 'autumn',
      nameKo: '가을',
      nameEn: 'Autumn',
      group: 'season',
      accent: Color(0xFF805A3A),
      chrome: Color(0xFFFAF4EC),
      tonal: Color(0xFFF1E6D8),
      ink: Color(0xFF493E32),
      page: Color(0xFFFFFCF7),
      background: BackgroundDesign(
        sky: Color(0xFFFAEFDF),
        ground: Color(0xFFEBD9BE),
        effect: BackgroundEffect.leaves,
        particle: Color(0x99BF855B),
        secondaryParticle: Color(0x99D7AC63),
      ),
    ),
    AppThemeDefinition(
      id: 'winter',
      nameKo: '겨울',
      nameEn: 'Winter',
      group: 'season',
      accent: Color(0xFF4B687E),
      chrome: Color(0xFFF2F6F8),
      tonal: Color(0xFFE3EBF0),
      ink: Color(0xFF34434F),
      page: Color(0xFFF8FAFC),
      background: BackgroundDesign(
        scene: BackgroundScene.snowyHills,
        sky: Color(0xFFEDF2F6),
        ground: Color(0xFFDFE8ED),
        effect: BackgroundEffect.snow,
        particle: Color(0xE6FFFFFF),
        secondaryParticle: Color(0x99B8CED9),
      ),
    ),
    AppThemeDefinition(
      id: 'original',
      nameKo: '기본 테마',
      nameEn: 'Classic',
      group: 'basic',
      accent: Color(0xFF9B4658),
      chrome: Color(0xFFF3EAE0),
      tonal: Color(0xFFF2E3E7),
      ink: Color(0xFF403735),
      page: Color(0xFFFFFCF7),
      background: BackgroundDesign(
        scene: BackgroundScene.original,
        sky: Color(0xFFFFFCF7),
        ground: Color(0xFFFFFCF7),
      ),
    ),
  ];
  static AppThemeDefinition byId(String id) => all.firstWhere(
    (theme) => theme.id == id,
    orElse: () => all.firstWhere((theme) => theme.id == 'original'),
  );
  static String seasonalId(DateTime date) {
    if (date.month >= 3 && date.month <= 5) return 'spring';
    if (date.month >= 6 && date.month <= 8) return 'summer';
    if (date.month >= 9 && date.month <= 11) return 'autumn';
    return 'winter';
  }
}

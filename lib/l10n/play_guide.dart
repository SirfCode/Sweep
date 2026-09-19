/// Add translated help assets here as they become available. Unsupported
/// languages use the short English player guide, never the developer rulebook.
const playerGuideAssets = <String, String>{
  'en': 'assets/help/how_to_play_en.txt',
};

String playerGuideAsset(String languageCode) =>
    playerGuideAssets[languageCode] ?? playerGuideAssets['en']!;

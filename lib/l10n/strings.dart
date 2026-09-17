import 'package:flutter/material.dart';
import 'catalog.dart';

String localized(String key, String language,
    [Map<String, Object?> values = const {}]) {
  final messages = messageCatalog[key];
  var result = messages?[language] ?? messages?['en'] ?? key;
  for (final entry in values.entries) {
    result = result.replaceAll('{${entry.key}}', '${entry.value ?? ''}');
  }
  return result;
}

String tr(BuildContext context, String key,
        [Map<String, Object?> values = const {}]) =>
    localized(key, Localizations.localeOf(context).languageCode, values);
String playerName(BuildContext context, int seat) =>
    seat == 0 && Localizations.localeOf(context).languageCode == 'hi'
        ? 'आप'
        : ['You', 'Mira', 'Ari', 'Dev'][seat];

class LanguageScope extends InheritedWidget {
  final ValueChanged<String> change;
  const LanguageScope({super.key, required this.change, required super.child});
  static LanguageScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()!;
  @override
  bool updateShouldNotify(LanguageScope oldWidget) =>
      change != oldWidget.change;
}

String historyText(BuildContext context, Map<String, dynamic> record) {
  final english = '${record['text'] ?? ''}'
      .replaceAll('sweep', 'seep')
      .replaceAll('Sweep', 'Seep');
  if (Localizations.localeOf(context).languageCode != 'hi') return english;
  final a = (record['args'] as Map?) ?? {};
  final player =
      a['player'] is int ? playerName(context, a['player'] as int) : '';
  return switch (record['event']) {
    'dealStart' =>
      'बाज़ी ${a['deal']} • ${playerName(context, a['dealer'] as int)} पत्ते बाँटते हैं। $player बोली लगाते हैं।${a['retries'] == 0 ? '' : ' गड्डी ${a['retries']} बार दोबारा फेंटी गई।'}',
    'call' => '$player की बोली ${a['value']}। मेज़ के पत्ते खोल दिए गए।',
    'discard' => '$player ने ${a['card']} फेंका।',
    'capture' =>
      '$player ने ${a['card']} से ${a['cards']} उठाए (पत्तों के ${a['points']} अंक)।',
    'clear' => '$player ने मेज़ खाली की • ${a['points']} अस्थायी सीप अंक।',
    'build' =>
      '$player ने ${a['card']} से ${a['value']} का घर ${a['raise'] == true ? 'बढ़ाया' : 'बनाया / उसमें जोड़ा'}${a['pakka'] == true ? ' • पक्का' : ''}।',
    'dealt' => 'बाकी पत्ते बाँट दिए गए।',
    'leftovers' =>
      'बचे पत्ते ${a['team'] == 0 ? 'आपकी टीम' : 'विरोधी टीम'} को मिले; कोई सीप बोनस नहीं।',
    'scored' => 'बाज़ी ${a['deal']} के अंक: ${a['us']} – ${a['them']}।',
    _ => english,
  };
}

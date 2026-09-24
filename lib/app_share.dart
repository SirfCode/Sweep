import 'package:share_plus/share_plus.dart';

const playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.nzkosh.seep';

class AppShare {
  static Future<void> seep() => SharePlus.instance.share(ShareParams(
      subject: 'Seep',
      text:
          "I'm playing Seep, a classic card game with smart bot opponents. Try it here:\n$playStoreUrl"));
}

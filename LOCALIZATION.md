# Seep languages

English and Hindi are supported. Both use left-to-right layouts. Use the globe button on the home screen or game table to change languages. The device's supported language is used initially, with English as the fallback. An explicit choice is saved locally and does not change the current deal.

## Translation resources

- `lib/l10n/catalog.dart`: bundled interface messages, with stable keys and matching placeholders in English and Hindi.
- `lib/l10n/strings.dart`: rendering helpers, player labels and translations for structured public game events.
- `SEEP_RULES.md` and `SEEP_RULES_HI.md`: complete rules in both languages. Keep rule changes aligned.
- `assets/fonts/NotoSansDevanagari.ttf`: bundled font for offline Hindi rendering. Source: [Google Fonts Noto Sans Devanagari](https://github.com/google/fonts/tree/main/ofl/notosansdevanagari). Its SIL Open Font License is included beside the font.

Card ranks A/J/Q/K, suit symbols and bot names stay unchanged. Numerals remain 0–9 for consistency with the cards. Hindi terms include बाज़ी (deal), बोली (call), घर (house), पक्का घर (pakka house), उठाएँ (capture), and सीप (Seep). Hindi wording is ready for user review and can be adjusted without changing the rules.

New move-history records store public event types and values, so the same history can display in either language. Older English-only history stays readable in English; the old game name is normalised to Seep when displayed. Technical decision-diagnostic JSON remains in English for reproducible analysis.

Existing save keys, package identifiers, internal class names and the GitHub repository name retain their legacy spelling for compatibility. User-facing branding is Seep/सीप. Switching languages preserves cards, scores, the bot's information and turn order. It briefly pauses play while the language dialog is open.

## Adding or changing translations

Keep message keys stable. Update both language values, preserving all `{p0}`, `{p1}` and other placeholder names. Translate whole sentences rather than assembling language-dependent word order from fragments. Add another supported locale and Flutter delegate support before offering another language. Right-to-left languages are outside the current scope.

Run `flutter test test/localization_test.dart test/table_ui_test.dart` and `flutter analyze`. The tests check placeholder parity, device-language fallback, in-game switching, persistence, portrait/landscape layouts, translated history and legacy saves. Review the actual Hindi text with a fluent player before publishing a release.

Validation for this implementation: all 62 tests passed; web and Android debug builds succeeded. The Hindi home screen was also inspected in the web preview with the bundled font. Android runtime interaction was not retested on a device in this change.
# Player help

The in-app **How to play** guide uses `assets/help/how_to_play_en.txt`.
English is the fallback until translations are added. Register future translated
assets in `lib/l10n/play_guide.dart`; the existing language selector will choose
them automatically. Keep each translation as short as the English guide.
`SEEP_RULES.md` and `SEEP_RULES_HI.md` remain repository-only developer references
and are not bundled in the app.

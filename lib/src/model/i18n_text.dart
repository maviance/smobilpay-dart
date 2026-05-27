/// Localized text entry. Used for service hints and field labels.
class I18nText {
  /// Creates an [I18nText].
  const I18nText({required this.language, required this.localText});

  /// Decodes from JSON.
  factory I18nText.fromJson(Map<String, dynamic> json) => I18nText(
        language: json['language'] as String,
        localText: json['localText'] as String,
      );

  /// Target language code (ISO 639-1, e.g. `en`, `fr`).
  final String language;

  /// Localized text.
  final String localText;

  /// Encodes to JSON.
  Map<String, dynamic> toJson() => {
        'language': language,
        'localText': localText,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is I18nText && language == other.language && localText == other.localText;

  @override
  int get hashCode => Object.hash(language, localText);

  @override
  String toString() => 'I18nText($language: $localText)';
}

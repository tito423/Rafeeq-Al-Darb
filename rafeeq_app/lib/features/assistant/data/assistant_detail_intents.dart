part of 'assistant_intent.dart';

class MemorizeSurahIntent extends AssistantIntent {
  const MemorizeSurahIntent(this.surah);
  final int surah;
  @override
  String toString() => 'memorize surah $surah';
}

class OpenSunanSurahIntent extends AssistantIntent {
  const OpenSunanSurahIntent(this.surah);
  final int surah;
  @override
  String toString() => 'sunan surah $surah';
}

class OpenAzkarSectionIntent extends AssistantIntent {
  const OpenAzkarSectionIntent(this.sectionId);
  final int sectionId;
  @override
  String toString() => 'azkar section $sectionId';
}

class OpenAyahReciterIntent extends AssistantIntent {
  const OpenAyahReciterIntent(this.reciterId);
  final String reciterId;
  @override
  String toString() => 'ayah reciter $reciterId';
}

import '../services/language_service.dart';

class TextUtil {
  static String getCategorySelectionLabel(String? userSegment) {
    final isTurkish = LanguageService.instance.isTurkish;
    if (userSegment == 'work') return isTurkish ? 'KATEGORİ SEÇ' : 'SELECT CATEGORY';
    return isTurkish ? 'DERS SEÇ' : 'SELECT SUBJECT';
  }
}

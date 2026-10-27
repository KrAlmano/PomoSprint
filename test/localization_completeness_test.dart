import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/models/avatar_model.dart';
import 'package:pomodoro/utils/category_names.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _keys(Map<String, dynamic> map) =>
    map.keys.where((key) => !key.startsWith('@')).toSet();

Set<String> _placeholders(String value) => RegExp(
  r'\{([a-zA-Z_]\w*)\s*[,}]',
).allMatches(value).map((match) => match.group(1)!).toSet();

Iterable<File> _sources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    // Generated output is checked through its source ARBs instead.
    .where(
      (file) => !file.path.split('/').last.startsWith('app_localizations'),
    );

class _Token {
  const _Token(this.value, this.offset, {this.literal = false});
  final String value;
  final int offset;
  final bool literal;
}

bool _letter(String c) => RegExp(r'[a-zA-Z_$]').hasMatch(c);
bool _word(String c) => RegExp(r'[a-zA-Z0-9_$]').hasMatch(c);

// A small lexical scanner rather than a line regex: comments, escaped quotes,
// raw strings, triple strings and interpolation expressions are recognised.
// It intentionally checks literals at display sinks, not arbitrary source
// strings such as database keys, SQL error codes, routes or custom user names.
List<_Token> _tokens(String source) {
  final out = <_Token>[];
  var i = 0;
  void skipComment() {
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      i = end < 0 ? source.length : end;
    } else {
      var depth = 1;
      i += 2;
      while (i < source.length && depth > 0) {
        if (source.startsWith('/*', i)) {
          depth++;
          i += 2;
        } else if (source.startsWith('*/', i)) {
          depth--;
          i += 2;
        } else {
          i++;
        }
      }
    }
  }

  late String Function() readString;
  void skipInterpolation() {
    var depth = 1;
    i += 2; // ${
    while (i < source.length && depth > 0) {
      if (source.startsWith('//', i) || source.startsWith('/*', i)) {
        skipComment();
      } else if (source[i] == "'" ||
          source[i] == '"' ||
          (source[i] == 'r' &&
              i + 1 < source.length &&
              (source[i + 1] == "'" || source[i + 1] == '"'))) {
        readString();
      } else if (source[i] == '{') {
        depth++;
        i++;
      } else if (source[i] == '}') {
        depth--;
        i++;
      } else {
        i++;
      }
    }
  }

  readString = () {
    final raw = source[i] == 'r';
    if (raw) i++;
    final quote = source[i];
    final delimiter = source.startsWith(quote * 3, i) ? quote * 3 : quote;
    i += delimiter.length;
    final text = StringBuffer();
    while (i < source.length) {
      if (source.startsWith(delimiter, i)) {
        i += delimiter.length;
        break;
      }
      if (!raw && source[i] == r'\' && i + 1 < source.length) {
        final next = source[i + 1];
        text.write(next == 'n' || next == 't' || next == 'r' ? ' ' : next);
        i += 2;
      } else if (!raw && source.startsWith(r'${', i)) {
        skipInterpolation();
      } else if (!raw &&
          source[i] == r'$' &&
          i + 1 < source.length &&
          _letter(source[i + 1])) {
        i += 2;
        while (i < source.length && _word(source[i])) {
          i++;
        }
      } else {
        text.write(source[i]);
        i++;
      }
    }
    return text.toString();
  };

  while (i < source.length) {
    if (RegExp(r'\s').hasMatch(source[i])) {
      i++;
      continue;
    }
    if (source.startsWith('//', i) || source.startsWith('/*', i)) {
      skipComment();
      continue;
    }
    final offset = i;
    if (source[i] == "'" ||
        source[i] == '"' ||
        (source[i] == 'r' &&
            i + 1 < source.length &&
            (source[i + 1] == "'" || source[i + 1] == '"'))) {
      out.add(_Token(readString(), offset, literal: true));
    } else if (_letter(source[i])) {
      i++;
      while (i < source.length && _word(source[i])) {
        i++;
      }
      out.add(_Token(source.substring(offset, i), offset));
    } else {
      out.add(_Token(source[i++], offset));
    }
  }
  return out;
}

const _displayCalls = {'Text', 'SelectableText'};
const _displayParameters = {
  'text',
  'label',
  'labelText',
  'hintText',
  'helperText',
  'errorText',
  'tooltip',
  'semanticLabel',
  'semanticsLabel',
  'message',
  'title',
  'body',
  'channelName',
  'channelDescription',
};

// Product names (including the short tab label and uppercase wordmark) and
// ISO language codes are intentionally language-neutral. No files or arbitrary
// sentences are exempted from display scanning.
const _languageNeutralLabels = {'PomoSprint', 'POMOSPRINT', 'Pomo', 'TR', 'EN'};

// Turkish consent sentences place the verb after the linked legal document
// names. These three fragments alone are empty; the composed labels are not.
// Locale+key scope is deliberate: English prefixes and all complete messages
// still must be non-empty.
const _emptyGrammarFragments = {
  'tr/termsAgreePrefix',
  'tr/registerConsentTermsPrefix',
  'tr/registerConsentPrivacyPrefix',
};

List<String> _displayViolations(String source) {
  final tokens = _tokens(source);
  final calls = <String>[];
  final failures = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (!token.literal && token.value == '(') {
      calls.add(i > 0 ? tokens[i - 1].value : '');
    } else if (!token.literal && token.value == ')') {
      if (calls.isNotEmpty) calls.removeLast();
    } else if (token.literal) {
      final directDisplay =
          calls.isNotEmpty && _displayCalls.contains(calls.last);
      final displayParameter =
          i > 1 &&
          tokens[i - 1].value == ':' &&
          _displayParameters.contains(tokens[i - 2].value);
      if (!directDisplay && !displayParameter) continue;
      // A field key or comparison operand inside a Text expression is data,
      // not displayed prose: Text(row['name']) / Text(scope == 'global' ? ...).
      // This is structural, not an allowlist of field names or status strings.
      final mapKey =
          i > 0 &&
          i + 1 < tokens.length &&
          tokens[i - 1].value == '[' &&
          tokens[i + 1].value == ']';
      final comparisonOperand =
          i > 1 &&
          tokens[i - 1].value == '=' &&
          {'=', '!'}.contains(tokens[i - 2].value);
      final comparisonLeftOperand =
          i + 2 < tokens.length &&
          {'=', '!'}.contains(tokens[i + 1].value) &&
          tokens[i + 2].value == '=';
      if (mapKey || comparisonOperand || comparisonLeftOperand) continue;
      final value = token.value.trim();
      if (_languageNeutralLabels.contains(value)) continue;
      // Numerals, punctuation, emoji, password bullets and interpolation-only
      // text are formatting/user data, not translatable prose.
      if (!RegExp(r'[A-Za-z\u00C0-\u024F]').hasMatch(value)) continue;
      final line =
          '\n'.allMatches(source.substring(0, token.offset)).length + 1;
      failures.add('$line: $value');
    }
  }
  return failures;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TR/EN ARB key sets, non-empty values and placeholders match', () {
    final tr = _arb('tr');
    final en = _arb('en');
    expect(_keys(en), _keys(tr));
    for (final key in _keys(tr)) {
      expect(tr[key], isA<String>(), reason: 'tr/$key');
      expect(en[key], isA<String>(), reason: 'en/$key');
      for (final locale in ['tr', 'en']) {
        final value = (locale == 'tr' ? tr[key] : en[key]) as String;
        if (_emptyGrammarFragments.contains('$locale/$key')) {
          expect(value, isEmpty, reason: 'Only a documented grammar fragment');
        } else {
          expect(value.trim(), isNotEmpty, reason: '$locale/$key');
        }
      }
      expect(
        _placeholders(en[key] as String),
        _placeholders(tr[key] as String),
        reason: key,
      );
    }
    for (final locale in ['tr', 'en']) {
      final values = _arb(locale);
      for (final parts in [
        [
          'termsAgreePrefix',
          'termsLinkTerms',
          'termsAgreeConnector',
          'termsLinkPrivacy',
          'termsAgreeSuffix',
        ],
        [
          'registerConsentTermsPrefix',
          'registerConsentTermsLink',
          'registerConsentTermsSuffix',
        ],
        [
          'registerConsentPrivacyPrefix',
          'registerConsentKvkkLink',
          'registerConsentPrivacyConnector',
          'registerConsentPrivacyLink',
          'registerConsentPrivacySuffix',
        ],
      ]) {
        final completeLabel = parts.map((key) => values[key] as String).join();
        expect(completeLabel.trim(), isNotEmpty);
        expect(completeLabel, contains(locale == 'tr' ? 'okudum' : 'I '));
      }
    }
  });

  test(
    'server catalog fallbacks have paired names and preserve custom names',
    () {
      for (final avatar in AvatarCharacter.fallbackCatalog) {
        expect(avatar.nameTr.trim(), isNotEmpty, reason: '${avatar.id}/tr');
        expect(avatar.nameEn.trim(), isNotEmpty, reason: '${avatar.id}/en');
        expect(avatar.getName(true).trim(), isNotEmpty);
        expect(avatar.getName(false).trim(), isNotEmpty);
      }
      for (final pair in kKnownCategoryNames) {
        expect(pair.$1.trim(), isNotEmpty);
        expect(pair.$2.trim(), isNotEmpty);
        expect(localizedKnownCategoryName(pair.$1, turkish: false), pair.$2);
        expect(localizedKnownCategoryName(pair.$2, turkish: true), pair.$1);
      }
      const custom = 'My own category';
      expect(localizedKnownCategoryName(custom, turkish: true), custom);
      expect(localizedKnownCategoryName(custom, turkish: false), custom);
    },
  );

  test('legacy translation calls resolve to ARB in both languages', () async {
    final source = File(
      'lib/services/language_service.dart',
    ).readAsStringSync();
    final mapping = {
      for (final match in RegExp(
        r"'([a-z_0-9]+)'\s*=>\s*l10n\.([a-zA-Z0-9]+)",
      ).allMatches(source))
        match.group(1)!: match.group(2)!,
    };
    final used = <String>{};
    final calls = RegExp(r'''\.translate\(\s*['"]([^'"]+)['"]\s*\)''');
    for (final file in _sources()) {
      used.addAll(
        calls.allMatches(file.readAsStringSync()).map((m) => m.group(1)!),
      );
    }
    expect(
      mapping.keys.toSet().containsAll(used),
      isTrue,
      reason: 'Every remaining legacy call needs an explicit ARB mapping',
    );
    expect(source, isNot(contains('Map<AppLanguage, String>')));
    expect(source, isNot(contains('translateTableName')));
    final oldDevice = LanguageService.deviceLocale;
    addTearDown(() async {
      LanguageService.deviceLocale = oldDevice;
      SharedPreferences.setMockInitialValues({});
      await LanguageService.instance.init();
    });
    for (final locale in ['tr', 'en']) {
      final values = _arb(locale);
      SharedPreferences.setMockInitialValues({});
      LanguageService.deviceLocale = () => Locale(locale);
      await LanguageService.instance.init();
      for (final key in used) {
        expect(
          LanguageService.instance.translate(key),
          values[mapping[key]],
          reason: '$locale/$key',
        );
      }
    }
    expect(
      () => LanguageService.instance.translate('not_a_real_ui_key'),
      throwsArgumentError,
    );
  });

  test(
    'display-literal guard recognises prose without flagging technical data',
    () {
      expect(_displayViolations("Text('Not translated');"), isNotEmpty);
      expect(
        _displayViolations("Text(isTurkish ? 'Merhaba' : 'Hello');"),
        hasLength(2),
      );
      expect(
        _displayViolations("TextSpan(text: r'Not translated');"),
        isNotEmpty,
      );
      expect(
        _displayViolations(
          '''InputDecoration(hintText: "Missing translation");''',
        ),
        isNotEmpty,
      );
      expect(
        _displayViolations(
          "// Text('comment')\nText(l10n.title); /* nested /* Text('no') */ */",
        ),
        isEmpty,
      );
      expect(
        _displayViolations(
          "Text('TR'); Text('EN'); Text('PomoSprint'); Text('25:00'); Text('••••••••');",
        ),
        isEmpty,
      );
      expect(
        _displayViolations(r"Text('${l10n.name}: ${rows[0]['rank']}');"),
        isEmpty,
      );
      expect(
        _displayViolations(
          "rpc('private_method'); final route = 'settings'; final color = '#ff0000';",
        ),
        isEmpty,
      );
      expect(_displayViolations("Text(row['arbitrary_field']);"), isEmpty);
      expect(
        _displayViolations(
          "Text(scope == 'new_technical_id' ? l10n.one : l10n.two);",
        ),
        isEmpty,
      );
      expect(
        _displayViolations(
          "Text('new_technical_id' == scope ? l10n.one : l10n.two);",
        ),
        isEmpty,
      );
      expect(_displayViolations("Text('name');"), isNotEmpty);
      expect(_displayViolations("Text('global');"), isNotEmpty);
      expect(
        _displayViolations(r"Text('Untranslated ${row['name']}');"),
        isNotEmpty,
      );

      expect(_displayViolations("Text('''Multiple\nlines''');"), isNotEmpty);
    },
  );

  test('authored UI display sinks contain no untranslated prose', () {
    final violations = <String>[];
    for (final file in _sources()) {
      violations.addAll(
        _displayViolations(
          file.readAsStringSync(),
        ).map((v) => '${file.path}:$v'),
      );
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

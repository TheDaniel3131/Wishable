// Feature: wishable, Property 2: Title validation rejects blank titles and preserves state
//
// Property-based test for Wish title validation (task 5.2).
//
// Validates: Requirements 1.2, 2.2
//
// For any string that is empty or consists solely of whitespace, submitting it
// as a title on create ([WishValidator.validateDraft]) or edit
// ([WishValidator.validateEdit]) is rejected with a [TitleRequiredError], and
// no validated draft/edit value is produced (so the caller persists nothing on
// create and leaves the stored Wish unchanged on edit). Conversely, for any
// string that contains at least one non-whitespace character, validation
// succeeds and the returned title is the input with surrounding whitespace
// trimmed.
//
// Each property runs a minimum of 100 generated cases (glados default is 100).
import 'package:glados/glados.dart';
import 'package:wishable/domain/priority.dart';
import 'package:wishable/domain/wish_input.dart';
import 'package:wishable/domain/wish_validator.dart';

/// Whitespace code points used to assemble whitespace-only (blank) titles.
///
/// Includes ASCII space/tab/newlines plus a couple of Unicode whitespace
/// characters, all of which `String.trim()` strips, so a string built solely
/// from these must be rejected as blank (R1.2, R2.2).
const List<String> _whitespaceChars = <String>[
  ' ', // space
  '\t', // tab
  '\n', // line feed
  '\r', // carriage return
  '\u000B', // vertical tab
  '\u000C', // form feed
  '\u00A0', // no-break space
  '\u2003', // em space
  '\u3000', // ideographic space
];

/// Generates a possibly-empty whitespace-only string from [_whitespaceChars].
///
/// Used both as the blank-title generator and as the surrounding padding for
/// non-blank titles (so the trimming behavior is exercised).
Generator<String> get _whitespace => any
    .listWithLengthInRange(0, 12, any.choose(_whitespaceChars))
    .map((List<String> parts) => parts.join());

/// Generates blank titles: the empty string and whitespace-only strings of
/// varying length.
Generator<String> get _blankTitles => _whitespace;

/// Generates non-blank titles: strings guaranteed to contain at least one
/// non-whitespace character. Whitespace padding (possibly empty) is placed on
/// either side of a required non-whitespace core so trimming is exercised.
Generator<String> get _nonBlankTitles => any.combine3(
      // Leading whitespace padding (may be empty).
      _whitespace,
      // A core that is guaranteed non-empty and contains no whitespace.
      any.nonEmptyLetters,
      // Trailing whitespace padding (may be empty).
      _whitespace,
      (String lead, String core, String trail) => '$lead$core$trail',
    );

void main() {
  const WishValidator validator = WishValidator();

  // A fixed, valid category id so drafts/edits differ only by title.
  const String categoryId = 'cat-fixed-id';

  WishDraft draftWithTitle(String title) =>
      WishDraft(title: title, categoryId: categoryId, priority: Priority.high);

  WishEdit editWithTitle(String title) => WishEdit(
        title: title,
        categoryId: categoryId,
        priority: Priority.high,
      );

  group('blank titles are rejected and no validated value is produced', () {
    Glados<String>(_blankTitles).test(
        'validateTitle rejects blank with TitleRequiredError', (String title) {
      final ValidationResult<String> result = validator.validateTitle(title);
      expect(result.isValid, isFalse);
      expect(result.value, isNull);
      expect(result.errors, equals(const [TitleRequiredError()]));
    });

    Glados<String>(_blankTitles)
        .test('validateDraft (create) rejects blank, persists nothing',
            (String title) {
      final ValidationResult<WishDraft> result =
          validator.validateDraft(draftWithTitle(title));
      expect(result.isValid, isFalse);
      // No validated draft => the caller has nothing to persist (R1.2).
      expect(result.value, isNull);
      expect(result.errors, equals(const [TitleRequiredError()]));
    });

    Glados<String>(_blankTitles)
        .test('validateEdit rejects blank, leaving stored Wish unchanged',
            (String title) {
      final ValidationResult<WishEdit> result =
          validator.validateEdit(editWithTitle(title));
      expect(result.isValid, isFalse);
      // No validated edit => the caller leaves the stored Wish untouched (R2.2).
      expect(result.value, isNull);
      expect(result.errors, equals(const [TitleRequiredError()]));
    });
  });

  group('non-blank titles validate and are trimmed', () {
    Glados<String>(_nonBlankTitles).test('validateTitle accepts and trims',
        (String title) {
      final ValidationResult<String> result = validator.validateTitle(title);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.value, equals(title.trim()));
      expect(result.value!.trim(), equals(result.value));
    });

    Glados<String>(_nonBlankTitles)
        .test('validateDraft accepts and trims the title', (String title) {
      final ValidationResult<WishDraft> result =
          validator.validateDraft(draftWithTitle(title));
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.value, isNotNull);
      expect(result.value!.title, equals(title.trim()));
    });

    Glados<String>(_nonBlankTitles)
        .test('validateEdit accepts and trims the title', (String title) {
      final ValidationResult<WishEdit> result =
          validator.validateEdit(editWithTitle(title));
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.value, isNotNull);
      expect(result.value!.title, equals(title.trim()));
    });
  });
}

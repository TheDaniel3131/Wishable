// Feature: wishable, Property 3: Default priority is Medium
//
// Property-based test for task 5.3.
//
// Validates: Requirements 1.4 — "WHERE the User does not select a Priority
// during creation, THE Wish_Manager SHALL assign the Priority value `Medium`."
//
// Two complementary properties over randomly generated [WishDraft]s with valid
// (non-whitespace) titles and arbitrary category ids:
//
//   1. A draft that omits a priority (priority == null) is resolved by
//      [WishValidator.validateDraft] to [Priority.medium].
//   2. A draft that specifies a priority keeps exactly that priority.
//
// Each property runs over at least 100 generated cases (glados' default
// ExploreConfig.numRuns is 100).
import 'package:glados/glados.dart';
import 'package:wishable/domain/priority.dart';
import 'package:wishable/domain/wish_input.dart';
import 'package:wishable/domain/wish_validator.dart';

/// Generates strings that are valid Wish titles: they contain at least one
/// non-whitespace character so they pass [WishValidator.isTitleValid]. The raw
/// generated text may be empty, so a guaranteed non-whitespace character is
/// prepended.
Generator<String> validTitles() => any.letterOrDigits.map((String s) => 'w$s');

/// Generates arbitrary non-empty category ids (opaque strings the validator
/// does not interpret).
Generator<String> categoryIds() =>
    any.letterOrDigits.map((String s) => 'cat-$s');

/// Generates optional descriptions: sometimes null, sometimes an arbitrary
/// string, to exercise the full draft shape.
Generator<String?> optionalDescriptions() => any.either<String?>(
      any.always<String?>(null),
      any.letterOrDigits.map<String?>((String s) => s),
    );

/// Generates any member of the closed [Priority] set.
Generator<Priority> priorities() => any.choose<Priority>(Priority.values);

void main() {
  const WishValidator validator = WishValidator();

  group('Property 3: Default priority is Medium', () {
    // A draft that OMITS priority resolves to the default, Priority.medium.
    Glados3<String, String?, String>(
      validTitles(),
      optionalDescriptions(),
      categoryIds(),
    ).test(
      'omitted priority resolves to Priority.medium',
      (String title, String? description, String categoryId) {
        final WishDraft draft = WishDraft(
          title: title,
          description: description,
          categoryId: categoryId,
          // priority intentionally omitted (null).
        );

        final ValidationResult<WishDraft> result =
            validator.validateDraft(draft);

        expect(result.isValid, isTrue,
            reason:
                'A draft with a valid title and no priority must validate.');
        expect(result.value!.priority, Priority.medium,
            reason:
                'Omitting priority must default to Priority.medium (R1.4).');
        // The default must equal the documented constant.
        expect(result.value!.priority, kDefaultPriority);
      },
    );

    // A draft that SPECIFIES a priority keeps exactly that priority.
    Glados3<String, String, Priority>(
      validTitles(),
      categoryIds(),
      priorities(),
    ).test(
      'specified priority is preserved',
      (String title, String categoryId, Priority priority) {
        final WishDraft draft = WishDraft(
          title: title,
          categoryId: categoryId,
          priority: priority,
        );

        final ValidationResult<WishDraft> result =
            validator.validateDraft(draft);

        expect(result.isValid, isTrue);
        expect(result.value!.priority, priority,
            reason: 'A supplied priority must be retained unchanged.');
      },
    );
  });
}

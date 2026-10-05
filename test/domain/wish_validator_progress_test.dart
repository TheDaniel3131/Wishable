// Feature: wishable, Property 8: Progress bounds are enforced
//
// Property-based test for task 5.4.
//
// Property 8: Progress bounds are enforced.
//   _For any_ integer p, applying p as a Progress_Value persists it when
//   0 <= p <= 100 and rejects it while retaining the previously stored
//   Progress_Value when p < 0 or p > 100.
//
// Validates: Requirements 5.1, 5.2
//
// This test exercises the pure domain validator in
// lib/domain/wish_validator.dart via [WishValidator.validateProgress] and
// [WishValidator.isProgressInRange]. It generates random integers across the
// whole int space as well as values targeted at each partition (below 0, in
// range [0, 100], and above 100) so both acceptance and rejection paths are
// covered with well over 100 generated cases.
import 'package:glados/glados.dart';
import 'package:wishable/domain/wish_validator.dart';

void main() {
  const WishValidator validator = WishValidator();

  // "Previously stored" progress value used to assert that a rejected value
  // leaves prior state untouched (R5.2 "retain the previously stored
  // Progress_Value"). The validator is pure, so retention is modeled as: on
  // rejection the caller keeps [previous] because the result yields no value.
  const int previous = 42;

  group('Property 8: progress bounds are enforced', () {
    // General property over arbitrary integers: the two code paths must agree
    // and behave according to the [0, 100] rule. `any.int` ranges across a
    // broad span of positive and negative integers, so a single run covers
    // in-range and both out-of-range partitions. Default glados runs 100
    // examples, satisfying the minimum-100-cases requirement.
    Glados<int>(any.int).test(
      'validateProgress agrees with the [0, 100] rule for any integer',
      (int p) {
        final bool inRange = p >= 0 && p <= 100;
        final ValidationResult<int> result = validator.validateProgress(p);

        // isProgressInRange is the single source of truth for the bound.
        expect(validator.isProgressInRange(p), equals(inRange));
        expect(result.isValid, equals(inRange));

        if (inRange) {
          // R5.1: an in-range value validates and is carried through to be
          // persisted unchanged.
          expect(result.value, equals(p));
          expect(result.errors, isEmpty);
        } else {
          // R5.2: an out-of-range value is rejected with the specific error
          // and yields no value, so the caller retains the previously stored
          // Progress_Value.
          expect(result.value, isNull);
          expect(result.errors, equals(<ValidationError>[
            ProgressOutOfRangeError(p),
          ]));

          // Model "retain the previously stored value": with no validated
          // value to persist, the stored progress stays at [previous].
          final int stored =
              result.isValid ? (result.value as int) : previous;
          expect(stored, equals(previous));
        }
      },
    );

    // Targeted partition: in-range values [0, 100] must always persist (R5.1).
    Glados<int>(any.intInRange(0, 101)).test(
      'in-range values [0, 100] validate and persist',
      (int p) {
        expect(validator.isProgressInRange(p), isTrue);
        final ValidationResult<int> result = validator.validateProgress(p);
        expect(result.isValid, isTrue);
        expect(result.value, equals(p));
        expect(result.errors, isEmpty);
      },
    );

    // Targeted partition: values below 0 must always be rejected (R5.2).
    Glados<int>(any.intInRange(-100000, 0)).test(
      'values below 0 are rejected with ProgressOutOfRangeError',
      (int p) {
        expect(p < 0, isTrue);
        expect(validator.isProgressInRange(p), isFalse);
        final ValidationResult<int> result = validator.validateProgress(p);
        expect(result.isValid, isFalse);
        expect(result.value, isNull);
        expect(result.errors, equals(<ValidationError>[
          ProgressOutOfRangeError(p),
        ]));
      },
    );

    // Targeted partition: values above 100 must always be rejected (R5.2).
    Glados<int>(any.intInRange(101, 100001)).test(
      'values above 100 are rejected with ProgressOutOfRangeError',
      (int p) {
        expect(p > 100, isTrue);
        expect(validator.isProgressInRange(p), isFalse);
        final ValidationResult<int> result = validator.validateProgress(p);
        expect(result.isValid, isFalse);
        expect(result.value, isNull);
        expect(result.errors, equals(<ValidationError>[
          ProgressOutOfRangeError(p),
        ]));
      },
    );

    // Boundary examples: the inclusive edges 0 and 100 are valid; -1 and 101
    // are not. These anchor the property with the exact boundary cases.
    test('inclusive boundaries 0 and 100 validate; -1 and 101 are rejected',
        () {
      expect(validator.validateProgress(0).isValid, isTrue);
      expect(validator.validateProgress(100).isValid, isTrue);
      expect(validator.validateProgress(0).value, equals(0));
      expect(validator.validateProgress(100).value, equals(100));

      expect(validator.validateProgress(-1).isValid, isFalse);
      expect(validator.validateProgress(101).isValid, isFalse);
      expect(
        validator.validateProgress(-1).errors,
        equals(<ValidationError>[const ProgressOutOfRangeError(-1)]),
      );
      expect(
        validator.validateProgress(101).errors,
        equals(<ValidationError>[const ProgressOutOfRangeError(101)]),
      );
    });
  });
}

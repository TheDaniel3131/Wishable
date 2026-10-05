// Feature: auth, Property 2: Lockout backoff is non-decreasing past the threshold
//
// Property-based test for auth task 3.2.
//
// Property 2: For consecutive-failure counts at or beyond the threshold, the
// required cooldown is non-decreasing as failures increase, and never exceeds
// the configured maximum. A successful unlock (modeled as resetting the
// failure state) returns the policy to the "allowed" decision.
// Validates: Requirements 4.1 (backoff after threshold), 4.3 (reset on
// success).

import 'package:glados/glados.dart';
import 'package:wishable/domain/auth/auth_credentials.dart';
import 'package:wishable/domain/auth/lockout_policy.dart';

const LockoutPolicy _policy = LockoutPolicy(
  threshold: 5,
  baseCooldown: Duration(seconds: 30),
  maxCooldown: Duration(minutes: 15),
);

void main() {
  // Monotonicity: cooldownFor is non-decreasing and capped.
  Glados2<int, int>(any.intInRange(0, 40), any.intInRange(0, 40)).test(
    'cooldownFor is non-decreasing in failures and capped at maxCooldown',
    (int a, int b) {
      final int lo = a <= b ? a : b;
      final int hi = a <= b ? b : a;
      final Duration cLo = _policy.cooldownFor(lo);
      final Duration cHi = _policy.cooldownFor(hi);
      expect(cHi >= cLo, isTrue,
          reason: 'cooldown must not decrease as failures rise ($lo -> $hi)');
      expect(cHi <= _policy.maxCooldown, isTrue,
          reason: 'cooldown must be capped at maxCooldown');
    },
  );

  test('below threshold is always allowed, regardless of time', () {
    final DateTime now = DateTime.utc(2026, 1, 1, 12);
    for (int failures = 0; failures < _policy.threshold; failures++) {
      final AuthFailureState state = AuthFailureState(
        consecutiveFailures: failures,
        lastFailureUtc: now,
      );
      expect(_policy.evaluate(state, now), isA<LockoutAllowed>());
    }
  });

  test('at threshold, a fresh failure cools down then allows after the wait',
      () {
    final DateTime failedAt = DateTime.utc(2026, 1, 1, 12);
    final AuthFailureState state = AuthFailureState(
      consecutiveFailures: _policy.threshold,
      lastFailureUtc: failedAt,
    );

    // Immediately after the failure: cooling down.
    final LockoutDecision during = _policy.evaluate(state, failedAt);
    expect(during, isA<LockoutCoolingDown>());

    // After the cooldown elapses: allowed again.
    final Duration cd = _policy.cooldownFor(_policy.threshold);
    final DateTime after = failedAt.add(cd).add(const Duration(seconds: 1));
    expect(_policy.evaluate(state, after), isA<LockoutAllowed>());
  });

  test('reset (success) returns to allowed', () {
    final DateTime now = DateTime.utc(2026, 1, 1, 12);
    // A reset failure state is AuthFailureState.none.
    expect(_policy.evaluate(AuthFailureState.none, now), isA<LockoutAllowed>());
  });

  test('recordFailure increments and stamps the time', () {
    final DateTime now = DateTime.utc(2026, 1, 1, 12);
    final AuthFailureState s = AuthFailureState.none.recordFailure(now);
    expect(s.consecutiveFailures, 1);
    expect(s.lastFailureUtc, now);
  });
}

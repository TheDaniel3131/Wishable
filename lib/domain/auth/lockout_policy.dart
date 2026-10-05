/// Brute-force lockout policy (auth spec, Option A — R4).
///
/// Pure, deterministic function of the current failure state and an injected
/// clock. After [threshold] consecutive failures, each further failure imposes
/// a cooldown that grows with the number of failures (backoff), capped at
/// [maxCooldown]. A successful unlock resets the state (handled by the caller).
library wishable.domain.auth.lockout_policy;

import 'auth_credentials.dart';

/// The outcome of consulting the lockout policy before an unlock attempt.
sealed class LockoutDecision {
  const LockoutDecision();
}

/// An unlock attempt is permitted now.
final class LockoutAllowed extends LockoutDecision {
  const LockoutAllowed();
}

/// An unlock attempt is refused until [until]; [remaining] is relative to the
/// clock passed to [LockoutPolicy.evaluate].
final class LockoutCoolingDown extends LockoutDecision {
  const LockoutCoolingDown({required this.until, required this.remaining});

  final DateTime until;
  final Duration remaining;
}

/// Computes lockout decisions from a [AuthFailureState] and a clock.
final class LockoutPolicy {
  const LockoutPolicy({
    this.threshold = 5,
    this.baseCooldown = const Duration(seconds: 30),
    this.maxCooldown = const Duration(minutes: 15),
  });

  /// Consecutive failures allowed before a cooldown applies (R4.1).
  final int threshold;

  /// Cooldown applied at the first over-threshold failure; doubles per extra
  /// failure up to [maxCooldown] (backoff, R4.1).
  final Duration baseCooldown;

  /// Upper bound on the cooldown.
  final Duration maxCooldown;

  /// Decides whether an unlock may be attempted at [nowUtc] given [state].
  ///
  /// Below [threshold] failures: always allowed. At or above it: the attempt
  /// is refused until `lastFailure + cooldown(failures)`, where the cooldown
  /// grows by powers of two with each failure past the threshold and is capped
  /// at [maxCooldown] (R4.1, R4.2).
  LockoutDecision evaluate(AuthFailureState state, DateTime nowUtc) {
    if (state.consecutiveFailures < threshold || state.lastFailureUtc == null) {
      return const LockoutAllowed();
    }
    final Duration cooldown = cooldownFor(state.consecutiveFailures);
    final DateTime until = state.lastFailureUtc!.add(cooldown);
    if (!nowUtc.isBefore(until)) {
      return const LockoutAllowed();
    }
    return LockoutCoolingDown(until: until, remaining: until.difference(nowUtc));
  }

  /// The cooldown duration imposed for [failures] consecutive failures. Returns
  /// [Duration.zero] below [threshold]. Non-decreasing in [failures] (R4.1).
  Duration cooldownFor(int failures) {
    if (failures < threshold) {
      return Duration.zero;
    }
    final int over = failures - threshold; // 0 at the threshold failure.
    // Doubling backoff: base * 2^over, capped. Guard the shift against overflow.
    final int factor = over >= 30 ? (1 << 30) : (1 << over);
    final int millis = baseCooldown.inMilliseconds * factor;
    final Duration scaled = Duration(milliseconds: millis);
    return scaled > maxCooldown ? maxCooldown : scaled;
  }
}

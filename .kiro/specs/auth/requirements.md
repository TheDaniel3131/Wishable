# Requirements Document

Feature: Authentication / App Lock

## Introduction

Wishable is a **local-first** app with no backend, no account, and no network dependency (wishable spec R10.2, R10.3; enforced by the offline/no-backend architecture test). A conventional "login" against a server would contradict that core design.

This feature adds authentication in **two layers**, both in scope (product-owner decision: build both):

- **Option A — local app lock**: the app can require a passcode (PIN or password) and, where available, device biometrics (fingerprint / face) before a user can view or modify their Wishes. It protects on-device data from casual access, with no account, server, or network call. Requirements 1–9 cover Option A.
- **Option B — remote accounts + sync**: an optional account (email/password and/or OAuth) against a backend, enabling the user to sign in and sync their Wishes across devices. Requirements 10–14 cover Option B.

### Revised core invariant: offline-first, not no-backend

Adding Option B changes Wishable's original "no backend, ever" stance. The new invariant is **offline-first with optional sync**:

- The app MUST remain fully usable offline with no account — all existing local behavior is preserved, and a user who never signs in never touches the network.
- Remote accounts and sync are an **optional, isolated layer** that is inert unless the user signs in. The original "no server dependency compiled in" architecture test is **replaced** by an offline-first test (see Requirement 14): the local app graph must not depend on the remote layer, and the app must build and run with the remote layer disabled/unconfigured.

### Build order

Option A is self-contained and is built first. Option B layers on top, reusing the same `AuthController` surface, and requires a backend choice (Supabase / Firebase / custom) and an auth-method choice (email-password / OAuth / both) from the product owner before its network code is written.

## Glossary

- **App lock**: the gate shown before the main app content when authentication is enabled.
- **Passcode**: a user-chosen secret — a numeric PIN or an alphanumeric password — used to unlock the app.
- **Biometric unlock**: unlocking via the platform's biometric API (Touch ID / Face ID / Android biometric / Windows Hello) where hardware and OS support it.
- **Locked / Unlocked**: the two states of the app-lock gate within a running session.
- **Enrolled**: the state where the user has set a passcode and the app lock is enabled.

## Requirements

### Requirement 1: Enable and configure the app lock

**User Story:** As a user, I want to turn on an app lock with a passcode, so that my Wishes are protected if someone else opens the app.

#### Acceptance Criteria

1. WHEN the app lock is disabled THEN the system SHALL start directly in the unlocked state with full access, preserving today's behavior for users who never enroll.
2. WHEN a user enables the app lock THEN the system SHALL require the user to set a passcode and confirm it by re-entry before enabling.
3. WHEN the two passcode entries do not match THEN the system SHALL reject enrollment with a descriptive message and SHALL NOT enable the lock.
4. WHEN a passcode does not meet the minimum policy (PIN at least 4 digits, or password at least 6 characters) THEN the system SHALL reject it with a descriptive message.
5. WHEN enrollment succeeds THEN the system SHALL store only a non-reversible verifier for the passcode (a salted hash from a slow KDF), never the passcode itself.

### Requirement 2: Unlock with passcode

**User Story:** As an enrolled user, I want to enter my passcode to unlock the app, so that only I can see my Wishes.

#### Acceptance Criteria

1. WHEN the app launches AND the app lock is enabled THEN the system SHALL present the lock screen and SHALL NOT render Wish data until the user authenticates.
2. WHEN the user enters the correct passcode THEN the system SHALL transition to the unlocked state and reveal the app.
3. WHEN the user enters an incorrect passcode THEN the system SHALL remain locked, increment a failed-attempt counter, and show a non-revealing error (it SHALL NOT disclose the correct passcode or how close the entry was).
4. WHEN comparing an entered passcode to the stored verifier THEN the system SHALL use a constant-time comparison.

### Requirement 3: Biometric unlock

**User Story:** As an enrolled user on a device with biometrics, I want to unlock with my fingerprint or face, so that unlocking is fast.

#### Acceptance Criteria

1. WHEN the device and OS support biometrics AND the user has enabled biometric unlock THEN the lock screen SHALL offer a biometric prompt.
2. WHEN biometric authentication succeeds THEN the system SHALL transition to the unlocked state.
3. WHEN biometric authentication fails, is cancelled, or is unavailable THEN the system SHALL fall back to passcode entry and SHALL NOT bypass the gate.
4. WHERE the platform does not support biometrics (e.g. web without a platform authenticator) THEN the biometric option SHALL be hidden and passcode unlock SHALL remain available.

### Requirement 4: Lockout / brute-force resistance

**User Story:** As a user, I want repeated wrong guesses to be slowed down, so that someone cannot rapidly try every passcode.

#### Acceptance Criteria

1. WHEN the number of consecutive failed attempts reaches a threshold (e.g. 5) THEN the system SHALL impose a cooldown before accepting further attempts, with the delay increasing on continued failures (backoff).
2. WHILE a cooldown is active THEN the system SHALL reject unlock attempts and display the remaining wait time.
3. WHEN a successful unlock occurs THEN the system SHALL reset the failed-attempt counter and any cooldown.

### Requirement 5: Change and disable the passcode

**User Story:** As an enrolled user, I want to change or remove my passcode, so that I stay in control of the lock.

#### Acceptance Criteria

1. WHEN a user changes the passcode THEN the system SHALL first require the current passcode (or a successful biometric unlock), then require and confirm the new passcode subject to the same policy as enrollment.
2. WHEN a user disables the app lock THEN the system SHALL require successful authentication first, then remove the stored verifier and all lock settings, returning the app to the always-unlocked state.
3. IF the user cancels a change/disable flow THEN the system SHALL leave the existing lock configuration unchanged.

### Requirement 6: Auto-lock on background / timeout

**User Story:** As a user, I want the app to re-lock when I leave it, so that it is not left open on an unattended device.

#### Acceptance Criteria

1. WHEN the app is sent to the background (or the window loses focus on desktop/web) for longer than a configurable timeout (default: immediately or a short grace period) THEN the system SHALL return to the locked state on next foreground.
2. WHEN the app lock is enabled AND the app is relaunched from a cold start THEN the system SHALL start locked.
3. WHERE a timeout value is configurable THEN the system SHALL persist the chosen value across launches.

### Requirement 7: Secure storage of secrets

**User Story:** As a user, I want my passcode material protected on the device, so that it cannot be read out of app storage.

#### Acceptance Criteria

1. WHEN storing the passcode verifier, its salt, and the biometric-enabled flag THEN the system SHALL use the platform secure store (Keychain / Keystore / equivalent) where available, and SHALL NOT store these in plaintext in the Drift database or in shared preferences.
2. WHERE a platform has no secure store (e.g. some web contexts) THEN the system SHALL still store only the non-reversible verifier (never the passcode) and SHALL document the reduced protection.
3. WHEN any authentication error is surfaced THEN the system SHALL NOT include secret material, the stored hash, or the salt in the message or in logs.

### Requirement 8: Local-first invariant preserved

**User Story:** As a user, I want the lock to work entirely offline, so that the app keeps its local-first promise.

#### Acceptance Criteria

1. WHEN authenticating, enrolling, changing, or disabling the lock THEN the system SHALL perform no network request and SHALL depend on no server or account.
2. WHEN this feature is compiled THEN the offline/no-backend architecture test (wishable R10.2, R10.3, R14.4) SHALL still pass — no account/server/hosted-auth dependency is introduced.
3. WHEN the app lock is disabled THEN all existing offline behavior SHALL be unchanged.

### Requirement 9: Data protection relationship (optional sub-feature)

**User Story:** As a privacy-conscious user, I want the option to encrypt my local data behind the passcode, so that the lock protects data at rest, not just the UI.

#### Acceptance Criteria

1. WHERE database encryption is offered THEN enabling it SHALL derive the database key from the passcode (via the KDF) and SHALL require the passcode to open the database.
2. IF database encryption is NOT implemented in this iteration THEN the UI SHALL clearly state that the app lock protects access to the UI only, not data at rest, so users are not misled.
3. WHEN encryption is enabled AND the passcode is changed THEN the system SHALL re-key the database within a single all-or-nothing operation, leaving the database readable with the old key if re-keying fails.

## Non-functional requirements

- **Platforms**: behavior is consistent across all six targets; biometric and secure-store capabilities degrade gracefully where the platform lacks them (notably web).
- **Accessibility**: the lock screen's inputs and the biometric control are reachable, labelled, and usable with assistive technologies and large text scales.
- **Performance**: unlock verification completes quickly from the user's perspective despite the deliberately slow KDF (tune KDF cost to a sensible unlock latency).
- **Testability**: the auth state machine, policy, and KDF/verifier logic are pure/injectable so they can be unit- and property-tested without a real device.

## Option B — Remote accounts + sync

> These requirements are gated on two product-owner choices before their network code is implemented: the **backend** (Supabase / Firebase / custom) and the **auth method** (email-password / OAuth / both). The design and tasks define the backend-agnostic surface so the gated choice only affects one adapter.

### Requirement 10: Account sign-up and sign-in

**User Story:** As a user, I want to create an account and sign in, so that my Wishes can live beyond a single device.

#### Acceptance Criteria

1. WHEN the user chooses to sign up with the configured method (email+password and/or OAuth) THEN the system SHALL create an account via the backend and establish an authenticated session.
2. WHEN the user signs in with valid credentials THEN the system SHALL establish an authenticated session and expose the user's identity to the app.
3. WHEN sign-up/sign-in fails (bad credentials, network error, provider error) THEN the system SHALL surface a descriptive, non-sensitive error and remain signed out.
4. WHEN the app is offline THEN sign-in using an existing valid session SHALL still grant local access, and new network sign-in SHALL fail gracefully with a clear "you are offline" message.

### Requirement 11: Session management

**User Story:** As a signed-in user, I want my session to persist and refresh, so that I am not asked to re-authenticate constantly.

#### Acceptance Criteria

1. WHEN a session is established THEN the system SHALL persist its tokens in the platform secure store (never plaintext) and restore the session on relaunch.
2. WHEN an access token expires AND a refresh token is valid THEN the system SHALL refresh the session transparently.
3. WHEN the user signs out THEN the system SHALL revoke/clear the session locally and stop syncing; local Wishes remain on the device unless the user explicitly chooses to clear them.
4. WHEN a refresh fails irrecoverably THEN the system SHALL return to the signed-out state and inform the user.

### Requirement 12: Sync of Wishes across devices

**User Story:** As a signed-in user, I want my Wishes to sync across my devices, so that I see the same list everywhere.

#### Acceptance Criteria

1. WHEN signed in and online THEN the system SHALL push local changes to the backend and pull remote changes into the local Drift database, converging both to the same set.
2. WHEN the same Wish has been changed on two devices THEN the system SHALL resolve the conflict deterministically by last-write-wins on `updatedAtUtc` (the schema already records UTC update timestamps), and SHALL never silently lose a delete vs. edit without a defined rule.
3. WHEN offline THEN the system SHALL continue to work on the local database and SHALL queue changes to sync when connectivity returns.
4. WHEN a sync error occurs THEN the system SHALL leave the local database consistent, surface a non-blocking error, and retry later; a failed sync SHALL NOT corrupt local data.
5. WHEN a user signs out and back in THEN the system SHALL reconcile local and remote state without duplicating Wishes (identity is the stable Wish UUID).

### Requirement 13: Relationship between the app lock (A) and the account (B)

**User Story:** As a user, I want the local lock and my account to work together sensibly, so that the two features do not conflict.

#### Acceptance Criteria

1. WHEN both the app lock (A) is enabled AND an account (B) is signed in THEN the app lock SHALL gate local UI access and the account SHALL govern sync; the two SHALL be independent (unlocking locally does not sign in; signing in does not bypass the local lock).
2. WHEN the app lock is enabled THEN sync MAY run in the background, but Wish content SHALL NOT be rendered until the local lock is satisfied.
3. WHERE only one of the two is configured THEN the other SHALL be cleanly absent (no account prompts when only the lock is used, and vice versa).

### Requirement 14: Offline-first invariant (replaces the old no-backend test)

**User Story:** As a user, I want the app to keep working offline with no account, so that the remote layer is purely optional.

#### Acceptance Criteria

1. WHEN no account is configured/signed in THEN the app SHALL perform no network request for its core local behavior and SHALL function exactly as the local-only app does today.
2. WHEN the project is built THEN the offline-first architecture test SHALL pass: the local app graph (domain/data/application/presentation for Wishes and the local lock) SHALL NOT depend on the remote sync/account layer, and the app SHALL build and run with the remote layer unconfigured.
3. WHEN the remote layer is present but the user is signed out THEN it SHALL be inert — no background network activity.

## Out of scope (this feature)

- Account recovery flows beyond what the chosen backend provides out of the box (e.g. custom email templates); the backend's standard password-reset is used where available.
- Role-based access, team/shared lists, or multiple local user profiles on one install.
- End-to-end encryption of synced data (server sees Wish content under the chosen backend's model); can be a future enhancement.
- Real-time collaborative editing (sync is convergence, not live multi-cursor).

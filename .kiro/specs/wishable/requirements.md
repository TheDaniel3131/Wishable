# Requirements Document

## Introduction

Wishable is a cross-platform personal wishlist and achievement tracker. It lets a single user capture any aspiration — things to do, own, experience, or achieve — and move each one through a lifecycle from creation to fulfillment, with a celebration on completion.

Wishable V1 is local-first with no backend, no accounts, and no hosted database. Each installation stores its data in its own local SQLite database. The application targets web, Windows, macOS, Linux, Android, and iOS from a single shared Flutter/Dart codebase. V1 provides full offline functionality plus backup/export and restore/import so a user can move or safeguard data manually. The architecture must remain extensible for optional cloud synchronization in a future V2, but V2 behavior is out of scope for these requirements.

This document defines the functional and quality requirements for V1.

## Glossary

- **Wishable**: The complete cross-platform application described by this document.
- **Wish**: A user-created record representing an aspiration to do, own, experience, or achieve something. Each Wish has a title, optional description, category, priority, lifecycle status, and progress value.
- **Wish_Manager**: The subsystem of Wishable responsible for creating, reading, updating, deleting, and transitioning Wishes.
- **Lifecycle_Status**: The current stage of a Wish. One of: `Active`, `In_Progress`, `Completed`. (A Wish that is created is `Active` by default; "My Wishes" and "Active Wishes" are views, with `Active` as the initial status.)
- **Progress_Value**: An integer from 0 to 100 inclusive representing the percentage completion of a Wish.
- **Category**: A user-defined or preset grouping label applied to a Wish (for example: Learn, Travel, Buy, Save, Certify).
- **Priority**: A ranking applied to a Wish. One of: `Low`, `Medium`, `High`.
- **Celebration_View**: A visual acknowledgment shown when a Wish transitions to `Completed`, displaying a "Wish fulfilled" message.
- **Local_Database**: The per-installation SQLite database managed by Drift that stores all Wishes and settings.
- **Backup_Manager**: The subsystem responsible for exporting and importing Wishable data.
- **Database_Export**: A copy of the Local_Database file produced by the Backup_Manager for backup or transfer.
- **JSON_Export**: A JSON-formatted file containing all Wishes produced by the Backup_Manager.
- **CSV_Export**: A CSV-formatted file containing all Wishes produced by the Backup_Manager.
- **Import_File**: A Database_Export, JSON_Export, or CSV_Export file selected by the user for restore.
- **Settings_View**: The screen that exposes backup, restore, and application configuration options.
- **User**: The single person operating one installation of Wishable.
- **Round_Trip**: The operation of exporting Wishes and then importing the resulting file, used to verify data equivalence.

## Requirements

### Requirement 1: Create a Wish

**User Story:** As a User, I want to create a Wish with the details that matter to me, so that I can capture any aspiration I want to track.

#### Acceptance Criteria

1. WHEN the User submits a new Wish with a non-empty title, THE Wish_Manager SHALL persist the Wish to the Local_Database with Lifecycle_Status set to `Active` and Progress_Value set to 0.
2. IF the User submits a new Wish with an empty title, THEN THE Wish_Manager SHALL reject the submission and display a message stating that a title is required.
3. WHEN the User creates a Wish, THE Wish_Manager SHALL allow the User to set an optional description, a Category, and a Priority.
4. WHERE the User does not select a Priority during creation, THE Wish_Manager SHALL assign the Priority value `Medium`.
5. WHEN a Wish is persisted, THE Wish_Manager SHALL record the creation timestamp of the Wish.

### Requirement 2: Edit a Wish

**User Story:** As a User, I want to edit an existing Wish, so that I can keep its details accurate as my plans change.

#### Acceptance Criteria

1. WHEN the User saves edits to an existing Wish with a non-empty title, THE Wish_Manager SHALL update the stored Wish in the Local_Database with the new values.
2. IF the User saves edits that set the title to an empty value, THEN THE Wish_Manager SHALL reject the edit and display a message stating that a title is required.
3. WHEN the User updates the description, Category, or Priority of a Wish, THE Wish_Manager SHALL persist each changed value to the Local_Database.
4. WHEN a Wish is updated, THE Wish_Manager SHALL record the last-modified timestamp of the Wish.

### Requirement 3: Categorize Wishes

**User Story:** As a User, I want to assign and manage categories, so that I can group related Wishes.

#### Acceptance Criteria

1. WHEN the User assigns a Category to a Wish, THE Wish_Manager SHALL persist the Category association in the Local_Database.
2. THE Wish_Manager SHALL provide a set of preset Categories that includes Learn, Travel, Buy, Save, and Achieve.
3. WHEN the User creates a Category with a name that does not match an existing Category, THE Wish_Manager SHALL store the new Category for reuse.
4. WHEN the User requests Wishes filtered by a selected Category, THE Wish_Manager SHALL return only the Wishes associated with that Category.

### Requirement 4: Prioritize Wishes

**User Story:** As a User, I want to set and sort by priority, so that I can focus on the Wishes that matter most.

#### Acceptance Criteria

1. WHEN the User sets the Priority of a Wish to `Low`, `Medium`, or `High`, THE Wish_Manager SHALL persist the selected Priority in the Local_Database.
2. WHEN the User requests Wishes sorted by Priority, THE Wish_Manager SHALL order the Wishes from `High` to `Low`.
3. IF the User provides a Priority value outside the set {`Low`, `Medium`, `High`}, THEN THE Wish_Manager SHALL reject the value and retain the previously stored Priority.

### Requirement 5: Track Progress

**User Story:** As a User, I want to record how far along a Wish is, so that I can see my advancement toward each aspiration.

#### Acceptance Criteria

1. WHEN the User sets a Progress_Value between 0 and 100 inclusive for a Wish, THE Wish_Manager SHALL persist the Progress_Value in the Local_Database.
2. IF the User provides a Progress_Value below 0 or above 100, THEN THE Wish_Manager SHALL reject the value and retain the previously stored Progress_Value.
3. WHEN the Progress_Value of a Wish changes from 0 to a value greater than 0, THE Wish_Manager SHALL set the Lifecycle_Status of the Wish to `In_Progress`.
4. WHEN the User sets the Progress_Value of a Wish to 100, THE Wish_Manager SHALL set the Lifecycle_Status of the Wish to `Completed`.

### Requirement 6: Manage Wish Lifecycle

**User Story:** As a User, I want each Wish to move through a clear lifecycle, so that I can distinguish active, in-progress, and completed aspirations.

#### Acceptance Criteria

1. WHEN a Wish is created, THE Wish_Manager SHALL set the Lifecycle_Status of the Wish to `Active`.
2. WHEN the User marks an `Active` Wish as started, THE Wish_Manager SHALL set the Lifecycle_Status of the Wish to `In_Progress`.
3. WHEN the User marks a Wish as complete, THE Wish_Manager SHALL set the Lifecycle_Status to `Completed` and set the Progress_Value to 100.
4. WHEN the User reopens a `Completed` Wish, THE Wish_Manager SHALL set the Lifecycle_Status to `In_Progress` and retain the stored Progress_Value.
5. WHEN the User requests Wishes filtered by a Lifecycle_Status, THE Wish_Manager SHALL return only the Wishes whose Lifecycle_Status matches the selected value.

### Requirement 7: Celebrate Completion

**User Story:** As a User, I want a celebration when I complete a Wish, so that fulfilling an aspiration feels rewarding.

#### Acceptance Criteria

1. WHEN a Wish transitions to Lifecycle_Status `Completed`, THE Wishable SHALL display the Celebration_View containing the message "Wish fulfilled".
2. WHEN the User dismisses the Celebration_View, THE Wishable SHALL return the User to the view that was active before the Celebration_View appeared.
3. WHILE the Celebration_View is displayed, THE Wishable SHALL identify the completed Wish by its title.

### Requirement 8: Delete a Wish

**User Story:** As a User, I want to delete a Wish, so that I can remove aspirations I no longer want to track.

#### Acceptance Criteria

1. WHEN the User confirms deletion of a Wish, THE Wish_Manager SHALL remove the Wish from the Local_Database.
2. WHEN the User requests deletion of a Wish, THE Wish_Manager SHALL request confirmation before removing the Wish.
3. IF the User cancels the deletion request, THEN THE Wish_Manager SHALL retain the Wish in the Local_Database.

### Requirement 9: View and Browse Wishes

**User Story:** As a User, I want to view my Wishes organized by lifecycle stage, so that I can navigate my aspirations easily.

#### Acceptance Criteria

1. THE Wishable SHALL provide a view listing all Wishes regardless of Lifecycle_Status.
2. THE Wishable SHALL provide a view listing Wishes with Lifecycle_Status `Active`.
3. THE Wishable SHALL provide a view listing Wishes with Lifecycle_Status `In_Progress`.
4. THE Wishable SHALL provide a view listing Wishes with Lifecycle_Status `Completed`.
5. WHEN the User opens a Wish from any list view, THE Wishable SHALL display the full details of the selected Wish.

### Requirement 10: Local-First Persistence and Offline Operation

**User Story:** As a User, I want the app to work fully offline with my data stored locally, so that I can use Wishable without any network connection or account.

#### Acceptance Criteria

1. THE Wishable SHALL store all Wishes and settings in the Local_Database on the device where Wishable is installed.
2. WHILE the device has no network connection, THE Wishable SHALL allow the User to create, edit, delete, and view Wishes.
3. THE Wishable SHALL operate without requiring a User account, a server, or a hosted database.
4. WHEN the User reopens Wishable after closing it, THE Wishable SHALL load the Wishes that were previously persisted in the Local_Database.

### Requirement 11: Export Data

**User Story:** As a User, I want to export my data, so that I can back it up or move it to another installation.

#### Acceptance Criteria

1. WHEN the User selects database export in the Settings_View, THE Backup_Manager SHALL produce a Database_Export containing all Wishes and settings.
2. WHEN the User selects JSON export in the Settings_View, THE Backup_Manager SHALL produce a JSON_Export containing all Wishes.
3. WHEN the User selects CSV export in the Settings_View, THE Backup_Manager SHALL produce a CSV_Export containing all Wishes.
4. IF an export operation fails, THEN THE Backup_Manager SHALL display a message describing the failure, SHALL delete any partially written export file at the designated location, and SHALL leave the Local_Database unchanged.

### Requirement 12: Import and Restore Data

**User Story:** As a User, I want to import previously exported data, so that I can restore my Wishes on this or another installation.

#### Acceptance Criteria

1. WHEN the User selects a valid Import_File in the Settings_View and confirms restore, THE Backup_Manager SHALL load the Wishes from the Import_File into the Local_Database.
2. IF the selected Import_File is malformed or unreadable, THEN THE Backup_Manager SHALL reject the import, display a descriptive error, and leave the Local_Database unchanged.
3. WHEN the User initiates a restore that will replace existing data, THE Backup_Manager SHALL request confirmation before modifying the Local_Database.
4. FOR ALL exports, performing a Round_Trip of exporting Wishes to a JSON_Export and then importing that JSON_Export SHALL produce a set of Wishes equivalent to the original set.
5. FOR ALL exports, performing a Round_Trip of exporting Wishes to a CSV_Export and then importing that CSV_Export SHALL produce a set of Wishes equivalent to the original set.

### Requirement 13: Responsive Cross-Platform Presentation

**User Story:** As a User, I want a consistent, adaptive interface on every platform, so that Wishable is usable on phones, tablets, and desktops.

#### Acceptance Criteria

1. THE Wishable SHALL run on web, Windows, macOS, Linux, Android, and iOS from a single shared codebase.
2. WHERE the available viewport width is at or below 600 logical pixels, THE Wishable SHALL present a single-column layout.
3. WHERE the available viewport width is above 600 logical pixels, THE Wishable SHALL present a multi-column or navigation-rail layout.
4. THE Wishable SHALL render its interface using Material 3 components and Material Symbols icons.

### Requirement 14: Extensibility for Future Cloud Synchronization

**User Story:** As a product owner, I want the V1 architecture to accommodate future cloud sync, so that V2 can add synchronization without a rewrite.

#### Acceptance Criteria

1. THE Wishable SHALL assign a stable unique identifier to each Wish at creation.
2. THE Wishable SHALL record a creation timestamp and a last-modified timestamp for each Wish.
3. THE Wishable SHALL isolate all Local_Database access behind a data-access layer that application features depend on instead of accessing the Local_Database directly.
4. THE Wishable SHALL exclude any account, server, or hosted-database dependency from V1.

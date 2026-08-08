import 'package:flutter/material.dart' show ThemeMode;
import 'package:surplus_marketplace/features/account/domain/entities/contact_category.dart';
import 'package:surplus_marketplace/features/account/domain/entities/deletion_eligibility.dart';
import 'package:surplus_marketplace/features/account/domain/entities/help_topic.dart';
import 'package:surplus_marketplace/features/account/domain/entities/legal_doc_id.dart';
import 'package:surplus_marketplace/features/account/domain/entities/legal_document.dart';
import 'package:surplus_marketplace/features/account/domain/entities/notification_preferences.dart';
import 'package:surplus_marketplace/features/account/domain/entities/saved_location.dart';
import 'package:surplus_marketplace/features/location/domain/entities/resolved_location.dart';

/// Server stand-in (Phase 1 locked decision) for Phase 7 §7.7 (Phase 8
/// §8.12 step 9). **Profile itself (name/email/avatar/phone) is not here**
/// — it's `Customer`, owned by `auth` (`AuthRepository.updateAccountDetails`
/// etc.), reused rather than duplicated.
abstract interface class AccountRepository {
  // ---------------------------------------------------------------------
  // Saved locations (§5f.3)
  // ---------------------------------------------------------------------

  Future<List<SavedLocation>> getSavedLocations();

  /// Throws `ValidationException` past the 10-location cap (§5f.3).
  Future<SavedLocation> addSavedLocation({
    required String label,
    required ResolvedLocation location,
  });

  Future<SavedLocation> updateSavedLocationLabel(String id, String label);

  /// Deleting the default promotes another location or clears the default
  /// explicitly (§5f.3) — never leaves a dangling default reference.
  Future<void> deleteSavedLocation(String id);

  Future<void> setDefaultSavedLocation(String id);

  // ---------------------------------------------------------------------
  // Notification preferences (§5f.4)
  // ---------------------------------------------------------------------

  Future<NotificationPreferences> getNotificationPreferences();

  Future<void> setNotificationPreferences(NotificationPreferences prefs);

  // ---------------------------------------------------------------------
  // App settings (§5f.5)
  // ---------------------------------------------------------------------

  Future<ThemeMode> getThemeMode();

  Future<void> setThemeMode(ThemeMode mode);

  Future<bool> getDataSaverEnabled();

  Future<void> setDataSaverEnabled(bool enabled);

  /// Bytes currently reclaimable — **never includes auth tokens or cached
  /// order history**, which are not cache (§5f.5's own rule).
  Future<int> cacheSizeBytes();

  Future<void> clearCache();

  // ---------------------------------------------------------------------
  // Help & support (§5f.6/§5f.7)
  // ---------------------------------------------------------------------

  Future<List<HelpTopic>> getHelpTopics();

  /// Throws `NotFoundException` for an unknown id.
  Future<HelpTopic> getHelpTopic(String id);

  // ---------------------------------------------------------------------
  // Contact us (§5f.8)
  // ---------------------------------------------------------------------

  Future<void> submitContactRequest({
    required ContactCategory category,
    required String message,
    String? orderId,
  });

  // ---------------------------------------------------------------------
  // Legal (§5f.9)
  // ---------------------------------------------------------------------

  /// Throws `NotFoundException` for an unknown [docId].
  Future<LegalDocument> getLegalDocument(LegalDocId docId);

  // ---------------------------------------------------------------------
  // Deletion (§5f.11, amendment A20)
  // ---------------------------------------------------------------------

  Future<DeletionEligibility> getDeletionEligibility();

  /// Throws `AccountDeletionBlockedException` if called while blocked —
  /// the eligibility check is advisory for the UI; this is the
  /// server-enforced boundary (mirrors R2's "never trust cache at a
  /// mutation boundary" shape). The caller is responsible for proving
  /// possession of the phone number first, via
  /// `AuthRepository.requestReverificationOtp`/`verifyReverificationOtp`
  /// (§5f.11 — "confirmation is by OTP, not by typing a magic word").
  Future<void> deleteAccount();
}

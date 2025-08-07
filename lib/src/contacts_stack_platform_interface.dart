import 'package:flutter_contacts_stack/flutter_contacts_stack.dart';

/// Abstract platform interface for `flutter_contacts_stack` plugin.
/// This defines the contract that platform-specific implementations must fulfill.

abstract class ContactsStackPlatform {
  /// Singleton instance that delegates to the actual platform implementation.
  /// By default, it uses [MethodChannelContactsStack] unless overridden for testing/mocking.
  static ContactsStackPlatform instance = MethodChannelContactsStack();

  /// startListeningToContactChanges
  void startListeningToContactChanges(Function(List<Contact>) onChanged);

  /// requestPermission
  Future<bool> requestPermission();

  /// Fetches contacts based on provided [ContactFetchOptions].
  /// Supports partial or full data retrieval, including pagination or batching.
  Future<List<Contact>> fetchContacts(ContactFetchOptions options);

  /// Streams contacts continuously in batches or chunks using [ContactFetchOptions].
  /// Ideal for large contact sets or real-time updates during long fetch operations.
  Stream<List<Contact>> streamContacts(ContactFetchOptions options);

  /// Retrieves a single contact by its [id], usually the platform-assigned identifier.
  /// Returns `null` if the contact doesn't exist or can't be accessed.
  Future<Contact?> getContactById(String id);

  /// Inserts a new [contact] into the contact store.
  /// Returns `true` on success, `false` on failure.
  Future<bool> insertContact(Contact contact);

  /// Updates an existing [contact] (matched by its ID).
  /// Returns `true` if the update was successful.
  Future<bool> updateContact(Contact contact);

  /// Deletes a contact identified by [id].
  /// Returns `true` if the deletion was successful.
  Future<bool> deleteContact(String id);

  /// Deletes multiple contacts using a list of [ids].
  /// Returns `true` if all deletions succeeded.
  Future<bool> deleteMultipleContacts(List<String> ids);

  /// Exports the given [contact] as a VCard string (VCF format).
  /// Useful for sharing, backup, or sync operations.
  Future<String> exportToVCard(Contact contact);

  /// Imports a [vCardString] and converts it into a [Contact] object.
  /// Also saves it into the contact store.
  //Future<Contact?> importFromVCard(String vCardString);
}

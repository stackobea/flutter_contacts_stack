import 'package:flutter_contacts_stack/flutter_contacts_stack.dart';

class FlutterContactsStack {
  static Future<bool> requestPermission() {
    return ContactsStackPlatform.instance.requestPermission();
  }

  /// startListeningToContactChanges
  static void startListeningToContactChanges(
    Function(List<Contact>) onChanged,
  ) {
    return ContactsStackPlatform.instance.startListeningToContactChanges(
      onChanged,
    );
  }

  /// Fetch contacts
  static Future<List<Contact>> fetchContacts(ContactFetchOptions options) {
    return ContactsStackPlatform.instance.fetchContacts(options);
  }

  /// Stream contacts
  static Stream<List<Contact>> streamContacts(ContactFetchOptions options) {
    return ContactsStackPlatform.instance.streamContacts(options);
  }

  /// Get a contact by id
  static Future<Contact?> getContactById(String id) {
    return ContactsStackPlatform.instance.getContactById(id);
  }

  /// Insert a contact
  static Future<bool> insertContact(Contact contact) {
    return ContactsStackPlatform.instance.insertContact(contact);
  }

  /// Update a contact
  static Future<bool> updateContact(Contact contact) {
    return ContactsStackPlatform.instance.updateContact(contact);
  }

  /// Delete a contact by ID
  static Future<bool> deleteContact(String id) {
    return ContactsStackPlatform.instance.deleteContact(id);
  }

  /// Delete multiple contacts by IDs
  static Future<bool> deleteMultipleContacts(List<String> ids) {
    return ContactsStackPlatform.instance.deleteMultipleContacts(ids);
  }

  /// Export contacts to VCard
  static Future<String> exportToVCard(Contact contact) {
    return ContactsStackPlatform.instance.exportToVCard(contact);
  }

  /// Import contacts from VCard
  // static Future<Contact?> importFromVCard(String vCardString) {
  //   return ContactsStackPlatform.instance.importFromVCard(vCardString);
  // }
}

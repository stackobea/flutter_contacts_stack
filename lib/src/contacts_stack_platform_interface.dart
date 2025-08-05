import 'package:flutter_contacts_stack/src/contact_model.dart';
import 'package:flutter_contacts_stack/src/method_channel_contacts_stack.dart';

abstract class ContactsStackPlatform {
  static ContactsStackPlatform _instance = MethodChannelContactsStack();

  static ContactsStackPlatform get instance => _instance;

  static set instance(ContactsStackPlatform instance) {
    _instance = instance;
  }

  Future<List<Contact>> fetchContacts({
    bool withProperties = false,
    bool withPhoto = false,
    int? batchSize,
    int? offset,
  });

  Stream<List<Contact>> streamContacts({
    bool withProperties = false,
    bool withPhoto = false,
    int batchSize = 100,
  });

  Future<Contact?> getContactById(String id);

  Future<bool> insertContact(Contact contact);

  Future<bool> updateContact(Contact contact);

  Future<bool> deleteContact(String id);

  Future<bool> deleteMultipleContacts(List<String> ids);

  Future<String> exportToVCard(Contact contact);

  Future<Contact?> importFromVCard(String vCardString);
}

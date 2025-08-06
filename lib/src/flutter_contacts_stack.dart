
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts_stack/flutter_contacts_stack.dart';

class FlutterContactsStack {
  // static Future<bool> requestPermission() {
  //   return ContactsStackPlatform.instance.requestPermission();
  // }

  static Future<List<Contact>> fetchContacts(ContactFetchOptions options) {
    return ContactsStackPlatform.instance.fetchContacts(options);
  }
}

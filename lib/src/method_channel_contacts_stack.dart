import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts_stack/flutter_contacts_stack.dart';

class MethodChannelContactsStack extends ContactsStackPlatform {
  static const MethodChannel _channel = MethodChannel('flutter_contacts_stack');

  @override
  void startListeningToContactChanges(Function(List<Contact>) onChanged) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onContactChanged') {
        final List<dynamic>? res = call.arguments as List<dynamic>?;

        final contacts = (res ?? [])
            .map((item) => Contact.fromMap(Map<String, dynamic>.from(item)))
            .toList();

        onChanged(contacts);
      }
    });
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('Permission request failed: $e');
      return false;
    }
  }

  @override
  Future<List<Contact>> fetchContacts(ContactFetchOptions options) async {
    final result = await _channel.invokeMethod<List<dynamic>>('fetchContacts', {
      'withProperties': options.withProperties,
      'withPhoto': options.withPhoto,
      'batchSize': options.batchSize,
      'offset': options.offset,
    });

    final contacts = (result ?? [])
        .map((item) => Contact.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    return contacts;
  }

  @override
  Stream<List<Contact>> streamContacts(ContactFetchOptions options) async* {
    int offset = 0;

    while (true) {
      // Fetch contacts using current offset and batch size
      final batch = await fetchContacts(
        ContactFetchOptions(
          withProperties: options.withProperties,
          withPhoto: options.withPhoto,
          batchSize: options.batchSize,
          offset: offset, // ❗️Use updated offset here instead of options.offset
        ),
      );

      // Break the loop if no more contacts are returned
      if (batch.isEmpty) break;

      // Yield the current batch of contacts
      yield batch;

      // Increment offset for the next batch
      offset += options.batchSize ?? 0;

      // If no batchSize is specified, stop to avoid infinite loop
      //if (options.batchSize == null) break;

      if (batch.length < (options.batchSize ?? 0)) break; // last batch
    }
  }

  @override
  Future<Contact?> getContactById(String id) async {
    final result = await _channel.invokeMethod<Map>('getContactById', {
      'id': id,
    });
    return result != null
        ? Contact.fromMap(Map<String, dynamic>.from(result))
        : null;
  }

  @override
  Future<bool> insertContact(Contact contact) async {
    final result = await _channel.invokeMethod<bool>(
      'insertContact',
      contact.toMap(),
    );
    return result ?? false;
  }

  @override
  Future<bool> updateContact(Contact contact) async {
    final result = await _channel.invokeMethod<bool>(
      'updateContact',
      contact.toMap(),
    );
    return result ?? false;
  }

  @override
  Future<bool> deleteContact(String id) async {
    final result = await _channel.invokeMethod<bool>('deleteContact', {
      'id': id,
    });
    return result ?? false;
  }

  @override
  Future<bool> deleteMultipleContacts(List<String> ids) async {
    final result = await _channel.invokeMethod<bool>('deleteMultipleContacts', {
      'ids': ids,
    });
    return result ?? false;
  }

  @override
  Future<String> exportToVCard(Contact contact) async {
    final result = await _channel.invokeMethod<String>(
      'exportToVCard',
      contact.toMap(),
    );
    return result ?? "";
  }

  // @override
  // Future<Contact?> importFromVCard(String vCardString) async {
  //   final result = await _channel.invokeMethod<Map>('importFromVCard', {
  //     'vCard': vCardString,
  //   });
  //   return result != null
  //       ? Contact.fromMap(Map<String, dynamic>.from(result))
  //       : null;
  // }
}

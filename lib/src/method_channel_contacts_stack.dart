import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts_stack/flutter_contacts_stack.dart';
import 'package:flutter_contacts_stack/src/contacts_stack_platform_interface.dart';
import 'package:flutter_contacts_stack/src/models/contact_model.dart';

class MethodChannelContactsStack extends ContactsStackPlatform {
  static const _channel = MethodChannel('flutter_contacts_stack');

  // @override
  // Future<List<Contact>> fetchContacts({
  //   bool withProperties = false,
  //   bool withPhoto = false,
  //   int? batchSize,
  //   int? offset,
  // }) async {
  //   final result = await _channel.invokeMethod<List<dynamic>>('fetchContacts', {
  //     'withProperties': withProperties,
  //     'withPhoto': withPhoto,
  //     'batchSize': batchSize,
  //     'offset': offset,
  //   });
  //
  //   return result
  //           ?.map((e) => Contact.fromMap(Map<String, dynamic>.from(e)))
  //           .toList() ??
  //       [];
  // }

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
      final batch = await fetchContacts(
        ContactFetchOptions(
          withProperties: options.withProperties,
          withPhoto: options.withPhoto,
          batchSize: options.batchSize,
          offset: options.offset,
        ),
      );
      if (batch.isEmpty) break;
      yield batch;
      offset += options.batchSize ?? 0;
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
    return result ?? '';
  }

  @override
  Future<Contact?> importFromVCard(String vCardString) async {
    final result = await _channel.invokeMethod<Map>('importFromVCard', {
      'vCard': vCardString,
    });
    return result != null
        ? Contact.fromMap(Map<String, dynamic>.from(result))
        : null;
  }
}

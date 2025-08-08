# Flutter Contacts

[![Pub Version](https://img.shields.io/pub/v/flutter_contacts_stack)](https://pub.dev/packages/flutter_contacts_stack)
[![Pub Likes](https://img.shields.io/pub/likes/flutter_contacts_stack)](https://pub.dev/packages/flutter_contacts_stack)
[![Pub Points](https://img.shields.io/pub/points/flutter_contacts_stack)](https://pub.dev/packages/flutter_contacts_stack)
[![Popularity](https://img.shields.io/pub/popularity/flutter_contacts_stack)](https://pub.dev/packages/flutter_contacts_stack)


A full-featured, cross-platform Flutter plugin to manage contacts on Android and iOS devices.  
Built for speed, reliability, and modern app needs—capable of handling 5000+ contacts seamlessly.

---

## ✨ Features

- ✅ Light & full fetch (with optional photo, emails, phones, etc.)
- ✅ Pagination / Stream fetch for large datasets
- ✅ Fetch contact by ID
- ✅ Insert / Update / Delete (single & multiple)
- ✅ vCard Export & Import
- ✅ Contact change observer (Android & iOS)
- ✅ Contact search (name, phone, email)
- ✅ Group / Label fetch and assignment
- ✅ Merge contact suggestions
- ✅ Fetch deleted contacts (Android)
- ✅ Filter by SIM / device / social accounts
- ✅ Proper permission handling
- ✅ Type-safe & null-safe Dart APIs

---

## 🔧 Platform Support

| Feature               | Android | iOS |
|-----------------------|---------|-----|
| Fetch Contacts        | ✅      | ✅  |
| Insert/Update/Delete  | ✅      | ✅  |
| vCard Export / Import | ✅      | ✅  |
| Contact Observer      | ✅      | ✅  |
| Deleted Contacts      | ✅      | 🚫  |
| Group/Label support   | ✅      | ✅  |

---

## 🚀 Installation


```yaml
dependencies:
  flutter_contacts_stack: ^<latest-version>
```

Then Run

```bash
flutter pub get
```


## 🛠️ Permissions

**Android:**
Add to AndroidManifest.xml:

```xml
<uses-permission android:name="android.permission.READ_CONTACTS"/>
<uses-permission android:name="android.permission.WRITE_CONTACTS"/>
<uses-permission android:name="android.permission.GET_ACCOUNTS"/>
```

**iOS:**
Add to Info.plist:
```xml
<key>NSContactsUsageDescription</key>
<string>This app uses contacts to manage your address book.</string>
```


## 📦 Usage

```dart
import 'package:flutter_contacts_stack/flutter_contacts_stack.dart';

// Check permission
await FlutterContactsStack.requestPermission();

// Fetch all contacts (light)
final contacts = await FlutterContactsStack.fetchContacts();

// Fetch fully with properties
final result = await FlutterContactsStack.fetchContacts(
  const ContactFetchOptions(
    withPhoto: true,
    withProperties: true,
    offset: 0,
    batchSize: 100,
  )
);

// Stream Fetch
FlutterContactsStack.streamContacts(options);

// Insert a contact
final newContact = Contact(
  givenName: 'Titto',
  familyName: 'Stack',
  phones: ['1234567890'],
);
await FlutterContactsStack.insertContact(newContact);

// Export as vCard
final vcard = await FlutterContactsStack.exportToVCard(contactId);

// Import from vCard
final contact = await FlutterContactsStack.importFromVCard(vcard);
```


## 📲 Observing Contact Changes
```dart
FlutterContactsStack.startListeningToContactChanges((contacts) {
  for (var contact in contacts) {
    if (kDebugMode) {
      print('Updated: ${contact.displayName}');
    }
  }
});
```

## 📇 Insert a Contact
```dart
final contact = Contact(
displayName: "Titto Stack",
phones: ["1234567890", "9090909090"],
emails: ["titto@example.com", "titto.contact@example.com"],
);
await plugin.insertContact(contact);
```


## 📚 vCard Support
*exportToVCard(contactId) – Exports a contact to .vcf format*    



## 🔍 TODO (Future Updates)
Support for contact favorites

⚫ importFromVCard
⚫ Cross-device sync layer  
⚫ Deleted contact recovery (iOS workaround)  
⚫ Custom contact field support    



## 💬 Feedback
Pull requests and issues are welcome on GitHub.  


## 👨‍💻 Contributing
Pull requests are welcome. Please ensure any changes maintain cross-platform compatibility and are tested.
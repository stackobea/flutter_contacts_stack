import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts_stack/flutter_contacts_stack.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // final hasPermission = await FlutterContactsStack.requestPermission();
  // if (!hasPermission) {
  //   print('Permission denied');
  // } else {
  //   print('Permission granted');
  // }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contacts Stack Demo',

      debugShowCheckedModeBanner: false,
      home: const ContactHomePage(),
    );
  }
}

class ContactHomePage extends StatefulWidget {
  const ContactHomePage({super.key});

  @override
  State<ContactHomePage> createState() => _ContactHomePageState();
}

class _ContactHomePageState extends State<ContactHomePage> {
  List<Contact> contacts = [];

  @override
  void initState() {
    super.initState();
    loadContacts();
  }

  Future<void> loadContacts() async {
    try {
      final result = await FlutterContactsStack.fetchContacts(
        const ContactFetchOptions(
          withPhoto: true,
          withProperties: true,
          offset: 0,
          batchSize: 100,
        ),
      );

      setState(() {
        contacts = result;
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching contacts: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts Stack'), centerTitle: true),
      body: ListView.builder(
        itemCount: contacts.length,
        shrinkWrap: true,
        itemBuilder: (_, index) {
          final Contact contact = contacts[index];

          return contactItems(contact);
        },
      ),
    );
  }

  Widget contactItems(Contact contact) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Color(0xffF7F3F2),
        border: Border.all(color: Color(0xffE3DAD8)),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) {
              if (contact.photo.toString() == "null") {
                return ClipOval(
                  child: CircleAvatar(
                    backgroundColor: Colors.grey,
                    radius: 25,
                    child: Text(
                      contact.displayName?.substring(0, 1).toString() ?? ".",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }

              Uint8List imageBytes = base64Decode(
                contact.photo.toString().trim().replaceAll('\n', ''),
              );

              return ClipOval(
                child: Image.memory(
                  imageBytes,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),

          SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contact.displayName ?? "No-Name",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),

              Text(
                contact.phones!.isNotEmpty ? contact.phones!.first : 'Null',

                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

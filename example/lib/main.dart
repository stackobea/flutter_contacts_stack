import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts_stack/flutter_contacts_stack.dart';
import 'package:flutter_contacts_stack_example/fetch_contacts_scroll.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  askPermission() async {
    final hasPermission = await FlutterContactsStack.requestPermission();
    if (!hasPermission) {
      if (kDebugMode) {
        print('Permission denied');
      }
    } else {
      if (kDebugMode) {
        print('Permission granted');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    askPermission();
  }

  startListeningToContactChanges() {
    FlutterContactsStack.startListeningToContactChanges((contacts) {
      for (var contact in contacts) {
        if (kDebugMode) {
          print('Updated: ${contact.displayName}');
        }
      }

      // Optional: Refresh local database or UI here.
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        scrolledUnderElevation: 0.0,

        title: const Text(
          'Contacts Stack',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            allButtons(),

            if (contacts.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text("No data"),
              ),
            ] else ...[
              ListView.builder(
                itemCount: contacts.length,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemBuilder: (_, index) {
                  final Contact contact = contacts[index];
                  return contactItems(contact);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget allButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 10),
          Text(
            "Samples",
            style: TextStyle(
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),

          SizedBox(height: 20),

          // fetchContacts
          sampleWidget(
            onTap: () async {
              try {
                final result = await FlutterContactsStack.fetchContacts(
                  const ContactFetchOptions(
                    withPhoto: true,
                    withProperties: true,
                    offset: 0,
                    batchSize: 1000,
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
            },
            name: "Fetch All Contacts",
            icon: Icon(Icons.all_inclusive),
          ),

          // getContactById
          sampleWidget(
            onTap: () async {
              try {
                final result = await FlutterContactsStack.getContactById("2");

                setState(() {
                  if (result != null) {
                    contacts = [
                      Contact(
                        id: result.id ?? "",
                        displayName: result.displayName ?? "",
                        photo: result.photo ?? "",
                        phones: result.phones ?? [],
                        emails: result.emails ?? [],
                      ),
                    ];
                  } else {
                    contacts = [];
                  }
                });
              } catch (e) {
                if (kDebugMode) {
                  print("Error fetching contact: $e");
                }
              }
            },
            name: "Get Contacts by Unique ID",
            icon: Icon(Icons.format_underline),
          ),

          // streamContacts
          sampleWidget(
            onTap: () async {
              final options = ContactFetchOptions(
                withProperties: true,
                withPhoto: false,
                batchSize: 100, // fetch 100 contacts per batch
                offset: 0,
              );

              FlutterContactsStack.streamContacts(options).listen(
                (batch) {
                  // // This will be called for each batch of contacts
                  // for (var contact in batch) {
                  //   print(
                  //     'Name: ${contact.displayName}, Phones: ${contact.phones}',
                  //   );
                  // }

                  // You can also add each batch to a list if needed
                  contacts.addAll(batch);
                  setState(() {});
                },
                onError: (error) {
                  //print('Error fetching contacts: $error');
                },
                onDone: () {
                  //print('Finished loading all contacts.');
                },
              );
            },
            name: "Stream Contacts",
            icon: Icon(Icons.all_inclusive),
          ),

          // exportToVCard
          sampleWidget(
            onTap: () async {
              try {
                var res = await FlutterContactsStack.exportToVCard(
                  Contact(id: "2"),
                );

                if (kDebugMode) {
                  print(res);
                }
              } catch (e) {
                if (kDebugMode) {
                  print("Error $e");
                }
              }
            },
            name: "Export To VCard",
            icon: Icon(CupertinoIcons.circle_grid_hex_fill),
          ),

          // importFromVCard
          // sampleWidget(
          //   onTap: () async {
          //     try {
          //          var res=  await FlutterContactsStack.importFromVCard();
          //
          //
          //     } catch (e) {
          //       if (kDebugMode) {
          //         print("Error $e");
          //       }
          //     }
          //   },
          //   name: "Import From VCard",
          //   icon: Icon(CupertinoIcons.book),
          // ),

          // ContactStreamPage
          sampleWidget(
            onTap: () async {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (e) => ContactStreamPage()));
            },
            name: "Contact Stream Scroll Page",
            icon: Icon(CupertinoIcons.book),
          ),
        ],
      ),
    );
  }

  Widget sampleWidget({
    required Function() onTap,
    required String name,
    required Widget icon,
  }) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 18),
        margin: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Color(0xffEDEDF7),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Row(
          children: [
            icon,
            SizedBox(width: 10),
            Text(
              name,
              style: TextStyle(
                color: Colors.blue,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
              if (contact.photo.toString() == "null" && contact.photo == null) {
                return ClipOval(
                  child: CircleAvatar(
                    backgroundColor: Colors.grey,
                    radius: 25,
                    child: Text(
                      (contact.displayName != ""
                          ? contact.displayName
                                    ?.substring(0, 1)
                                    .toString()
                                    .toUpperCase() ??
                                "."
                          : "?"),
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
          Expanded(
            child: Column(
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

                if (contact.phones?.isNotEmpty ?? false) ...[
                  Text(
                    contact.phones!.isNotEmpty
                        ? contact.phones!.join(', ')
                        : 'Null',

                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],

                if (contact.emails?.isNotEmpty ?? false) ...[
                  Text(
                    contact.emails!.isNotEmpty
                        ? contact.emails!.join(', ')
                        : 'Null',

                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],

                if (contact.id?.isNotEmpty ?? false) ...[
                  Text(
                    "ID = ${contact.id}",

                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ] else ...[
                  SizedBox(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

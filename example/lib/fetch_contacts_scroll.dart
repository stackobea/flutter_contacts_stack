import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_contacts_stack/flutter_contacts_stack.dart';

class ContactStreamPage extends StatefulWidget {
  const ContactStreamPage({super.key});

  @override
  createState() => _ContactStreamPageState();
}

class _ContactStreamPageState extends State<ContactStreamPage> {
  final ScrollController _scrollController = ScrollController();
  final List<Contact> _contacts = [];
  late Stream<List<Contact>> _contactStream;
  late StreamIterator<List<Contact>> _contactStreamIterator;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();

    // Start streaming
    _contactStream = FlutterContactsStack.streamContacts(
      ContactFetchOptions(batchSize: 12, withProperties: true),
    );
    _contactStreamIterator = StreamIterator(_contactStream);

    _loadNextBatch();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _loadNextBatch();
      }
    });
  }

  Future<void> _loadNextBatch() async {
    setState(() {
      _isLoading = true;
    });
    final hasNext = await _contactStreamIterator.moveNext();
    if (hasNext) {
      setState(() {
        _contacts.addAll(_contactStreamIterator.current);
      });
    } else {
      setState(() {
        _hasMore = false;
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _contactStreamIterator.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.0,
        backgroundColor: Colors.white,
        title: const Text("Contacts"),
      ),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: _contacts.length + 1, // +1 for loading indicator
        itemBuilder: (context, index) {
          if (index == _contacts.length) {
            return _hasMore
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }

          final contact = _contacts[index];
          return ListTile(
            leading: CircleAvatar(child: Text(contact.displayName?[0] ?? "?")),
            title: Text(contact.displayName ?? "No name"),
            subtitle: Text(
              (contact.phones?.map((e) => e).join(", ")) ?? "No phone",
              style: const TextStyle(fontSize: 12),
            ),
          );
        },
      ),
    );
  }
}

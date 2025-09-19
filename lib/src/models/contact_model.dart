class Contact {
  final String? id;
  final String? displayName;
  final String? givenName;
  final String? middleName;
  final String? familyName;
  final String? prefix;
  final String? suffix;
  final List<String>? phones;
  final List<String>? emails;
  final String? company;
  final String? jobTitle;
  final String? photo;
  final String? note;
  final List<String>? postalAddresses;

  Contact({
    this.id,
    this.displayName,
    this.givenName,
    this.middleName,
    this.familyName,
    this.prefix,
    this.suffix,
    this.phones,
    this.emails,
    this.company,
    this.jobTitle,
    this.photo,
    this.note,
    this.postalAddresses,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'givenName': givenName,
      'middleName': middleName,
      'familyName': familyName,
      'prefix': prefix,
      'suffix': suffix,
      'phones': phones,
      'emails': emails,
      'company': company,
      'jobTitle': jobTitle,
      'photo': photo,
      'note': note,
      'postalAddresses': postalAddresses,
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    List<String> listStringFrom(List<dynamic> list) {
      if (list.isEmpty) return [];
      return list
          .map((e) {
            if (e is String) return e;
            if (e is Map) return e['value'];
            return null;
          })
          .whereType<String>()
          .toList();
    }
    
    return Contact(
      id: map['id'],
      displayName: map['displayName'],
      givenName: map['givenName'],
      middleName: map['middleName'],
      familyName: map['familyName'],
      prefix: map['prefix'],
      suffix: map['suffix'],
      phones:listStringFrom(map['phones'] ?? []),
      emails: listStringFrom(map['emails'] ?? []),
      company: map['company'],
      jobTitle: map['jobTitle'],
      photo: map['photo'],
      note: map['note'],
      postalAddresses: List<String>.from(map['postalAddresses'] ?? []),
    );
  }
}

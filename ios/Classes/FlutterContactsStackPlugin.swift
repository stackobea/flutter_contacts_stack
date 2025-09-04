import Flutter
import UIKit
import Contacts
import ContactsUI

public class FlutterContactsStackPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?
    private let contactStore = CNContactStore()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_contacts_stack", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "flutter_contacts_stack_events", binaryMessenger: registrar.messenger())

        let instance = FlutterContactsStackPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "hasPermission": hasPermission(result: result)
        case "requestPermission": requestPermission(result: result)
        case "fetchContacts": fetchContacts(args: call.arguments, result: result)
        case "getContactsLite": getContactsLite(result: result)
        case "getContactsFull": getContactsFull(result: result)
        case "getContactById": getContactById(args: call.arguments, result: result)
        case "insertContact": insertContact(args: call.arguments, result: result)
        case "updateContact": updateContact(args: call.arguments, result: result)
        case "deleteContact": deleteContact(args: call.arguments, result: result)
        case "exportToVCard": exportToVCard(args: call.arguments, result: result)
        case "startObserver": startObserver(result: result)
        case "stopObserver": stopObserver(result: result)
        case "searchContacts": searchContacts(args: call.arguments, result: result)
        case "getGroups": getGroups(result: result)
        case "getContactsByAccountType": getContactsByAccountType(args: call.arguments, result: result)
        case "getMergeSuggestions": getMergeSuggestions(result: result)
        case "getDeletedContacts": getDeletedContacts(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Permissions

    private func hasPermission(result: FlutterResult) {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        result(status == .authorized)
    }

    private func requestPermission(result: @escaping FlutterResult) {
        contactStore.requestAccess(for: .contacts) { granted, _ in
            DispatchQueue.main.async { result(granted) }
        }
    }

    // MARK: - Fetch Contacts

    private func fetchContacts(args: Any?, result: FlutterResult) {
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor
        ]
        var contactsArray: [[String: Any]] = []

        let request = CNContactFetchRequest(keysToFetch: keys)
        do {
            try contactStore.enumerateContacts(with: request) { contact, _ in
                contactsArray.append(self.serializeContact(contact))
            }
            result(contactsArray)
        } catch {
            result(FlutterError(code: "FETCH_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func getContactsLite(result: FlutterResult) {
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor
        ]
        var contactsArray: [[String: Any]] = []

        let request = CNContactFetchRequest(keysToFetch: keys)
        do {
            try contactStore.enumerateContacts(with: request) { contact, _ in
                contactsArray.append(self.serializeContact(contact, lite: true))
            }
            result(contactsArray)
        } catch {
            result(FlutterError(code: "FETCH_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func getContactsFull(result: FlutterResult) {
        fetchContacts(args: nil, result: result)
    }

    private func getContactById(args: Any?, result: FlutterResult) {
        guard let dict = args as? [String: Any], let id = dict["id"] as? String else {
            result(nil)
            return
        }

        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactImageDataKey] as [CNKeyDescriptor]
        do {
            let contact = try contactStore.unifiedContact(withIdentifier: id, keysToFetch: keys)
            result(serializeContact(contact))
        } catch {
            result(nil)
        }
    }

    // MARK: - CRUD

    private func insertContact(args: Any?, result: FlutterResult) {
        guard let dict = args as? [String: Any] else { result(false); return }

        let contact = CNMutableContact()
        contact.givenName = dict["givenName"] as? String ?? ""
        contact.familyName = dict["familyName"] as? String ?? ""
        if let phone = dict["phone"] as? String {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))]
        }
        if let email = dict["email"] as? String {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelHome, value: email as NSString)]
        }

        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)

        do {
            try contactStore.execute(saveRequest)
            result(true)
        } catch {
            result(false)
        }
    }

    private func updateContact(args: Any?, result: FlutterResult) {
        guard let dict = args as? [String: Any], let id = dict["id"] as? String else { result(false); return }
        do {
            let contact = try contactStore.unifiedContact(withIdentifier: id, keysToFetch: [CNContactGivenNameKey as CNKeyDescriptor]).mutableCopy() as! CNMutableContact
            if let name = dict["givenName"] as? String { contact.givenName = name }

            let saveRequest = CNSaveRequest()
            saveRequest.update(contact)
            try contactStore.execute(saveRequest)
            result(true)
        } catch {
            result(false)
        }
    }

    private func deleteContact(args: Any?, result: FlutterResult) {
        guard let dict = args as? [String: Any], let id = dict["id"] as? String else { result(false); return }
        do {
            let contact = try contactStore.unifiedContact(withIdentifier: id, keysToFetch: []).mutableCopy() as! CNMutableContact
            let saveRequest = CNSaveRequest()
            saveRequest.delete(contact)
            try contactStore.execute(saveRequest)
            result(true)
        } catch {
            result(false)
        }
    }

    // MARK: - VCard

    private func exportToVCard(args: Any?, result: FlutterResult) {
        guard let dict = args as? [String: Any], let id = dict["id"] as? String else { result(nil); return }
        do {
            let contact = try contactStore.unifiedContact(withIdentifier: id, keysToFetch: [CNContactViewController.descriptorForRequiredKeys()])
            let data = try CNContactVCardSerialization.data(with: [contact])
            let vCardString = String(data: data, encoding: .utf8)
            result(vCardString)
        } catch {
            result(nil)
        }
    }

    // MARK: - Observer

    private func startObserver(result: FlutterResult) {
        NotificationCenter.default.addObserver(self, selector: #selector(contactsDidChange), name: .CNContactStoreDidChange, object: nil)
        result(true)
    }

    private func stopObserver(result: FlutterResult) {
        NotificationCenter.default.removeObserver(self, name: .CNContactStoreDidChange, object: nil)
        result(true)
    }

    @objc private func contactsDidChange() {
        eventSink?("onContactChanged")
    }

    // MARK: - Search & Groups

    private func searchContacts(args: Any?, result: FlutterResult) {
        guard let dict = args as? [String: Any], let query = dict["query"] as? String else { result([]); return }
        let predicate = CNContact.predicateForContacts(matchingName: query)
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        do {
            let contacts = try contactStore.unifiedContacts(matching: predicate, keysToFetch: keys)
            result(contacts.map { serializeContact($0) })
        } catch {
            result([])
        }
    }

    private func getGroups(result: FlutterResult) {
        do {
            let groups = try contactStore.groups(matching: nil)
            let data = groups.map { ["name": $0.name, "identifier": $0.identifier] }
            result(data)
        } catch {
            result([])
        }
    }

    private func getContactsByAccountType(args: Any?, result: FlutterResult) {
        // iOS doesn't expose account types like Android - can be approximated via container IDs
        do {
            let containers = try contactStore.containers(matching: nil)
            let data = containers.map { ["name": $0.name, "identifier": $0.identifier] }
            result(data)
        } catch {
            result([])
        }
    }

    private func getMergeSuggestions(result: FlutterResult) {
        // No direct iOS API — would require manual duplicate matching
        result([])
    }

    private func getDeletedContacts(result: FlutterResult) {
        // No native deleted contacts API — can track via observer and caching
        result([])
    }

    // MARK: - Helper

    private func serializeContact(_ contact: CNContact, lite: Bool = false) -> [String: Any] {
        var dict: [String: Any] = [
            "id": contact.identifier,
            "givenName": contact.givenName,
            "familyName": contact.familyName
        ]

        if !lite {
            dict["phones"] = contact.phoneNumbers.map { ["label": $0.label ?? "", "value": $0.value.stringValue] }
            dict["emails"] = contact.emailAddresses.map { ["label": $0.label ?? "", "value": $0.value as String] }
            if let data = contact.imageData {
                dict["image"] = FlutterStandardTypedData(bytes: data)
            }
        }
        return dict
    }

    // MARK: - FlutterStreamHandler

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }


    // MARK: - vCard Import

//     private func importFromVCard(args: Any?, result: @escaping FlutterResult) {
//         // args expected: either {"vCard": "<string>"} or {"filePath": "<path>"}
//         DispatchQueue.global(qos: .userInitiated).async {
//             // Ensure we have contacts permission
//             let status = CNContactStore.authorizationStatus(for: .contacts)
//             guard status == .authorized else {
//                 // Attempt to request if not determined
//                 if status == .notDetermined {
//                     self.contactStore.requestAccess(for: .contacts) { granted, _ in
//                         DispatchQueue.main.async {
//                             if granted {
//                                 // recall import after permission granted
//                                 self.importFromVCard(args: args, result: result)
//                             } else {
//                                 result(FlutterError(code: "PERMISSION_DENIED", message: "Contacts permission denied", details: nil))
//                             }
//                         }
//                     }
//                     return
//                 } else {
//                     DispatchQueue.main.async {
//                         result(FlutterError(code: "PERMISSION_DENIED", message: "Contacts permission not granted", details: nil))
//                     }
//                     return
//                 }
//             }
//
//             // Read data from args
//             var vcardData: Data?
//
//             if let dict = args as? [String: Any] {
//                 if let vcardString = dict["vCard"] as? String {
//                     vcardData = vcardString.data(using: .utf8)
//                 } else if let filePath = dict["filePath"] as? String {
//                     // Try reading file
//                     let fileUrl = URL(fileURLWithPath: filePath)
//                     do {
//                         vcardData = try Data(contentsOf: fileUrl)
//                     } catch {
//                         DispatchQueue.main.async {
//                             result(FlutterError(code: "FILE_READ_ERROR", message: "Failed to read vCard file: \(error.localizedDescription)", details: nil))
//                         }
//                         return
//                     }
//                 }
//             }
//
//             guard let data = vcardData else {
//                 DispatchQueue.main.async {
//                     result(FlutterError(code: "INVALID_ARGUMENT", message: "vCard string or filePath is required", details: nil))
//                 }
//                 return
//             }
//
//             do {
//                 // Parse vCard into CNContact instances
//                 let parsedContacts = try CNContactVCardSerialization.contacts(with: data)
//
//                 // Prepare save request
//                 let saveRequest = CNSaveRequest()
//                 var savedContactsSerialized: [[String: Any]] = []
//
//                 for contact in parsedContacts {
//                     // Convert to mutable to save
//                     let mutable = contact.mutableCopy() as! CNMutableContact
//
//                     // Add to save request
//                     saveRequest.add(mutable, toContainerWithIdentifier: nil)
//
//                     // Serialize now (we'll adjust the id after saving since id isn't assigned until executed)
//                     // Use serializeContact but without image typed wrapper (we return raw data)
//                     var ser = self.serializeContact(contact, lite: false)
//                     // When saved, identifier will be present. We'll fix below after execute.
//                     savedContactsSerialized.append(ser)
//                 }
//
//                 // Execute save
//                 try self.contactStore.execute(saveRequest)
//
//                 // After saving, we should fetch fresh unified contacts by matching name/phone/email to get identifiers.
//                 // For robustness, re-serialize saved contacts by searching by unique attributes (e.g., name + phone)
//                 var finalSerialized: [[String: Any]] = []
//                 for contact in parsedContacts {
//                     // Build a small query to locate saved contact. Prefer phone if available.
//                     var matched: CNContact?
//                     if let firstPhone = contact.phoneNumbers.first?.value.stringValue {
//                         let predicate = CNContact.predicateForContacts(matching: CNPhoneNumber(stringValue: firstPhone))
//                         let keys: [CNKeyDescriptor] = [CNContactIdentifierKey as CNKeyDescriptor,
//                                                       CNContactGivenNameKey as CNKeyDescriptor,
//                                                       CNContactFamilyNameKey as CNKeyDescriptor,
//                                                       CNContactPhoneNumbersKey as CNKeyDescriptor,
//                                                       CNContactEmailAddressesKey as CNKeyDescriptor,
//                                                       CNContactImageDataKey as CNKeyDescriptor]
//                         let list = try self.contactStore.unifiedContacts(matching: predicate, keysToFetch: keys)
//                         if let first = list.first {
//                             matched = first
//                         }
//                     }
//
//                     // Fallback search by name
//                     if matched == nil {
//                         let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
//                         if !name.isEmpty {
//                             let predicate = CNContact.predicateForContacts(matchingName: name)
//                             let keys: [CNKeyDescriptor] = [CNContactIdentifierKey as CNKeyDescriptor,
//                                                           CNContactGivenNameKey as CNKeyDescriptor,
//                                                           CNContactFamilyNameKey as CNKeyDescriptor,
//                                                           CNContactPhoneNumbersKey as CNKeyDescriptor,
//                                                           CNContactEmailAddressesKey as CNKeyDescriptor,
//                                                           CNContactImageDataKey as CNKeyDescriptor]
//                             let list = try self.contactStore.unifiedContacts(matching: predicate, keysToFetch: keys)
//                             if let first = list.first {
//                                 matched = first
//                             }
//                         }
//                     }
//
//                     if let saved = matched {
//                         finalSerialized.append(self.serializeContact(saved, lite: false))
//                     } else {
//                         // If not found, fall back to the original serialized (without identifier)
//                         finalSerialized.append(self.serializeContact(contact, lite: false))
//                     }
//                 }
//
//                 DispatchQueue.main.async {
//                     result(finalSerialized)
//                 }
//             } catch let error as NSError {
//                 DispatchQueue.main.async {
//                     result(FlutterError(code: "VCARD_PARSE_ERROR", message: error.localizedDescription, details: nil))
//                 }
//             } catch {
//                 DispatchQueue.main.async {
//                     result(FlutterError(code: "UNKNOWN_ERROR", message: error.localizedDescription, details: nil))
//                 }
//             }
//         }
//     }

}

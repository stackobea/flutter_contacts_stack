
import Flutter
import UIKit
import Contacts

public class ContactsStackPlugin: NSObject, FlutterPlugin {
  let contactStore = CNContactStore()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "contacts_stack", binaryMessenger: registrar.messenger())
    let instance = ContactsStackPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "fetchContacts":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
        return
      }
      let withProperties = args["withProperties"] as? Bool ?? false
      let withPhoto = args["withPhoto"] as? Bool ?? false
      let batchSize = args["batchSize"] as? Int ?? 100
      let offset = args["offset"] as? Int ?? 0
      fetchContacts(withProperties: withProperties, withPhoto: withPhoto, batchSize: batchSize, offset: offset, result: result)

    case "getContactById":
      guard let args = call.arguments as? [String: Any],
            let id = args["id"] as? String else {
        result(FlutterError(code: "INVALID_ID", message: nil, details: nil))
        return
      }
      getContactById(id: id, result: result)

    case "insertContact":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
        return
      }
      insertContact(args: args, result: result)

    case "updateContact":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
        return
      }
      updateContact(args: args, result: result)

    case "deleteContact":
      guard let args = call.arguments as? [String: Any], let id = args["id"] as? String else {
        result(FlutterError(code: "INVALID_ID", message: nil, details: nil))
        return
      }
      deleteContact(id: id, result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func fetchContacts(withProperties: Bool, withPhoto: Bool, batchSize: Int, offset: Int, result: @escaping FlutterResult) {
    let keys: [CNKeyDescriptor] = [
      CNContactIdentifierKey as CNKeyDescriptor,
      CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
    ] + (withProperties ? [
      CNContactPhoneNumbersKey as CNKeyDescriptor,
      CNContactEmailAddressesKey as CNKeyDescriptor,
      CNContactOrganizationNameKey as CNKeyDescriptor,
      CNContactJobTitleKey as CNKeyDescriptor,
      CNContactNoteKey as CNKeyDescriptor,
      CNContactPostalAddressesKey as CNKeyDescriptor
    ] : []) + (withPhoto ? [CNContactImageDataKey as CNKeyDescriptor] : [])

    let request = CNContactFetchRequest(keysToFetch: keys)
    request.sortOrder = .userDefault
    var allContacts: [[String: Any?]] = []
    var currentIndex = 0

    do {
      try contactStore.enumerateContacts(with: request) { contact, _ in
        if currentIndex >= offset && allContacts.count < batchSize {
          allContacts.append(self.contactToMap(contact: contact, withProperties: withProperties, withPhoto: withPhoto))
        }
        currentIndex += 1
      }
      result(allContacts)
    } catch {
      result(FlutterError(code: "FETCH_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  private func getContactById(id: String, result: @escaping FlutterResult) {
    let keys: [CNKeyDescriptor] = [
      CNContactIdentifierKey as CNKeyDescriptor,
      CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
      CNContactPhoneNumbersKey as CNKeyDescriptor,
      CNContactEmailAddressesKey as CNKeyDescriptor,
      CNContactOrganizationNameKey as CNKeyDescriptor,
      CNContactJobTitleKey as CNKeyDescriptor,
      CNContactNoteKey as CNKeyDescriptor,
      CNContactPostalAddressesKey as CNKeyDescriptor,
      CNContactImageDataKey as CNKeyDescriptor
    ]

    do {
      let contact = try contactStore.unifiedContact(withIdentifier: id, keysToFetch: keys)
      let mapped = contactToMap(contact: contact, withProperties: true, withPhoto: true)
      result(mapped)
    } catch {
      result(nil)
    }
  }

  private func insertContact(args: [String: Any], result: @escaping FlutterResult) {
    let contact = CNMutableContact()
    fillContact(contact, from: args)
    let request = CNSaveRequest()
    request.add(contact, toContainerWithIdentifier: nil)

    do {
      try contactStore.execute(request)
      result(true)
    } catch {
      result(FlutterError(code: "INSERT_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  private func updateContact(args: [String: Any], result: @escaping FlutterResult) {
    guard let id = args["id"] as? String else {
      result(FlutterError(code: "INVALID_ID", message: nil, details: nil))
      return
    }
    do {
      let contact = try contactStore.unifiedContact(withIdentifier: id, keysToFetch: [CNContactViewController.descriptorForRequiredKeys()])
      let mutableContact = contact.mutableCopy() as! CNMutableContact
      fillContact(mutableContact, from: args)
      let request = CNSaveRequest()
      request.update(mutableContact)
      try contactStore.execute(request)
      result(true)
    } catch {
      result(FlutterError(code: "UPDATE_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  private func deleteContact(id: String, result: @escaping FlutterResult) {
    do {
      let contact = try contactStore.unifiedContact(withIdentifier: id, keysToFetch: [CNContactViewController.descriptorForRequiredKeys()])
      let mutableContact = contact.mutableCopy() as! CNMutableContact
      let request = CNSaveRequest()
      request.delete(mutableContact)
      try contactStore.execute(request)
      result(true)
    } catch {
      result(FlutterError(code: "DELETE_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  private func fillContact(_ contact: CNMutableContact, from args: [String: Any]) {
    contact.givenName = args["givenName"] as? String ?? ""
    contact.familyName = args["familyName"] as? String ?? ""
    contact.organizationName = args["company"] as? String ?? ""
    contact.jobTitle = args["jobTitle"] as? String ?? ""
    contact.note = args["note"] as? String ?? ""

    if let phones = args["phones"] as? [String] {
      contact.phoneNumbers = phones.map { CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: $0)) }
    }

    if let emails = args["emails"] as? [String] {
      contact.emailAddresses = emails.map { CNLabeledValue(label: CNLabelHome, value: $0 as NSString) }
    }

    if let photo = args["photo"] as? String, let data = Data(base64Encoded: photo) {
      contact.imageData = data
    }
  }

  private func contactToMap(contact: CNContact, withProperties: Bool, withPhoto: Bool) -> [String: Any?] {
    var map: [String: Any?] = [
      "id": contact.identifier,
      "displayName": CNContactFormatter.string(from: contact, style: .fullName) ?? ""
    ]

    if withProperties {
      map["phones"] = contact.phoneNumbers.map { $0.value.stringValue }
      map["emails"] = contact.emailAddresses.map { String($0.value) }
      map["company"] = contact.organizationName
      map["jobTitle"] = contact.jobTitle
      map["note"] = contact.note
      map["postalAddresses"] = contact.postalAddresses.map { $0.value.street }
    }

    if withPhoto, let imageData = contact.imageData {
      map["photo"] = imageData.base64EncodedString()
    }

    return map
  }
}

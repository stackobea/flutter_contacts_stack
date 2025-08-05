package com.stackobea.flutter_contacts_stack

import android.Manifest
import android.app.Activity
import android.content.ContentProviderOperation
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.util.Base64
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.util.*

enum class AccountType {
    SIM, GOOGLE, WHATSAPP, PHONE, OTHER
}



class ContactsStackPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var contentObserver: ContentObserver? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_contacts_stack")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> {
                val hasPermission = ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.READ_CONTACTS
                ) == PackageManager.PERMISSION_GRANTED
                result.success(hasPermission)
            }

            "requestPermission" -> {
                ActivityCompat.requestPermissions(
                    activity!!,
                    arrayOf(Manifest.permission.READ_CONTACTS, Manifest.permission.WRITE_CONTACTS),
                    1001
                )
                result.success(null)
            }

            "getContactsLite" -> {
                result.success(fetchContacts(false, false, 1000, 0))
            }

            "getContactsFull" -> {
                val withProperties = call.argument<Boolean>("withProperties") ?: true
                val withPhoto = call.argument<Boolean>("withPhoto") ?: true
                result.success(fetchContacts(withProperties, withPhoto, 1000, 0))
            }

            "getContactById" -> {
                val id = call.argument<String>("id")
                if (id != null) {
                    result.success(getContactById(id))
                } else {
                    result.error("INVALID_ARGUMENT", "Contact ID is null", null)
                }
            }

            "insertContact" -> {
                val contactMap = call.arguments as? Map<String, Any?>
                if (contactMap != null) {
                    val inserted = insertContact(contactMap)
                    result.success(inserted)
                } else {
                    result.error("INVALID_ARGUMENT", "Missing contact data", null)
                }
            }

            "updateContact" -> {
                val map = call.arguments as? Map<String, Any?>
                val id = map?.get("id") as? String
                if (map == null || id == null) {
                    result.error("INVALID_ARGUMENT", "Missing contact data or ID", null)
                    return
                }
                val deleted = deleteContact(id)
                val inserted = insertContact(map)
                result.success(deleted && inserted)
            }

            "deleteContact" -> {
                val id = call.argument<String>("id")
                result.success(id?.let { deleteContact(it) })
            }

            "importVCard" -> {
                val path = call.argument<String>("path")
                if (path != null) {
                    result.success(importVCard(path))
                } else {
                    result.error("INVALID_ARGUMENT", "Missing path to vCard", null)
                }
            }

            "exportVCard" -> {
                val id = call.argument<String>("id")
                if (id != null) {
                    result.success(exportVCard(id))
                } else {
                    result.error("INVALID_ARGUMENT", "Missing contact ID", null)
                }
            }

            "startObserver" -> {
                startContactObserver()
                result.success(true)
            }

            "stopObserver" -> {
                stopContactObserver()
                result.success(true)
            }

            "searchContacts" -> {
                val query = call.argument<String>("query") ?: ""
                result.success(searchContacts(query))
            }

            "getGroups" -> {
                result.success(getGroups())
            }

            "getContactsByAccountType" -> {
                val accountType = call.argument<String>("accountType") ?: ""
                result.success(getContactsByAccount(accountType))
            }

            "getMergeSuggestions" -> {
                result.success(getMergeSuggestions())
            }

            "getDeletedContacts" -> {
                result.success(getDeletedContacts())
            }

            else -> result.notImplemented()
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun startContactObserver() {
        if (contentObserver == null) {
            contentObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
                override fun onChange(selfChange: Boolean) {
                    channel.invokeMethod("onContactChanged", null)
                }
            }
            context.contentResolver.registerContentObserver(
                ContactsContract.Contacts.CONTENT_URI,
                true,
                contentObserver!!
            )
        }
    }

    private fun stopContactObserver() {
        contentObserver?.let {
            context.contentResolver.unregisterContentObserver(it)
            contentObserver = null
        }
    }

    private fun exportVCard(contactId: String): Boolean {
        val resolver = context.contentResolver
        val uri = Uri.withAppendedPath(
            ContactsContract.Contacts.CONTENT_VCARD_URI,
            contactId
        )
        return try {
            val inputStream: InputStream? = resolver.openInputStream(uri)
            if (inputStream != null) {
                val file = File(context.cacheDir, "$contactId.vcf")
                val output = FileOutputStream(file)
                inputStream.copyTo(output)
                inputStream.close()
                output.close()
                true
            } else false
        } catch (e: Exception) {
            false
        }
    }

    private fun importVCard(path: String): Boolean {
        return try {
            val uri = Uri.parse(path)
            val intent = Intent("com.android.contacts.action.IMPORT_VCARD")
            intent.setDataAndType(uri, "text/x-vcard")
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun searchContacts(query: String): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        val cursor = context.contentResolver.query(
            ContactsContract.Contacts.CONTENT_URI,
            null,
            "${ContactsContract.Contacts.DISPLAY_NAME_PRIMARY} LIKE ?",
            arrayOf("%$query%"),
            null
        )
        cursor?.use {
            while (it.moveToNext()) {
                val id = it.getString(it.getColumnIndexOrThrow(ContactsContract.Contacts._ID))
                val name =
                    it.getString(it.getColumnIndexOrThrow(ContactsContract.Contacts.DISPLAY_NAME))
                results.add(mapOf("id" to id, "displayName" to name))
            }
        }
        return results
    }

    private fun getGroups(): List<Map<String, String>> {
        val groups = mutableListOf<Map<String, String>>()
        val cursor = context.contentResolver.query(
            ContactsContract.Groups.CONTENT_URI,
            arrayOf(ContactsContract.Groups._ID, ContactsContract.Groups.TITLE),
            null,
            null,
            null
        )
        cursor?.use {
            while (it.moveToNext()) {
                val id = it.getString(it.getColumnIndexOrThrow(ContactsContract.Groups._ID))
                val title = it.getString(it.getColumnIndexOrThrow(ContactsContract.Groups.TITLE))
                groups.add(mapOf("id" to id, "title" to title))
            }
        }
        return groups
    }

    private fun getContactsByAccount(accountType: String): List<Map<String, Any?>> {
        val contacts = mutableListOf<Map<String, Any?>>()
        val selection = "${ContactsContract.RawContacts.ACCOUNT_TYPE} = ?"
        val cursor = context.contentResolver.query(
            ContactsContract.RawContacts.CONTENT_URI,
            arrayOf(ContactsContract.RawContacts.CONTACT_ID),
            selection,
            arrayOf(accountType),
            null
        )
        val ids = mutableSetOf<String>()
        cursor?.use {
            while (it.moveToNext()) {
                ids.add(it.getString(it.getColumnIndexOrThrow(ContactsContract.RawContacts.CONTACT_ID)))
            }
        }
        ids.forEach {
            getContactById(it)?.let { c -> contacts.add(c) }
        }
        return contacts
    }

    private fun getMergeSuggestions(): List<Map<String, String>> {
        val contacts = fetchContacts(true, false, 1000, 0)
        val suggestions = mutableListOf<Map<String, String>>()
        val seen = mutableSetOf<String>()
        for (i in contacts.indices) {
            val ci = contacts[i]
            val name1 = ci["displayName"] as? String ?: continue
            val phones1 = ci["phones"] as? List<String> ?: continue
            for (j in i + 1 until contacts.size) {
                val cj = contacts[j]
                val name2 = cj["displayName"] as? String ?: continue
                val phones2 = cj["phones"] as? List<String> ?: continue
                if (name1 == name2 || phones1.any { phones2.contains(it) }) {
                    val key = listOf(ci["id"], cj["id"]).sorted().joinToString("-")
                    if (!seen.contains(key)) {
                        suggestions.add(
                            mapOf(
                                "id1" to ci["id"].toString(),
                                "id2" to cj["id"].toString()
                            )
                        )
                        seen.add(key)
                    }
                }
            }
        }
        return suggestions
    }

    private fun getDeletedContacts(): List<Map<String, String>> {
        val deleted = mutableListOf<Map<String, String>>()
        val cursor = context.contentResolver.query(
            ContactsContract.RawContacts.CONTENT_URI,
            arrayOf(
                ContactsContract.RawContacts.CONTACT_ID,
                ContactsContract.RawContacts.DISPLAY_NAME_PRIMARY
            ),
            "${ContactsContract.RawContacts.DELETED} = 1",
            null,
            null
        )
        cursor?.use {
            while (it.moveToNext()) {
                val id =
                    it.getString(it.getColumnIndexOrThrow(ContactsContract.RawContacts.CONTACT_ID))
                val name =
                    it.getString(it.getColumnIndexOrThrow(ContactsContract.RawContacts.DISPLAY_NAME_PRIMARY))
                deleted.add(mapOf("id" to id, "displayName" to name))
            }
        }
        return deleted
    }

    // Existing insertContact, deleteContact, fetchContacts, etc. remain unchanged


    private fun insertContact(data: Map<String, Any?>?): Boolean {
        if (data == null || context == null) return false
        val ops = ArrayList<ContentProviderOperation>()

        val rawContactInsertIndex = ops.size
        ops.add(
            ContentProviderOperation.newInsert(ContactsContract.RawContacts.CONTENT_URI)
                .withValue(ContactsContract.RawContacts.ACCOUNT_TYPE, null)
                .withValue(ContactsContract.RawContacts.ACCOUNT_NAME, null)
                .build()
        )

        val displayName = data["displayName"] as? String ?: ""
        ops.add(
            ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, rawContactInsertIndex)
                .withValue(
                    ContactsContract.Data.MIMETYPE,
                    ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE
                )
                .withValue(
                    ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME,
                    displayName
                )
                .build()
        )

        (data["phones"] as? List<*>)?.forEach {
            ops.add(
                ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                    .withValueBackReference(
                        ContactsContract.Data.RAW_CONTACT_ID,
                        rawContactInsertIndex
                    )
                    .withValue(
                        ContactsContract.Data.MIMETYPE,
                        ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE
                    )
                    .withValue(ContactsContract.CommonDataKinds.Phone.NUMBER, it as String)
                    .withValue(
                        ContactsContract.CommonDataKinds.Phone.TYPE,
                        ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE
                    )
                    .build()
            )
        }

        (data["emails"] as? List<*>)?.forEach {
            ops.add(
                ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                    .withValueBackReference(
                        ContactsContract.Data.RAW_CONTACT_ID,
                        rawContactInsertIndex
                    )
                    .withValue(
                        ContactsContract.Data.MIMETYPE,
                        ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE
                    )
                    .withValue(ContactsContract.CommonDataKinds.Email.ADDRESS, it as String)
                    .withValue(
                        ContactsContract.CommonDataKinds.Email.TYPE,
                        ContactsContract.CommonDataKinds.Email.TYPE_HOME
                    )
                    .build()
            )
        }

        try {
            context!!.contentResolver.applyBatch(ContactsContract.AUTHORITY, ops)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return false
    }

    private fun deleteContact(contactId: String): Boolean {
        try {
            val uri = ContactsContract.RawContacts.CONTENT_URI
            val selection = "${ContactsContract.RawContacts.CONTACT_ID} = ?"
            val selectionArgs = arrayOf(contactId)
            val rows = context!!.contentResolver.delete(uri, selection, selectionArgs)
            return rows > 0
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return false
    }

    private fun fetchContacts(
        withProperties: Boolean,
        withPhoto: Boolean,
        batchSize: Int,
        offset: Int
    ): List<Map<String, Any?>> {
        val contacts = mutableListOf<Map<String, Any?>>()
        val resolver: ContentResolver = context!!.contentResolver

        val projection = arrayOf(
            ContactsContract.Contacts._ID,
            ContactsContract.Contacts.DISPLAY_NAME
        )

        val cursor = resolver.query(
            ContactsContract.Contacts.CONTENT_URI,
            projection,
            null,
            null,
            "${ContactsContract.Contacts.DISPLAY_NAME} ASC LIMIT $batchSize OFFSET $offset"
        )

        cursor?.use {
            while (it.moveToNext()) {
                val contactId =
                    it.getString(it.getColumnIndexOrThrow(ContactsContract.Contacts._ID))
                val displayName =
                    it.getString(it.getColumnIndexOrThrow(ContactsContract.Contacts.DISPLAY_NAME))
                val map =
                    mutableMapOf<String, Any?>("id" to contactId, "displayName" to displayName)

                if (withProperties) {
                    map["phones"] = fetchPhones(contactId)
                    map["emails"] = fetchEmails(contactId)
                }

                if (withPhoto) {
                    val photo = fetchPhoto(contactId)
                    if (photo != null) {
                        map["photo"] = Base64.encodeToString(photo, Base64.DEFAULT)
                    }
                }

                contacts.add(map)
            }
        }
        return contacts
    }

    private fun fetchPhones(contactId: String): List<String> {
        val phones = mutableListOf<String>()
        val resolver = context!!.contentResolver
        val cursor = resolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER),
            "${ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?",
            arrayOf(contactId),
            null
        )
        cursor?.use {
            while (it.moveToNext()) {
                phones.add(it.getString(it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER)))
            }
        }
        return phones
    }

    private fun fetchEmails(contactId: String): List<String> {
        val emails = mutableListOf<String>()
        val resolver = context!!.contentResolver
        val cursor = resolver.query(
            ContactsContract.CommonDataKinds.Email.CONTENT_URI,
            arrayOf(ContactsContract.CommonDataKinds.Email.ADDRESS),
            "${ContactsContract.CommonDataKinds.Email.CONTACT_ID} = ?",
            arrayOf(contactId),
            null
        )
        cursor?.use {
            while (it.moveToNext()) {
                emails.add(it.getString(it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Email.ADDRESS)))
            }
        }
        return emails
    }

    private fun fetchPhoto(contactId: String): ByteArray? {
        val resolver = context!!.contentResolver
        val photoUri = ContactsContract.Contacts.CONTENT_URI.buildUpon().appendPath(contactId)
            .appendPath(ContactsContract.Contacts.Photo.CONTENT_DIRECTORY).build()
        val cursor = resolver.query(
            photoUri,
            arrayOf(ContactsContract.Contacts.Photo.PHOTO),
            null,
            null,
            null
        )
        cursor?.use {
            if (it.moveToFirst()) {
                return it.getBlob(it.getColumnIndexOrThrow(ContactsContract.Contacts.Photo.PHOTO))
            }
        }
        return null
    }

    private fun getContactById(id: String): Map<String, Any?>? {
        return fetchContacts(true, true, 1, 0).firstOrNull { it["id"] == id }
    }

}





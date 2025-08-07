package com.stackobea.flutter_contacts_stack

import android.Manifest
import android.app.Activity
import android.content.ContentProviderOperation
import android.content.ContentResolver
import android.content.Context
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
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
import androidx.core.net.toUri
import android.util.Base64
import io.flutter.plugin.common.PluginRegistry


class ContactsStackPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var context: Context
    private var activity: Activity? = null
    private var contentObserver: ContentObserver? = null
    private lateinit var channel: MethodChannel
    private var permissionResult: MethodChannel.Result? = null


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
                val currentActivity = activity
                if (currentActivity != null) {
                    permissionResult = result
                    ActivityCompat.requestPermissions(
                        currentActivity,
                        arrayOf(
                            Manifest.permission.READ_CONTACTS,
                            Manifest.permission.WRITE_CONTACTS
                        ),
                        1001
                    )
                } else {
                    result.error("ACTIVITY_NULL", "Activity is null", null)
                }
            }


            "fetchContacts" -> {
                val withProperties = call.argument<Boolean>("withProperties") ?: false
                val withPhoto = call.argument<Boolean>("withPhoto") ?: false
                val batchSize = call.argument<Int>("batchSize") ?: 100
                val offset = call.argument<Int>("offset") ?: 0
                val contacts = fetchContacts(
                    withProperties = withProperties,
                    withPhoto = withPhoto,
                    batchSize = batchSize,
                    offset = offset
                )

                result.success(contacts)
            }

            "getContactsLite" -> {
                result.success(
                    fetchContacts(
                        withProperties = false,
                        withPhoto = false, batchSize = 1000, offset = 0
                    )
                )
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

//            "importFromVCard" -> {
//                val path = call.argument<String>("path")
//                if (path != null) {
//                    result.success(importVCard(path))
//                } else {
//                    result.error("INVALID_ARGUMENT", "Missing path to vCard", null)
//                }
//            }

            "exportToVCard" -> {
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

    private fun startContactObserver() {
        if (contentObserver == null) {
            contentObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
                override fun onChange(selfChange: Boolean) {
                    super.onChange(selfChange)

                    val projection = arrayOf(
                        ContactsContract.Contacts._ID,
                        ContactsContract.Contacts.DISPLAY_NAME
                    )

                    val cursor = context.contentResolver.query(
                        ContactsContract.Contacts.CONTENT_URI,
                        projection,
                        null,
                        null,
                        ContactsContract.Contacts.CONTACT_LAST_UPDATED_TIMESTAMP + " DESC LIMIT 30" // We can adjust as needed
                    )

                    val contactList = mutableListOf<Map<String, String>>()

                    cursor?.use {
                        val idIndex = it.getColumnIndex(ContactsContract.Contacts._ID)
                        val nameIndex = it.getColumnIndex(ContactsContract.Contacts.DISPLAY_NAME)

                        while (it.moveToNext()) {
                            if (idIndex != -1 && nameIndex != -1) {
                                val id = it.getString(idIndex)
                                val name = it.getString(nameIndex)
                                contactList.add(mapOf("id" to id, "name" to name))
                            }
                        }
                    }

                    if (contactList.isNotEmpty()) {
                        channel.invokeMethod("onContactChanged", contactList)
                    }
                }
            }

            context.contentResolver.registerContentObserver(
                ContactsContract.Contacts.CONTENT_URI,
                true,
                contentObserver as ContentObserver
            )
        }
    }

    private fun stopContactObserver() {
        contentObserver?.let {
            context.contentResolver?.unregisterContentObserver(it)
            contentObserver = null
        }
    }

    fun exportVCard(contactId: String): String? {
        val resolver = context.contentResolver

        val cursor = resolver.query(
            ContactsContract.Contacts.CONTENT_URI,
            arrayOf(ContactsContract.Contacts.LOOKUP_KEY),
            "${ContactsContract.Contacts._ID} = ?",
            arrayOf(contactId),
            null
        )

        if (cursor != null && cursor.moveToFirst()) {
            val lookupKey = cursor.getString(0)
            cursor.close()

            val uri = Uri.withAppendedPath(
                ContactsContract.Contacts.CONTENT_VCARD_URI,
                lookupKey
            )

            return try {
                val tempFile = File(context.cacheDir, "$contactId.vcf")
                resolver.openInputStream(uri)?.use { inputStream ->
                    FileOutputStream(tempFile).use { output ->
                        inputStream.copyTo(output)
                    }
                }

                val outputFile = File(context.getExternalFilesDir(null), "$contactId.vcf")
                tempFile.copyTo(outputFile, overwrite = true)

                // Return the path so you can use it later
                outputFile.absolutePath
            } catch (e: Exception) {
                e.printStackTrace()
                null
            }
        } else {
            cursor?.close()
            return null
        }
    }


//    private fun importVCard(path: String): Boolean {
//        return try {
//            val uri = path.toUri()
//            val intent = Intent("com.android.contacts.action.IMPORT_VCARD")
//            intent.setDataAndType(uri, "text/x-vcard")
//            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
//            context.startActivity(intent)
//            true
//        } catch (_: Exception) {
//            false
//        }
//    }

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
        val contacts = fetchContacts(
            withProperties = true,
            withPhoto = false,
            batchSize = 1000,
            offset = 0
        )
        val suggestions = mutableListOf<Map<String, String>>()
        val seen = mutableSetOf<String>()

        for (i in contacts.indices) {
            val ci = contacts[i]
            val name1 = ci["displayName"] as? String ?: continue
            val phones1 = ci["phones"] as? List<*> ?: continue

            for (j in i + 1 until contacts.size) {
                val cj = contacts[j]
                val name2 = cj["displayName"] as? String ?: continue
                val phones2 = cj["phones"] as? List<*> ?: continue

                if (name1 == name2 || phones1.any { phones2.contains(it) }) {
                    val id1 = ci["id"]?.toString() ?: continue
                    val id2 = cj["id"]?.toString() ?: continue
                    val key = listOf(id1, id2).sorted().joinToString("-")

                    if (!seen.contains(key)) {
                        suggestions.add(
                            mapOf("id1" to id1, "id2" to id2)
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

    private fun insertContact(data: Map<String, Any?>?): Boolean {
        if (data == null) return false
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
            context.contentResolver.applyBatch(ContactsContract.AUTHORITY, ops)
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
            val rows = context.contentResolver.delete(uri, selection, selectionArgs)
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
        val resolver: ContentResolver = context.contentResolver

        val projection = arrayOf(
            ContactsContract.Contacts._ID,
            ContactsContract.Contacts.DISPLAY_NAME
        )

        val cursor = resolver.query(
            ContactsContract.Contacts.CONTENT_URI,
            projection,
            null,
            null,
            "${ContactsContract.Contacts.DISPLAY_NAME} COLLATE NOCASE ASC LIMIT $batchSize OFFSET $offset"
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
        val resolver = context.contentResolver
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
        val resolver = context.contentResolver
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
        val resolver = context.contentResolver
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

//    private fun getContactById(id: String): Map<String, Any?>? {
//        return fetchContacts(
//            withProperties = true,
//            withPhoto = true,
//            batchSize = 1,
//            offset = 0
//        ).firstOrNull { it["id"] == id }
//    }

    private fun getContactById(id: String): Map<String, Any?>? {
        val resolver = context.contentResolver

        val contactUri = ContactsContract.Contacts.CONTENT_URI
        val cursor = resolver.query(
            contactUri,
            null,
            "${ContactsContract.Contacts._ID} = ?",
            arrayOf(id),
            null
        )

        cursor?.use {
            if (it.moveToFirst()) {
                val contactId =
                    it.getString(it.getColumnIndexOrThrow(ContactsContract.Contacts._ID))
                val displayName =
                    it.getString(it.getColumnIndexOrThrow(ContactsContract.Contacts.DISPLAY_NAME))

                val phones = mutableListOf<String>()
                val phoneCursor = resolver.query(
                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                    null,
                    "${ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?",
                    arrayOf(contactId),
                    null
                )
                phoneCursor?.use { pc ->
                    while (pc.moveToNext()) {
                        val phone =
                            pc.getString(pc.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER))
                        phones.add(phone)
                    }
                }

                val emails = mutableListOf<String>()
                val emailCursor = resolver.query(
                    ContactsContract.CommonDataKinds.Email.CONTENT_URI,
                    null,
                    "${ContactsContract.CommonDataKinds.Email.CONTACT_ID} = ?",
                    arrayOf(contactId),
                    null
                )
                emailCursor?.use { ec ->
                    while (ec.moveToNext()) {
                        val email =
                            ec.getString(ec.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Email.ADDRESS))
                        emails.add(email)
                    }
                }

                // Fetch photo (if any)
                val photoUri =
                    it.getString(it.getColumnIndexOrThrow(ContactsContract.Contacts.PHOTO_URI))
                val photoBase64 = photoUri?.let { uri ->
                    try {
                        val inputStream = resolver.openInputStream(uri.toUri())
                        val bytes = inputStream?.readBytes()
                        inputStream?.close()
                        bytes?.let { Base64.encodeToString(it, Base64.NO_WRAP) }
                    } catch (_: Exception) {
                        null
                    }
                }

                return mapOf(
                    "id" to contactId,
                    "displayName" to displayName,
                    "phones" to phones,
                    "emails" to emails,
                    "photo" to photoBase64
                )
            }
        }

        return null
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == 1001) {
            val granted =
                grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            permissionResult?.success(granted)
            permissionResult = null
            return true
        }
        return false
    }
}
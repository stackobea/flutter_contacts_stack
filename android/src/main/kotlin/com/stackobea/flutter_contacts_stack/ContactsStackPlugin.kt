package com.stackobea.flutter_contacts_stack

import android.app.Activity
import android.content.ContentProviderOperation
import android.content.ContentResolver
import android.content.Context
import android.provider.ContactsContract
import android.util.Base64
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class ContactsStackPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "contacts_stack")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "fetchContacts" -> {
                val withProperties = call.argument<Boolean>("withProperties") ?: false
                val withPhoto = call.argument<Boolean>("withPhoto") ?: false
                val batchSize = call.argument<Int>("batchSize") ?: 100
                val offset = call.argument<Int>("offset") ?: 0
                val contacts = fetchContacts(withProperties, withPhoto, batchSize, offset)
                result.success(contacts)
            }

            "getContactById" -> {
                val id = call.argument<String>("id") ?: return result.error(
                    "INVALID_ID",
                    "Contact ID is null",
                    null
                )
                val contact = getContactById(id)
                result.success(contact)
            }

            "insertContact" -> {
                val map = call.arguments as? Map<String, Any?>
                result.success(insertContact(map))
            }

            "updateContact" -> {
                // TODO: Implement update contact
                result.notImplemented()
            }

            "deleteContact" -> {
                val id = call.argument<String>("id") ?: return result.error(
                    "INVALID_ID",
                    "Contact ID is null",
                    null
                )
                val deleted = deleteContact(id)
                result.success(deleted)
            }

            else -> result.notImplemented()
        }
    }

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

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }
}


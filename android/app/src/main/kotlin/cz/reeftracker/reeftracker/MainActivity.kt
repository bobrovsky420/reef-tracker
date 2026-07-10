package cz.reeftracker.reeftracker

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Hosts the `cloud_folder` MethodChannel: a minimal Storage Access Framework
 * wrapper for the cloud-folder backup sync (U20). Implemented in-house instead
 * of a third-party SAF plugin deliberately — the pinned plugin trio (TODO #50)
 * shows how stale plugin releases break against this project's AGP/Kotlin
 * toolchain, and this file compiles with the project's own toolchain forever.
 *
 * Contract (all names are display names inside the picked tree, no paths):
 *  - pickFolder()                     -> {uri, name} or null when cancelled
 *  - checkAccess(uri)                 -> bool (persisted grant still valid)
 *  - list(uri)                        -> [{name, modified, size}] files only
 *  - read(uri, name)                  -> bytes
 *  - write(uri, name, bytes)          -> overwrites or creates
 *  - delete(uri, name)                -> no-op when absent
 * I/O failures surface as PlatformException(code = "io").
 */
class MainActivity : FlutterActivity() {
    private var pendingPickResult: MethodChannel.Result? = null

    // Document providers can be network-backed (Drive, Dropbox) — never run
    // their I/O on the platform thread. Single lane: the Dart side already
    // serializes pushes, and ordered list/read/delete is what prune expects.
    private val io = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFolder" -> pickFolder(result)
                    "checkAccess" -> onIo(result) { checkAccess(treeUri(call)) }
                    "list" -> onIo(result) { list(treeUri(call)) }
                    "read" -> onIo(result) { read(treeUri(call), nameArg(call)) }
                    "write" -> {
                        val bytes = call.argument<ByteArray>("bytes")!!
                        onIo(result) { write(treeUri(call), nameArg(call), bytes) }
                    }
                    "delete" -> onIo(result) { delete(treeUri(call), nameArg(call)) }
                    else -> result.notImplemented()
                }
            }
    }

    // --- pick ---------------------------------------------------------------

    private fun pickFolder(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("busy", "folder picker already open", null)
            return
        }
        pendingPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        )
        try {
            startActivityForResult(intent, PICK_FOLDER_REQUEST)
        } catch (e: Exception) {
            pendingPickResult = null
            result.error("io", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != PICK_FOLDER_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingPickResult ?: return
        pendingPickResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null) // cancelled
            return
        }
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
            // The app only ever uses one folder; drop grants for older picks
            // so abandoned folders don't accumulate persisted permissions.
            contentResolver.persistedUriPermissions
                .filter { it.uri != uri }
                .forEach {
                    try {
                        contentResolver.releasePersistableUriPermission(
                            it.uri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                        )
                    } catch (_: Exception) {
                        // Best-effort cleanup; the new grant is what matters.
                    }
                }
            val name = DocumentFile.fromTreeUri(this, uri)?.name ?: uri.lastPathSegment
            result.success(mapOf("uri" to uri.toString(), "name" to name))
        } catch (e: Exception) {
            result.error("io", e.message, null)
        }
    }

    // --- document ops (io thread) --------------------------------------------

    private fun checkAccess(uri: Uri): Boolean {
        val granted = contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission && it.isWritePermission
        }
        if (!granted) return false
        val dir = DocumentFile.fromTreeUri(this, uri) ?: return false
        return dir.exists() && dir.canWrite()
    }

    private fun list(uri: Uri): List<Map<String, Any?>> =
        dir(uri).listFiles()
            .filter { it.isFile }
            .map {
                mapOf(
                    "name" to it.name,
                    "modified" to it.lastModified(),
                    "size" to it.length()
                )
            }

    private fun read(uri: Uri, name: String): ByteArray {
        val file = dir(uri).findFile(name)
            ?: throw IllegalStateException("file not found: $name")
        return contentResolver.openInputStream(file.uri)!!.use { it.readBytes() }
    }

    private fun write(uri: Uri, name: String, bytes: ByteArray): Any? {
        val folder = dir(uri)
        // findFile-then-overwrite instead of blind createFile: SAF createFile
        // dedupes a name collision to "name (1)", which would escape the
        // prefix-based listing forever.
        val target = folder.findFile(name)
            ?: folder.createFile("application/json", name)
            ?: throw IllegalStateException("could not create $name")
        // "wt" truncates; without it a shorter rewrite leaves a trailing tail
        // of the old content.
        contentResolver.openOutputStream(target.uri, "wt")!!.use {
            it.write(bytes)
            it.flush()
        }
        return null
    }

    private fun delete(uri: Uri, name: String): Any? {
        dir(uri).findFile(name)?.delete()
        return null
    }

    // --- helpers --------------------------------------------------------------

    private fun dir(uri: Uri): DocumentFile =
        DocumentFile.fromTreeUri(this, uri)
            ?: throw IllegalStateException("not a tree uri: $uri")

    private fun treeUri(call: io.flutter.plugin.common.MethodCall): Uri =
        Uri.parse(call.argument<String>("uri")!!)

    private fun nameArg(call: io.flutter.plugin.common.MethodCall): String =
        call.argument<String>("name")!!

    /** Runs [op] on the io executor and posts its result/error back to the
     * platform thread (MethodChannel results must be delivered there). */
    private fun onIo(result: MethodChannel.Result, op: () -> Any?) {
        io.execute {
            try {
                val value = op()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post { result.error("io", e.message, null) }
            }
        }
    }

    companion object {
        private const val CHANNEL = "cz.reeftracker.reeftracker/cloud_folder"
        private const val PICK_FOLDER_REQUEST = 0xC10D
    }
}

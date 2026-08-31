package com.xiaoluo.xiaoluo_diary

import android.app.Activity
import android.content.Intent
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val SAVE_FILE_REQUEST_CODE = 4317
    }

    private var pendingResult: MethodChannel.Result? = null
    private var pendingSourcePath: String? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAVE_FILE_REQUEST_CODE) return
        val result = pendingResult
        val sourcePath = pendingSourcePath
        pendingResult = null
        pendingSourcePath = null
        if (resultCode != Activity.RESULT_OK || data?.data == null || sourcePath == null) {
            result?.success(null)
            return
        }
        val target = data.data!!
        Thread {
            try {
                FileInputStream(File(sourcePath)).use { input ->
                    contentResolver.openOutputStream(target, "w")!!.use { output ->
                        input.copyTo(output, 1024 * 1024)
                    }
                }
                runOnUiThread { result?.success(target.toString()) }
            } catch (error: Exception) {
                runOnUiThread {
                    result?.error("SAVE_FAILED", error.message ?: "保存失败", null)
                }
            }
        }.start()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "xiaoluo_diary/files")
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                if (call.method == "saveMediaToGallery") {
                    saveMediaToGallery(call, result)
                    return@setMethodCallHandler
                }
                if (call.method != "saveFile") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingResult != null) {
                    result.error("SAVE_BUSY", "已有保存窗口正在打开", null)
                    return@setMethodCallHandler
                }
                val sourcePath = call.argument<String>("sourcePath")
                val fileName = call.argument<String>("fileName")
                val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                if (sourcePath.isNullOrBlank() || fileName.isNullOrBlank()) {
                    result.error("BAD_ARGUMENT", "导出文件参数不完整", null)
                    return@setMethodCallHandler
                }
                pendingResult = result
                pendingSourcePath = sourcePath
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = mimeType
                    putExtra(Intent.EXTRA_TITLE, fileName)
                    addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                }
                startActivityForResult(intent, SAVE_FILE_REQUEST_CODE)
            }
    }

    private fun saveMediaToGallery(call: MethodCall, result: MethodChannel.Result) {
        val sourcePath = call.argument<String>("sourcePath")
        val isVideo = call.argument<Boolean>("isVideo") ?: false
        if (sourcePath.isNullOrBlank()) {
            result.error("BAD_ARGUMENT", "媒体文件路径为空", null)
            return
        }
        Thread {
            try {
                val source = File(sourcePath)
                val collection = if (isVideo) {
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                } else {
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                }
                val mime = if (isVideo) "video/mp4" else "image/jpeg"
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, source.name)
                    put(MediaStore.MediaColumns.MIME_TYPE, mime)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        put(
                            MediaStore.MediaColumns.RELATIVE_PATH,
                            if (isVideo) Environment.DIRECTORY_MOVIES + "/小罗日记"
                            else Environment.DIRECTORY_PICTURES + "/小罗日记"
                        )
                        put(MediaStore.MediaColumns.IS_PENDING, 1)
                    }
                }
                val uri = contentResolver.insert(collection, values)
                    ?: throw IllegalStateException("无法创建相册文件")
                contentResolver.openOutputStream(uri, "w")!!.use { output ->
                    FileInputStream(source).use { input -> input.copyTo(output, 1024 * 1024) }
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    values.clear()
                    values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    contentResolver.update(uri, values, null, null)
                }
                runOnUiThread { result.success(true) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("GALLERY_SAVE_FAILED", error.message ?: "保存相册失败", null)
                }
            }
        }.start()
    }
}

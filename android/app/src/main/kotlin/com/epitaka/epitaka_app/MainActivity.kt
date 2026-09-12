package com.dn.epitaka

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.InputStream

class MainActivity : FlutterActivity() {
    // TTS lifecycle ownership:
    // - Dart `TtsNotifier` owns the speech engines, `TtsReadingNotifier`
    //   owns the reading session + notification callbacks.
    // - This Activity only (a) shares the engine via the cache so
    //   audio_service reuses it, and (b) guarantees speech stops when the
    //   app task is swiped away (system TTS would otherwise finish the
    //   queued utterance after the Dart isolate is gone).
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        // Never `new FlutterEngine()` here: the FlutterLoader is not yet
        // initialized at this point, so manual creation crashes on cold
        // start (`FlutterLoader.ensureInitializationComplete:533`
        // RuntimeException, seen in Play Console v28). Returning the cached
        // engine — or null so FlutterActivity creates it correctly —
        // shares the engine without the crash.
        return FlutterEngineCache.getInstance().get(engineId)
    }

    override fun onDestroy() {
        // Swipe-kill: stop the audio foreground service so the notification
        // goes away with the task. The Dart `detached` handler stops the
        // speech engines themselves.
        try {
            stopService(Intent(this, Class.forName("com.ryanheise.audioservice.AudioService")))
        } catch (_: Exception) {
        }
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Share the correctly-initialized engine with audio_service.
        // First launch: provideFlutterEngine returned null, FlutterActivity
        // created this engine safely — cache it now for reuse.
        if (FlutterEngineCache.getInstance().get(engineId) == null) {
            FlutterEngineCache.getInstance().put(engineId, flutterEngine)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "copyCoreDatabases" -> {
                        val destDir = call.argument<String>("destDir")
                        if (destDir == null) {
                            result.error("BAD_ARGS", "destDir required", null)
                            return@setMethodCallHandler
                        }
                        // The DBs total ~700 MB — copying them on the platform
                        // main thread at cold start could exceed the ANR
                        // window. Do the copy on a background thread and post
                        // the result back on the main thread.
                        val target = File(destDir)
                        Thread {
                            try {
                                val copied = copyCoreDatabases(target)
                                runOnUiThread { result.success(copied) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("COPY_FAILED", e.message, null)
                                }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TTS_SETTINGS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openTtsSettings" -> {
                        // Official Android TTS settings screen (voice
                        // install/manage). url_launcher can't launch this —
                        // it only does ACTION_VIEW — so expose it natively.
                        try {
                            // There is no public Settings.ACTION_TTS_SETTINGS
                            // constant in the Android SDK — the Settings app
                            // registers this action string directly.
                            startActivity(Intent("com.android.settings.TTS_SETTINGS"))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("LAUNCH_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROCESS_TEXT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "queryProcessTextApps" -> {
                        val apps = queryProcessTextApps()
                        result.success(apps)
                    }
                    "launchProcessTextApp" -> {
                        val packageName = call.argument<String>("packageName")
                        val text = call.argument<String>("text") ?: ""
                        if (packageName == null || text.isEmpty()) {
                            result.error("BAD_ARGS", "packageName and text required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            startActivity(processTextIntent(packageName, text))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("LAUNCH_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Queries installed apps that handle [Intent.ACTION_PROCESS_TEXT] with a
     * `text/plain` type (dictionaries, translators, note apps, …) and returns
     * them as a list of `{packageName, label}` maps.
     */
    private fun queryProcessTextApps(): List<Map<String, String>> {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PackageManager.MATCH_ALL.toLong()
        } else {
            0L
        }
        val intent = Intent(Intent.ACTION_PROCESS_TEXT).apply {
            type = "text/plain"
        }
        val infos: List<ResolveInfo> =
            packageManager.queryIntentActivities(intent, flags.toInt())
        return infos.mapNotNull { info ->
            val pkg = info.activityInfo?.packageName ?: return@mapNotNull null
            val label = info.loadLabel(packageManager)?.toString() ?: pkg
            mapOf("packageName" to pkg, "label" to label)
        }.distinctBy { it["packageName"] }
    }

    /** Builds an ACTION_PROCESS_TEXT intent targeting [packageName]. */
    private fun processTextIntent(packageName: String, text: String): Intent {
        return Intent(Intent.ACTION_PROCESS_TEXT).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_PROCESS_TEXT, text)
            setPackage(packageName)
        }
    }

    /**
     * Copies the core databases (epitaka.db, epitaka_en.db, dpd-dictionary.db)
     * from the install-time Play Asset Delivery pack ("core_db") into [destDir] on
     * first launch.
     *
     * Install-time asset packs ship inside the AAB and are immediately
     * readable via the standard Android AssetManager — no Play Core library
     * is required. Returns the list of filenames that were copied (files that
     * already exist are left untouched). This method runs on a background
     * thread (see the copyCoreDatabases channel handler).
     */
    private fun copyCoreDatabases(destDir: File): List<String> {
        if (!destDir.exists()) destDir.mkdirs()
        Log.i(TAG, "copyCoreDatabases → ${destDir.absolutePath}")
        val copied = mutableListOf<String>()
        for (name in CORE_DB_FILES) {
            val dest = File(destDir, name)
            if (dest.exists() && dest.length() > 0) {
                Log.i(TAG, "$name already present (${dest.length()} bytes), skipping")
                continue
            }
            val input = openAsset(name)
            if (input == null) {
                Log.w(TAG, "$name not in asset pack; will fall back to download")
                continue
            }
            input.use { ins ->
                dest.outputStream().use { out -> ins.copyTo(out) }
            }
            Log.i(TAG, "copied $name (${dest.length()} bytes)")
            copied.add(name)
        }
        return copied
    }

    /**
     * Opens a file from the install-time asset pack via the standard
     * AssetManager.
     *
     * The addressable path varies with how the app was packaged: an AAB
     * installed via Play exposes the pack content by bare name, while a
     * sideloaded APK (`flutter build apk`) merges it under different
     * prefixes. All known layouts are tried, then the asset tree is listed
     * to discover the file wherever it actually landed.
     */
    private fun openAsset(name: String): InputStream? {
        val assetManager = assets
        for (candidate in assetCandidates(name)) {
            try {
                return assetManager.open(candidate)
            } catch (_: Exception) {
                // try next candidate
            }
        }
        val found = findAssetByName(name)
        if (found != null) {
            try {
                return assetManager.open(found)
            } catch (e: Exception) {
                Log.w(TAG, "openAsset: discovered $found but open failed: $e")
            }
        }
        Log.w(TAG, "openAsset: $name not found. roots=${listAssetDir("")}")
        return null
    }

    private fun assetCandidates(name: String): List<String> {
        return listOf(
            name,
            "core_db/$name",
            "assetpacks/core_db/$name",
            "assetpacks/core_db/assets/$name",
            "assets/core_db/$name",
            "flutter_assets/assets/db/$name",
            "flutter_assets/$name",
        )
    }

    private fun listAssetDir(path: String): List<String> {
        return try {
            assets.list(path)?.toList() ?: emptyList()
        } catch (_: Exception) {
            emptyList()
        }
    }

    /**
     * Searches the asset tree (breadth-first, bounded depth) for a file
     * with the exact [name], returning its full asset path when found.
     */
    private fun findAssetByName(name: String): String? {
        val queue = ArrayDeque<String>()
        queue.add("")
        var steps = 0
        while (queue.isNotEmpty() && steps < 60) {
            steps++
            val dir = queue.removeFirst()
            val entries = listAssetDir(dir)
            for (entry in entries) {
                val full = if (dir.isEmpty()) entry else "$dir/$entry"
                if (entry == name) return full
                if (entry.contains('.')) continue
                queue.add(full)
            }
        }
        return null
    }

    companion object {
        private const val engineId = "audio_service_engine"
        private const val TAG = "EPITAKA_ASSET_PACK"
        private const val CHANNEL = "epitaka/asset_pack"
        private const val PROCESS_TEXT_CHANNEL = "epitaka/process_text"
        private const val TTS_SETTINGS_CHANNEL = "epitaka/tts_settings"
        private val CORE_DB_FILES = listOf("epitaka.db", "epitaka_en.db", "dpd-dictionary.db")
    }
}

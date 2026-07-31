package com.dn.epitaka

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.InputStream

class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        // audio_service expects a shared FlutterEngine cached under the key
        // "audio_service_engine". Without this override, FlutterActivity
        // creates its own engine while audio_service creates a separate
        // background engine, causing:
        //
        //   IllegalStateException: The Activity class declared in your
        //   AndroidManifest.xml is wrong or has not provided the correct
        //   FlutterEngine.
        //
        // By creating the engine here and caching it under the expected
        // key, both the Activity and audio_service share the same engine.
        val engineId = "audio_service_engine"
        var engine = FlutterEngineCache.getInstance().get(engineId)
        if (engine == null) {
            engine = FlutterEngine(context)
            // Don't execute the Dart entrypoint here — FlutterActivity
            // will do that after provideFlutterEngine() returns. We only
            // need to create + cache the engine so that audio_service's
            // getFlutterEngine() finds it and reuses it instead of
            // creating a second, incompatible engine.
            FlutterEngineCache.getInstance().put(engineId, engine)
        }
        return engine
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
    }

    /**
     * Copies the two core databases (epitaka.db, dpd-dictionary.db) from the
     * install-time Play Asset Delivery pack ("core_db") into [destDir] on
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
        val copied = mutableListOf<String>()
        for (name in CORE_DB_FILES) {
            val dest = File(destDir, name)
            if (dest.exists()) continue // already present — never overwrite
            val input = openAsset(name) ?: continue // pack not available
            input.use { ins ->
                dest.outputStream().use { out -> ins.copyTo(out) }
            }
            copied.add(name)
        }
        return copied
    }

    /**
     * Opens a file from the install-time asset pack via the standard
     * AssetManager. Depending on the bundletool version the file may be
     * addressable by its bare name, or prefixed with the pack name — try the
     * common layouts defensively.
     */
    private fun openAsset(name: String): InputStream? {
        val assetManager = assets
        for (candidate in listOf(name, "core_db/$name", "assets/core_db/$name")) {
            try {
                return assetManager.open(candidate)
            } catch (_: Exception) {
                // try next candidate
            }
        }
        return null
    }

    companion object {
        private const val CHANNEL = "epitaka/asset_pack"
        private val CORE_DB_FILES = listOf("epitaka.db", "dpd-dictionary.db")
    }
}

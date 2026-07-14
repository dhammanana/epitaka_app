package com.epitaka.epitaka_app

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

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
}

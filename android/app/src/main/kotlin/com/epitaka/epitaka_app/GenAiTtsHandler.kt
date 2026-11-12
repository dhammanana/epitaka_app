package com.dn.epitaka

import android.content.Context
import android.media.AudioAttributes
import android.util.Log
import com.google.mlkit.genai.common.DownloadStatus
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.texttospeech.SpeechSynthesis
import com.google.mlkit.genai.texttospeech.SpeechSynthesizer
import com.google.mlkit.genai.texttospeech.SpeechSynthesizerRequest
import com.google.mlkit.genai.texttospeech.SpeechSynthesizerResponse
import com.google.mlkit.genai.texttospeech.VoiceInfo
import com.google.mlkit.genai.texttospeech.speechSynthesizerOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Bridges Google's on-device GenAI Text-to-Speech SDK
 * (`com.google.mlkit:genai-text-to-speech`) to Dart.
 *
 * Channel: `epitaka/genai_tts`
 *   - `isAvailable {language}` -> String status, so Dart can explain *why* a
 *     voice is unusable instead of blaming the language for everything:
 *       "available"          ready to speak now
 *       "downloadable"       this phone supports it, the voice needs a download
 *       "downloading"        that download is in progress
 *       "languageUnsupported" the SDK has no voice for this language
 *       "deviceUnsupported"  this phone model is not supported
 *       "unknown"            the check itself failed
 *   - `download {language}` -> same status string, starting the voice download
 *     when the status is "downloadable".
 *   - `speak {text, language}` -> String: "started" | "downloading" |
 *     "unavailable". The SDK plays the audio itself (the request carries
 *     AudioAttributes), so only status changes are forwarded to Dart:
 *     `onStart`, `onDone`, `onError`, `onVoiceReady`.
 *   - `stop` -> Boolean
 *   - `release` -> Boolean (Activity teardown)
 *
 * Everything is guarded: unsupported devices, missing/outdated Speech Services
 * and unsupported locales all resolve as "unavailable" so Dart can fall back
 * to the system TTS engine.
 */
class GenAiTtsHandler(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var client: SpeechSynthesizer? = null
    private var clientLocale: Locale? = null
    private var synthesisJob: Job? = null
    private var downloadJob: Job? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> {
                val language = call.argument<String>("language") ?: DEFAULT_LANGUAGE
                scope.launch { result.success(voiceStatus(language)) }
            }

            "download" -> {
                val language = call.argument<String>("language") ?: DEFAULT_LANGUAGE
                scope.launch { result.success(downloadVoices(language)) }
            }

            "speak" -> {
                val text = call.argument<String>("text")
                val language = call.argument<String>("language") ?: DEFAULT_LANGUAGE
                if (text.isNullOrBlank()) {
                    result.error("BAD_ARGS", "text required", null)
                    return
                }
                scope.launch { result.success(speak(text, language)) }
            }

            "stop" -> {
                stopSpeech()
                result.success(true)
            }

            "release" -> {
                release()
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Why the voice for [languageTag] is (not) usable. Distinguishing these
     * matters: most phones simply are not supported, while a supported phone
     * only needs to download the model once.
     */
    private suspend fun voiceStatus(languageTag: String): String {
        val locale = localeFor(languageTag)
        return try {
            val synthesizer = clientFor(locale)
            val voices = synthesizer.getSupportedVoices(locale)
            val voice = voices.firstOrNull() ?: return STATUS_LANGUAGE_UNSUPPORTED
            when (synthesizer.checkStatus(voice)) {
                FeatureStatus.AVAILABLE -> STATUS_AVAILABLE
                FeatureStatus.DOWNLOADABLE -> STATUS_DOWNLOADABLE
                FeatureStatus.DOWNLOADING -> STATUS_DOWNLOADING
                else -> STATUS_DEVICE_UNSUPPORTED
            }
        } catch (e: Exception) {
            Log.w(TAG, "voiceStatus($languageTag) failed: $e")
            STATUS_UNKNOWN
        }
    }

    /** Starts the voice model download and reports the resulting status. */
    private suspend fun downloadVoices(languageTag: String): String {
        val locale = localeFor(languageTag)
        return try {
            val synthesizer = clientFor(locale)
            val voice = firstVoice(synthesizer, locale)
                ?: return STATUS_LANGUAGE_UNSUPPORTED
            when (synthesizer.checkStatus(voice)) {
                FeatureStatus.AVAILABLE -> STATUS_AVAILABLE
                FeatureStatus.DOWNLOADING -> STATUS_DOWNLOADING
                FeatureStatus.DOWNLOADABLE -> {
                    startDownload(synthesizer, voice)
                    STATUS_DOWNLOADING
                }
                else -> STATUS_DEVICE_UNSUPPORTED
            }
        } catch (e: Exception) {
            Log.w(TAG, "download($languageTag) failed: $e")
            STATUS_UNKNOWN
        }
    }

    private suspend fun speak(text: String, languageTag: String): String {
        return try {
            val locale = localeFor(languageTag)
            val synthesizer = clientFor(locale)
            val voice = firstVoice(synthesizer, locale) ?: return UNAVAILABLE
            when (synthesizer.checkStatus(voice)) {
                FeatureStatus.AVAILABLE -> {
                    startSynthesis(synthesizer, text, voice)
                    "started"
                }
                // Kick the model download off in the background and let the
                // caller fall back to the system voice meanwhile.
                FeatureStatus.DOWNLOADABLE, FeatureStatus.DOWNLOADING -> {
                    startDownload(synthesizer, voice)
                    "downloading"
                }
                else -> UNAVAILABLE
            }
        } catch (e: Exception) {
            Log.w(TAG, "speak($languageTag) failed: $e")
            UNAVAILABLE
        }
    }

    private fun localeFor(languageTag: String): Locale =
        Locale.forLanguageTag(languageTag).takeIf { it.language.isNotEmpty() }
            ?: Locale.US

    /**
     * One client serves every language; the locale only selects the default
     * voice list. Rebuild it when the requested locale changes so
     * `getSupportedVoices()` returns that language's voices.
     */
    private fun clientFor(locale: Locale): SpeechSynthesizer {
        val current = client
        if (current != null && clientLocale == locale) return current
        stopSpeech()
        try {
            current?.close()
        } catch (e: Exception) {
            Log.w(TAG, "closing previous client failed: $e")
        }
        val options = speechSynthesizerOptions(locale) {
            // Let the SDK fall back to a related voice instead of failing.
            setVoiceFallbackEnabled(true)
        }
        val fresh = SpeechSynthesis.getClient(options)
        client = fresh
        clientLocale = locale
        return fresh
    }

    private suspend fun firstVoice(
        synthesizer: SpeechSynthesizer,
        locale: Locale,
    ): VoiceInfo? = try {
        synthesizer.getSupportedVoices(locale).firstOrNull()
    } catch (e: Exception) {
        Log.w(TAG, "getSupportedVoices($locale) failed: $e")
        null
    }

    private fun startSynthesis(
        synthesizer: SpeechSynthesizer,
        text: String,
        voice: VoiceInfo,
    ) {
        synthesisJob?.cancel()
        synthesisJob = scope.launch {
            val request = SpeechSynthesizerRequest(
                input = SpeechSynthesizerRequest.Input.Text(text, voice),
                audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
                queueMode = SpeechSynthesizerRequest.QueueMode.QUEUE_FLUSH,
            )
            try {
                synthesizer.synthesize(request).collect { response ->
                    when (response) {
                        is SpeechSynthesizerResponse.StatusUpdate -> {
                            when (response.status) {
                                SpeechSynthesizerResponse.Status.START ->
                                    channel.invokeMethod("onStart", null)
                                SpeechSynthesizerResponse.Status.DONE ->
                                    channel.invokeMethod("onDone", null)
                                else -> {}
                            }
                        }
                        is SpeechSynthesizerResponse.Error ->
                            channel.invokeMethod("onError", response.errorCode)
                        else -> {}
                    }
                }
            } catch (e: CancellationException) {
                // stop()/release() cancelled the flow — nothing to report.
            } catch (e: Exception) {
                Log.w(TAG, "synthesis failed: $e")
                channel.invokeMethod("onError", e.message)
            }
        }
    }

    private fun startDownload(synthesizer: SpeechSynthesizer, voice: VoiceInfo) {
        if (downloadJob?.isActive == true) return
        downloadJob = scope.launch {
            try {
                synthesizer.download(voice).collect { status ->
                    when (status) {
                        is DownloadStatus.DownloadCompleted ->
                            channel.invokeMethod("onVoiceReady", null)
                        is DownloadStatus.DownloadFailed ->
                            Log.w(TAG, "voice download failed: ${status.e.message}")
                        else -> {}
                    }
                }
            } catch (e: CancellationException) {
                // Cancelled by release().
            } catch (e: Exception) {
                Log.w(TAG, "voice download failed: $e")
            }
        }
    }

    private fun stopSpeech() {
        synthesisJob?.cancel()
        synthesisJob = null
        try {
            client?.stop()
        } catch (e: Exception) {
            Log.w(TAG, "stop failed: $e")
        }
    }

    /** Stops speech and releases native resources (activity destroyed). */
    fun release() {
        stopSpeech()
        downloadJob?.cancel()
        downloadJob = null
        try {
            client?.close()
        } catch (e: Exception) {
            Log.w(TAG, "close failed: $e")
        }
        client = null
        clientLocale = null
        channel.setMethodCallHandler(null)
        scope.cancel()
    }

    companion object {
        private const val TAG = "EPITAKA_GENAI_TTS"
        private const val CHANNEL = "epitaka/genai_tts"
        private const val DEFAULT_LANGUAGE = "en-US"
        private const val UNAVAILABLE = "unavailable"
        private const val STATUS_AVAILABLE = "available"
        private const val STATUS_DOWNLOADABLE = "downloadable"
        private const val STATUS_DOWNLOADING = "downloading"
        private const val STATUS_LANGUAGE_UNSUPPORTED = "languageUnsupported"
        private const val STATUS_DEVICE_UNSUPPORTED = "deviceUnsupported"
        private const val STATUS_UNKNOWN = "unknown"
    }
}

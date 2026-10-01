package com.dn.epitaka

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle

/**
 * Invisible trampoline for text shared from another app (share sheet,
 * ACTION_SEND) or picked from the text-selection menu (ACTION_PROCESS_TEXT).
 *
 * It turns the text into an `epitaka://search?q=…` link and hands that to
 * MainActivity. app_links ignores ACTION_SEND intents, but it delivers VIEW
 * links to the deep-link service, which already opens search with a query.
 *
 * A separate activity, rather than intent filters on MainActivity, keeps
 * MainActivity's singleTop launch mode: a share started inside the sending
 * app's task would otherwise create a second MainActivity there, and both
 * would fight over the one FlutterEngine shared with audio_service.
 */
class ShareTextActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val text = when (intent?.action) {
            Intent.ACTION_SEND -> intent.getCharSequenceExtra(Intent.EXTRA_TEXT)
            Intent.ACTION_PROCESS_TEXT -> intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)
            else -> null
        }?.toString()?.trim()?.take(MAX_TEXT_LENGTH)

        val mainIntent = Intent(this, MainActivity::class.java).apply {
            if (!text.isNullOrEmpty()) {
                action = Intent.ACTION_VIEW
                data = Uri.Builder()
                    .scheme("epitaka")
                    .authority("search")
                    .appendQueryParameter("q", text)
                    .build()
            }
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
        }
        startActivity(mainIntent)
        finish()
    }

    companion object {
        // Sharing a whole article would put all of it in the intent, and past
        // Android's ~1 MB binder limit startActivity throws. A search never
        // needs more than a phrase.
        private const val MAX_TEXT_LENGTH = 1000
    }
}

/// Registers a `beforeunload` event listener to stop TTS when the page unloads.
///
/// This is a no-op stub for non-web platforms (iOS, macOS, Windows, Android, Linux).
/// The web implementation would be in a separate `web_tts_cleanup_web.dart` file
/// but is not included since this app doesn't support web platform.
void registerWebTtsCleanup() {
  // No-op on non-web platforms
}

/// Sets the global provider container for web TTS cleanup.
/// No-op on non-web platforms.
void setGlobalProviderContainer(dynamic container) {
  // No-op on non-web platforms
}
package com.tito.rafeeq_aldarb

/**
 * Every method-channel name this app answers on, in one place.
 *
 * They were four `private val`s on MainActivity and two string literals
 * written inline at the call site, which is how «com.tito.rafeeq_aldarb/
 * media_audio» and «com.tito.rafeeq_aldarb/prayer_card» came to be spelled
 * only once each, in the middle of a 304-line function. A channel name has to
 * match a literal on the Dart side exactly or the call silently goes nowhere,
 * so it is worth being able to see all of them at once.
 */
object Channels {
    const val ADHAN = "com.tito.rafeeq_aldarb/adhan"
    const val DOWNLOAD_SERVICE = "com.tito.rafeeq_aldarb/download_service"
    const val NATIVE_STRINGS = "com.tito.rafeeq_aldarb/native_strings"
    const val DOWNLOAD_TAP = "com.tito.rafeeq_aldarb/download_tap"
    const val MEDIA_AUDIO = "com.tito.rafeeq_aldarb/media_audio"
    const val PRAYER_CARD = "com.tito.rafeeq_aldarb/prayer_card"
}

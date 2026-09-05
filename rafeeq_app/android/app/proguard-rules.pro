# P3-46: R8 is already shrinking this release build (confirmed via the
# generated build/app/outputs/mapping/release/mapping.txt, which shows
# com.google.gson.internal.* classes being renamed) even though this file
# never set isMinifyEnabled explicitly. That shrinking was stripping the
# generic-type (Signature) metadata flutter_local_notifications v18 and
# below needs for its own internal Gson-based scheduled-notification
# persistence, causing a 100%-reproducible real crash on this project:
# "RuntimeException: Missing type parameter" from
# FlutterLocalNotificationsPlugin.loadScheduledNotifications, fatally
# killing the app on every boot (ScheduledNotificationBootReceiver) and
# silently breaking every adhan (re)schedule call at runtime otherwise.
# These are flutter_local_notifications' own official rules for this exact,
# documented issue (github.com/MaikuB/flutter_local_notifications, "Missing
# type parameter" / issue #408) — not fixed until v19+, and this project is
# pinned at 18.0.1.
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Standard Flutter ProGuard rules
-dontwarn io.flutter.embedding.**
-keep class io.flutter.embedding.** { *; }

# Keep model classes (if using reflection)
-keep class com.nudgee.** { *; }

# Hive
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepattributes Signature
-keepattributes *Annotation*

# OkHttp (used by Dio)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# Play Core SplitCompat (referenced by Flutter, not always available)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-keep class com.google.android.play.core.splitcompat.** { *; }

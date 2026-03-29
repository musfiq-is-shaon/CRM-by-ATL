# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Contacts Plugin (if used)
-keep class co.quis.flutter_contacts.** { *; }

# Keep line numbers for crash reports
-keepattributes SourceFile,LineNumberTable

# HTTP/Networking (dio/http/okhttp)
-keepattributes Signature
-keepattributes *Annotation*
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# JSON/Serialization (freezed/json_annotation/gson for models/providers)
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Riverpod/State management
-keep class com.google.gson.** { *; }

# CRM App specific - Dart models/providers (prevent obfuscation of reflection targets)
-keep class app.atl.crm.data.models.** { *; }
-keep class app.atl.crm.presentation.providers.** { *; }
-keep class app.atl.crm.MainActivity { *; }

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# Play Core / App Bundle (required)
-dontwarn com.google.android.play.core.**

# Standard Android keeps
-keep class * extends java.util.ListResourceBundle {
    protected Object[][] getContents();
}
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public enum * {*;}
-keepclassmembers enum * {*;}


# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class ezpaypal.flutter_local_notifications_linux.** { *; }

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class flutter_secure_storage.** { *; }

# Enhanced JSON/Freezed/Riverpod (json_annotation, riverpod_annotation)
-keepattributes *Annotation*
-keep class * {
    @com.google.gson.annotations.SerializedName *;
    @json_annotation.JsonKey *;
}
-dontwarn androidx.annotation.**

# Desugaring / Additional Play Services
-dontwarn java.lang.invoke.**
-dontwarn com.google.android.play.core.integrity.**
-dontwarn com.google.android.datatransport.**



# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# React Native & Jitsi Meet SDK
-keep,allowobfuscation @interface com.facebook.proguard.annotations.DoNotStrip
-keep @com.facebook.proguard.annotations.DoNotStrip class *
-keepclassmembers class * { @com.facebook.proguard.annotations.DoNotStrip *; }

-dontwarn com.facebook.react.**
-keep class com.facebook.react.** { *; }
-keep class org.jitsi.** { *; }
-keepclassmembers class org.jitsi.** { *; }
-keep class com.oney.jitsi_meet_flutter_sdk.** { *; }

# SharedPreferences & Google Fonts & PDF
-keep class androidx.preference.** { *; }
-keep class com.google.fonts.** { *; }

# Flutter Secure Storage & AndroidX Security Crypto
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn androidx.security.crypto.**
-keep class androidx.security.crypto.** { *; }

# Printing & PDF rendering
-keep class net.nfet.flutter.printing.** { *; }

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Flutter Play Core / Deferred Components
-dontwarn com.google.android.play.core.**


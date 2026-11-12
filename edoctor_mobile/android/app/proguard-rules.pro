# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# React Native, WebRTC & Jitsi Meet SDK (règles complètes pour release R8/ProGuard)
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

-keep,allowobfuscation @interface com.facebook.proguard.annotations.DoNotStrip
-keep,allowobfuscation @interface com.facebook.proguard.annotations.KeepGettersAndSetters
-keep @com.facebook.proguard.annotations.DoNotStrip class *
-keepclassmembers class * { @com.facebook.proguard.annotations.DoNotStrip *; }
-keepclassmembers @com.facebook.proguard.annotations.KeepGettersAndSetters class * {
    void set*(***);
    *** get*();
}

-dontwarn com.facebook.react.**
-keep class com.facebook.react.** { *; }
-keep,includedescriptorclasses class com.facebook.react.bridge.** { *; }
-keep class * implements com.facebook.react.bridge.JavaScriptModule { *; }
-keep class * implements com.facebook.react.bridge.NativeModule { *; }
-keepclassmembers class * {
    @com.facebook.react.uimanager.annotations.ReactProp <methods>;
    @com.facebook.react.uimanager.annotations.ReactPropGroup <methods>;
}
-keepclassmembers,includedescriptorclasses class * {
    native <methods>;
}

-dontwarn org.webrtc.**
-keep class org.webrtc.** { *; }
-keep class com.oney.WebRTCModule.** { *; }
-keep class com.reactnativecommunity.netinfo.** { *; }

-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

-keep class org.jitsi.** { *; }
-keepclassmembers class org.jitsi.** { *; }
-keep interface org.jitsi.** { *; }
-keep class org.jitsi.meet.sdk.** { *; }
-keep class org.jitsi.jitsi_meet_flutter_sdk.** { *; }
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

# Local Auth & BiometricPrompt
-dontwarn androidx.biometric.**
-keep class androidx.biometric.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }


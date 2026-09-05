# Flutter WebRTC & WebRTC JNI native bindings
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# Flutter Plugins
-keep class com.cloudwebrtc.webrtc.** { *; }
-keep class com.laithmh.offcast.** { *; }

# Keep Network interfaces and reflection for Shelf & WebSockets
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

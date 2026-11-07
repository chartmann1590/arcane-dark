# LiteRT-LM (on-device Gemma): the native library calls back into JniMessageCallback/JniInferenceCallback by name over JNI.
# R8 stripped those interface methods in direct build 4 (0 methods in classes.dex), so the first AI reply would end in
# NoSuchMethodError. Keep the whole LiteRT/AI Edge namespace. Added 2026-11-07.
-keep class com.google.ai.edge.** { *; }
-keepnames class com.google.ai.edge.** { *; }
-keep interface com.google.ai.edge.** { *; }

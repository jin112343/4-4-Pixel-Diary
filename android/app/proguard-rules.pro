# Flutter/Dart関連のルール
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase関連
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# JSON Serialization (freezed/json_serializable)
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Hive関連
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }

# flutter_secure_storage関連
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Bluetooth関連
-keep class com.boskokg.flutter_blue_plus.** { *; }

# Jailbreak Detection関連
-keep class com.example.flutter_jailbreak_detection.** { *; }

# ネイティブメソッド
-keepclasseswithmembernames class * {
    native <methods>;
}

# Enum保持
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Parcelable
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# R8最適化設定
-optimizationpasses 5
-dontusemixedcaseclassnames
-verbose

# デバッグ情報を削除
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# 難読化の除外（必要に応じて追加）
# -keep class com.example.pixeldiary.models.** { *; }

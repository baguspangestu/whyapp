# WorkManager creates its Room database implementation by class name.
# Keep these classes stable when AGP/R8 optimizes release builds.
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class **_Impl { *; }

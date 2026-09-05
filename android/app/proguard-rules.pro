# Google Play Billing Library (External Offers)
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.taucity.meowmin.** { *; }
-dontwarn io.flutter.**

# home_widget
-keep class es.antonborri.home_widget.** { *; }
-dontwarn es.antonborri.home_widget.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# RevenueCat
-keep class com.revenuecat.** { *; }
-dontwarn com.revenuecat.**
-keep class com.revenuecat.purchases.** { *; }

# SharedPreferences, WorkManager, AudioPlayers, SecureStorage, etc (prevent MissingPluginException with isMinifyEnabled)
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.baseflow.flutter.** { *; }
-keep class androidx.work.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn androidx.work.**
-dontwarn io.flutter.plugins.sharedpreferences.**
-dontwarn xyz.luan.audioplayers.**

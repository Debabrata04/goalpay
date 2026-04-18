# ════════════════════════════════════════════
# ANDROID — add to android/app/src/main/AndroidManifest.xml
# inside the <manifest> tag (before <application>)
# ════════════════════════════════════════════

<!--
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
-->


# ════════════════════════════════════════════
# iOS — add to ios/Runner/Info.plist
# inside the <dict> tag
# ════════════════════════════════════════════

<!--
<key>NSLocationWhenInUseUsageDescription</key>
<string>GoalPay uses your location to give accurate cost estimates for your city.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>GoalPay uses your location to personalise goal costs and trip planning.</string>
-->


# ════════════════════════════════════════════
# SETUP STEPS (run in order)
# ════════════════════════════════════════════

# 1. Create new Flutter project
flutter create goalpay
cd goalpay

# 2. Replace lib/main.dart and pubspec.yaml

# 3. Add Android location permissions to AndroidManifest.xml

# 4. Add iOS location permissions to Info.plist

# 5. Install dependencies
flutter pub get

# 6. Run
flutter run

# Optional: Set Gemini API key (free at aistudio.google.com/app/apikey)
# Uncomment in main():
#   AIService.setApiKey('YOUR_KEY');

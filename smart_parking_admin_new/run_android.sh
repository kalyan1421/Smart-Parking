#!/bin/bash

# Smart Parking Admin New - Android Runner
echo "📱 Starting Smart Parking Admin (New Version) on Android..."
echo "🔧 Device: Android"
echo "🗺️ Google Maps: Native Android SDK"
echo "🔥 Firebase: Connected"
echo ""

# Check if device is connected
echo "📱 Checking connected devices..."
flutter devices

echo ""
echo "🚀 Deploying to Android device..."

# Clean and rebuild if needed
if [ "$1" = "clean" ]; then
    echo "🧹 Cleaning project..."
    flutter clean
    flutter pub get
fi

# Run on Android device (will prompt to select if multiple devices)
flutter run

echo ""
echo "✅ Admin app should be running on your Android device"
echo "🔑 Login with admin credentials to access dashboard"
echo "🗺️ Use 'Parking Map View' for Google Maps features"


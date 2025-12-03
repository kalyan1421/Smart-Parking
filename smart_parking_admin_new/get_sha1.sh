#!/bin/bash

echo "=========================================="
echo "Getting SHA-1 Fingerprint for Google Maps"
echo "=========================================="
echo ""

cd android

echo "Debug SHA-1 Fingerprint:"
echo "------------------------"
./gradlew signingReport | grep -A 2 "Variant: debug" | grep "SHA1:"

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo "1. Copy the SHA-1 fingerprint above"
echo "2. Go to: https://console.cloud.google.com/apis/credentials"
echo "3. Select project: smart-parking-kalyan-2024"
echo "4. Click on API key: AIzaSyBvOkBwgGlbUiuS-oKrPgGHXKGMnpC7T6s"
echo "5. Under 'Application restrictions':"
echo "   - Select 'Android apps'"
echo "   - Click 'Add an item'"
echo "   - Package name: com.example.smart_parking_admin_new"
echo "   - SHA-1: [Paste the fingerprint from above]"
echo "6. Click 'Save'"
echo ""

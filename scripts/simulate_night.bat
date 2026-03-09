@echo off
echo Simulating Night Reflection...
adb shell cmd notification post -t "Night Reflection" -S bigtext "com.example.ramadan_app" "🌙 End the day with one du'a."
if %ERRORLEVEL% EQU 0 (
    echo Notification sent successfully!
) else (
    echo Failed to send notification. Make sure your phone is connected and USB debugging is enabled.
)
pause

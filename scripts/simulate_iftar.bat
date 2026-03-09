@echo off
echo Simulating Iftar Approaching...
adb shell cmd notification post -t "Iftar Approaching" -S bigtext "com.example.ramadan_app" "🌇 The fast is ending soon. Make dua"
if %ERRORLEVEL% EQU 0 (
    echo Notification sent successfully!
) else (
    echo Failed to send notification. Make sure your phone is connected and USB debugging is enabled.
)
pause

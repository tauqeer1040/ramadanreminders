@echo off
echo Simulating Suhoor Reminder...
adb shell cmd notification post -t "Suhoor Reminder" -S bigtext "com.example.ramadan_app" "🌅 Time to wake up! A little food, a lot of barakah."
if %ERRORLEVEL% EQU 0 (
    echo Notification sent successfully!
) else (
    echo Failed to send notification. Make sure your phone is connected and USB debugging is enabled.
)
pause

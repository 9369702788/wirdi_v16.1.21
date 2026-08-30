import re
from pathlib import Path

path = Path('android/app/src/main/AndroidManifest.xml')
text = path.read_text()

# All permissions needed by Wirdi
# AUDIT (production readiness): RECEIVE_BOOT_COMPLETED was declared but
# never actually used -- no BroadcastReceiver listens for
# android.intent.action.BOOT_COMPLETED anywhere in this codebase, and
# notification_service.dart's own doc comment explicitly documents that
# reminders are only rescheduled on the next successful prayer-times
# fetch (app open / refresh), NOT after a reboot. An unused dangerous-
# adjacent permission is exactly what Google Play's permission review
# flags and what a privacy-conscious user would question -- removed
# rather than left in "just in case". If real boot-survival scheduling
# is implemented later, re-add this permission alongside the actual
# BroadcastReceiver that uses it.
perms = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.VIBRATE',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.SCHEDULE_EXACT_ALARM',
    'android.permission.FOREGROUND_SERVICE',
    'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',
    'android.permission.WAKE_LOCK',
]
perm_lines = '\n'.join(
    f'    <uses-permission android:name="{p}" />'
    for p in perms if p not in text
)
if perm_lines:
    text = text.replace(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n' + perm_lines,
    )

# Add usesCleartextTraffic and networkSecurityConfig to <application>
if 'usesCleartextTraffic' not in text:
    text = re.sub(
        r'<application\b',
        '<application android:usesCleartextTraffic="true" '
        'android:networkSecurityConfig="@xml/network_security_config"',
        text, count=1
    )

# Register audio_service's foreground media-playback service + media
# button receiver, so Radio/Quran audio show a system notification with
# Play/Pause/Stop (lock screen + notification shade controls).
if 'com.ryanheise.audioservice.AudioService' not in text:
    audio_service_block = (
        '\n    <service android:name="com.ryanheise.audioservice.AudioService"\n'
        '        android:foregroundServiceType="mediaPlayback"\n'
        '        android:exported="true">\n'
        '        <intent-filter>\n'
        '            <action android:name="android.media.browse.MediaBrowserService" />\n'
        '        </intent-filter>\n'
        '    </service>\n'
        '    <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"\n'
        '        android:exported="true">\n'
        '        <intent-filter>\n'
        '            <action android:name="android.intent.action.MEDIA_BUTTON" />\n'
        '        </intent-filter>\n'
        '    </receiver>\n'
    )
    text = re.sub(r'(</application>)', audio_service_block + r'\1', text, count=1)

# Add <queries> block for URL launcher and radio streams
if '<queries>' not in text:
    queries = (
        '\n    <queries>\n'
        '        <intent>\n'
        '            <action android:name="android.intent.action.VIEW" />\n'
        '            <data android:scheme="https" />\n'
        '        </intent>\n'
        '        <intent>\n'
        '            <action android:name="android.intent.action.VIEW" />\n'
        '            <data android:scheme="http" />\n'
        '        </intent>\n'
        '        <intent>\n'
        '            <action android:name="android.intent.action.VIEW" />\n'
        '            <data android:scheme="geo" />\n'
        '        </intent>\n'
        '    </queries>\n'
    )
    text = text.replace('</manifest>', queries + '</manifest>')

# Register the home-screen widget provider (was previously missing entirely --
# the widget could never appear to the user without this receiver declaration).
if 'WirdiWidgetProvider' not in text:
    widget_block = (
        '\n    <receiver android:name="com.wirdi.wirdi.WirdiWidgetProvider"\n'
        '        android:exported="true">\n'
        '        <intent-filter>\n'
        '            <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />\n'
        '        </intent-filter>\n'
        '        <meta-data android:name="android.appwidget.provider"\n'
        '            android:resource="@xml/wirdi_widget_info" />\n'
        '    </receiver>\n'
    )
    text = re.sub(r'(</application>)', widget_block + r'\1', text, count=1)

path.write_text(text)
print('AndroidManifest.xml patched:')
print(text)

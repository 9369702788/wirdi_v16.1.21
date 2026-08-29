from pathlib import Path

# audio_service's system media notification (lock screen + notification-
# shade Play/Pause/Stop for Radio/Quran playback) requires MainActivity to
# extend AudioServiceActivity instead of the default FlutterActivity --
# otherwise AudioService.init() runs without error but the notification
# never actually appears and its buttons do nothing, because Android never
# properly hosts the media-session/foreground-service lifecycle.
candidates = list(Path("android/app/src/main/kotlin").rglob("MainActivity.kt"))
if not candidates:
    print("WARNING: MainActivity.kt not found -- audio_service media notification will not work")
else:
    for path in candidates:
        text = path.read_text()
        if "AudioServiceActivity" in text:
            print(f"{path} already extends AudioServiceActivity, skipping")
            continue
        text = text.replace(
            "import io.flutter.embedding.android.FlutterActivity",
            "import com.ryanheise.audioservice.AudioServiceActivity",
        )
        text = text.replace(
            "class MainActivity : FlutterActivity()",
            "class MainActivity : AudioServiceActivity()",
        )
        text = text.replace(
            "class MainActivity: FlutterActivity()",
            "class MainActivity: AudioServiceActivity()",
        )
        path.write_text(text)
        print(f"Patched {path} to extend AudioServiceActivity")

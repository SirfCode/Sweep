# Local development setup

Verified on 15 September 2026.

- Flutter 3.47.4 and Dart 3.13.3: `C:\Users\Work\develop\flutter`
- Android Studio 2026.1.4: `C:\Program Files\Android\Android Studio`
- Android SDK: `C:\Users\Work\AppData\Local\Android\Sdk`
- Android platform API 36 and build tools 36.0.0
- Platform tools, emulator, NDK 28.2.13676358, and CMake 3.22.1 installed
- Flutter configured to use Android Studio's bundled Java runtime
- User PATH and ANDROID_HOME configured; restart terminal applications to load them

`flutter doctor -v` passes Flutter and Android toolchain checks, including licenses. Windows desktop C++ components are missing; these are not required for Android development. It also reports an older ADB installation in `C:\Android`; use the SDK's platform-tools ADB for this project to avoid version conflicts.

The playable game passes `flutter analyze` and 24 automated tests across scoring, rules, full games, save/resume, and the player interface. `flutter build apk --debug` succeeds and includes ARM phone and x86_64 emulator targets. The installed build was checked on `emulator-5556`: house-raising preview/confirmation, bot turns, and exact saved-state recovery after force-stop/relaunch. Portrait and landscape screenshots are in `artifacts/sweep-table.png` and `artifacts/sweep-landscape.png`. No Flutter or Android runtime errors appeared during those checks.

Emulator hardware acceleration (WHPX) is available. `Sweep_Phone` is configured with a Pixel 5 profile and Android API 36 x86_64 system image. Its first boot completed successfully.

The existing older ADB service repeatedly restarted the default connection. Sweep's test emulator uses port 5556 and a separate ADB server on port 5038. Set these variables in PowerShell before using Flutter with this running emulator:

```powershell
$env:ANDROID_ADB_SERVER_PORT = '5038'
$env:ADB_SERVER_SOCKET = 'tcp:localhost:5038'
flutter devices
flutter run -d emulator-5556
```

To start this emulator again in the background:

```powershell
$env:ANDROID_ADB_SERVER_PORT = '5038'
$env:ADB_SERVER_SOCKET = 'tcp:localhost:5038'
$env:ANDROID_HOME = 'C:\Users\Work\AppData\Local\Android\Sdk'
& "$env:ANDROID_HOME\platform-tools\adb.exe" -P 5038 start-server
Start-Process -FilePath "$env:ANDROID_HOME\emulator\emulator.exe" -ArgumentList '-avd Sweep_Phone -port 5556 -no-window -no-audio -gpu software' -WindowStyle Hidden
```

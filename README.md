# DON'T BLINK — Godot Android Starter Project

A portrait, one-touch endless rage game built in Godot 4. The project uses vector-drawn art, so no downloaded art assets are needed.

## Current prototype features
- Title screen, gameplay, death/retry, and pause/resume.
- Tap/Space to start; tap/Space during play to blink.
- Blue barriers require an active blink. Red hazards are safe only when you are NOT blinking.
- Blink lasts 0.23 seconds and has a 1.20-second cooldown; tapping repeatedly cannot extend the blink.
- Score and best score; best score saved locally to `user://save.cfg`.
- Responsive canvas layout, neon look, Android vibration on blink.
- Offline and no permissions/backend required.

## Open and run
1. Install Godot 4.x from https://godotengine.org/download
2. Extract this ZIP.
3. In Godot Project Manager, choose **Import** and select this folder's `project.godot`.
4. Open the project and press **F6** (run current scene) or **F5** (run project).
5. On desktop, Space/Enter starts and blinks. Escape pauses/resumes. On phone, tap the screen.

## Export an Android APK
1. In Godot, open **Editor > Manage Export Templates** and install matching export templates.
2. Install Android Studio / Android SDK and configure Godot's Android SDK/JDK paths in **Editor Settings > Export > Android**. Follow the official Godot Android export guide: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
3. Go to **Project > Export**, add an **Android** preset, set package name such as `in.ideaai.dontblink` (change this to your own unique package ID), and set app name to `DON'T BLINK`.
4. Export a debug APK first and install it on your Android phone to test.
5. Before publishing, create a release keystore, configure signing, choose a unique package ID, add a final icon, and export an Android App Bundle (AAB) if required by Google Play.

## Known prototype limitations / next polish pass
- This is a playable foundation, not yet store-ready. Please test collision timing and obstacle sequences on an actual phone.
- The first version uses a fixed-height player and ground-based barriers. It is deliberately simple; later we should add a fair obstacle scheduler, a first-run tutorial, sound/music settings, and more visual effects.
- Audio is not included yet.
- The game has no ads, analytics, online leaderboard, or login.

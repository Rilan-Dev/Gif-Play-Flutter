# Repository Research Index Addendum — Android CI/CD

This addendum supplements `docs/AI_REPO_INDEX.md` with the automated Android build path.

## CI/CD topology

- Workflow: `.github/workflows/android-apk.yml`
- Build command: `flutter build apk --release`
- Output: `build/app/outputs/flutter-apk/app-release.apk`
- Artifact upload: GitHub Actions `upload-artifact@v4`, 30-day retention
- Setup: Ubuntu runner, Java 17, Flutter stable channel
- Triggers: push to `main` / `feature/**` / `feat/**`, pull request to `main`, manual dispatch
- Operator guide: `docs/CI_CD_ANDROID_APK.md`

For APK pipeline changes, inspect the workflow, `pubspec.yaml`, `android/app/build.gradle`, `android/build.gradle`, `android/settings.gradle`, and `android/gradle/wrapper/gradle-wrapper.properties`. Do not treat an artifact as production-release signed until release signing is configured.

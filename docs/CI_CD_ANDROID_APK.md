# Android APK CI/CD

## Automated build

Workflow: `.github/workflows/android-apk.yml`

It runs on:
- Pushes to `main`, `feature/**`, and `feat/**` branches.
- Pull requests targeting `main`.
- Manual dispatch from the GitHub Actions tab.

The job checks out the repository, installs Java 17 and the stable Flutter SDK, resolves packages, and runs:

```sh
flutter build apk --release
```

The resulting APK is uploaded as a GitHub Actions artifact named `gif-play-android-apk-<run number>` and retained for 30 days. The workflow does not create a GitHub Release or publish to an app store.

## Download the APK

1. Open the repository's **Actions** tab.
2. Select **Build Android APK** and open a completed run.
3. Under **Artifacts**, download `gif-play-android-apk-<run number>`.
4. Extract the downloaded ZIP; it contains `app-release.apk`.

## Signing note

The current `android/app/build.gradle` config signs the release build with the Android debug signing configuration. This is suitable for automated install/testing artifacts, not a production Play Store release. Before store distribution, configure a protected release keystore and GitHub Actions secrets; never commit keystore files or passwords.

## Verification behavior

This workflow produces an APK when the build succeeds. It is not a reason to pause unrelated implementation work; inspect a failed run when convenient rather than repeatedly polling it.

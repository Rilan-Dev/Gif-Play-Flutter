# Android APK CI/CD

## Manual-only build

Workflow: `.github/workflows/android-apk.yml`

The workflow runs **only when you manually dispatch it** from GitHub Actions. It does not run on pushes, branch updates, or pull requests, so normal development commits will not start an APK build.

When you click **Run workflow**, select the branch and choose **Build type**:
- `release` (default): creates `app-release.apk`.
- `debug`: creates `app-debug.apk`.

The job checks out the selected branch, installs Java 17 and the stable Flutter SDK, resolves packages, and runs the matching Flutter APK build command.

The verified Android build configuration uses Gradle 8.14.3, Android Gradle Plugin 8.11.1, and Kotlin Gradle Plugin 2.2.20. The custom SQL `LocalDatabase` uses Drift's `GeneratedDatabase` base class and declares its schema/migration hooks. Keep `drift: 2.31.0` paired with `drift_flutter: 0.2.3` unless the local database implementation is deliberately migrated to a newer Drift API.

## Successful build record

On October 10, 2026, release build run [#22](https://github.com/Rilan-Dev/Gif-Play-Flutter/actions/runs/38013379533) completed successfully and uploaded the artifact `gif-play-release-android-apk-22`. The APK inside is `app-release.apk`; the workflow artifact is retained for 30 days.

## Build and download an APK

1. Open the repository's [Actions tab](https://github.com/Rilan-Dev/Gif-Play-Flutter/actions).
2. Select **Build Android APK** from the left sidebar.
3. Click **Run workflow**, choose the branch and **Build type** (`release` or `debug`), then click **Run workflow** again.
4. When that run finishes successfully, open it and find **Artifacts** near the bottom of the run summary.
5. Download the artifact named `gif-play-<build type>-android-apk-<run number>` and extract the ZIP. It contains `app-release.apk` or `app-debug.apk`, matching the selected type.

Artifacts are retained for 30 days. The workflow does not create a GitHub Release or publish to an app store.

GitHub requires the workflow file with `workflow_dispatch` to be present on the default branch for the manual **Run workflow** button to appear.

## Signing note

The current `android/app/build.gradle` config signs the release build with the Android debug signing configuration. This is suitable for automated install/testing artifacts, not a production Play Store release. Before store distribution, configure a protected release keystore and GitHub Actions secrets; never commit keystore files or passwords.

## Verification behavior

Each manual click starts one build for the selected branch and APK type. No automatic build is started by ordinary code pushes. If a build fails, inspect the first failing step and fix that cause; unrelated feature development does not need to wait.

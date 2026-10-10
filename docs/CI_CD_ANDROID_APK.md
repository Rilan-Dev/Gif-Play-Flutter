# Android APK CI/CD

## Manual-only build

Workflow: `.github/workflows/android-apk.yml`

The workflow runs **only when you manually dispatch it** from GitHub Actions. It does not run on pushes, branch updates, or pull requests, so normal development commits will not start an APK build.

The job checks out the selected branch, installs Java 17 and the stable Flutter SDK, resolves packages, and runs:

```sh
flutter build apk --release
```

The resulting APK is uploaded as a GitHub Actions artifact named `gif-play-android-apk-<run number>` and retained for 30 days. The workflow does not create a GitHub Release or publish to an app store.

## Build and download the APK

1. Open the repository's [Actions tab](https://github.com/Rilan-Dev/Gif-Play-Flutter/actions).
2. Select **Build Android APK** from the left sidebar.
3. Click **Run workflow**, choose the branch you want to build, and click **Run workflow** again.
4. When that run finishes, open it and find **Artifacts** near the bottom of the run summary.
5. Download `gif-play-android-apk-<run number>` and extract the ZIP. It contains `app-release.apk`.

GitHub requires the workflow file with `workflow_dispatch` to be present on the default branch for the manual **Run workflow** button to appear.

## Signing note

The current `android/app/build.gradle` config signs the release build with the Android debug signing configuration. This is suitable for automated install/testing artifacts, not a production Play Store release. Before store distribution, configure a protected release keystore and GitHub Actions secrets; never commit keystore files or passwords.

## Verification behavior

Each manual click starts one build for the selected branch. No automatic build is started by ordinary code pushes. If a build fails, you can inspect or rerun it when convenient; unrelated development work does not need to wait.

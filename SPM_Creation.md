SPM Creation involved below steps.

1. Creating XCFramework
2. Uploading XCFramework
3. Updating Package.swift file
4. Publishing Cocoapod (Optional)

## Creating XCFramework

1. Download Code Zip File from Repo from release branch.
2. Go to `SPM_Builder` => `JMMediaStackSDK` and Open `JMMediaStackSDK.xcodeproj` in Xcode.
3. Delete all files if any exist from `JMMediaStackSDK` directory except `JMMediaStackSDK.h` file.
4. Right click on `JMMediaStackSDK` Directory and select option Add Files to `JMMediaStackSDK`.
5. Navigate to `JMMediaSampleApp => JMMediaStackSDK` and select all files except `JMMediaStackSDK.h` file.
6. Add all the files.
7. Close the Project
8. Open Terminal in SPM_Builder folder and run command `sh XcframeworksBuilder.sh --verbose`. 
9. It will create XCFramework and will zip it and open the containing folder.

## Uploading XCFramework

1. Go to below url and create a folder with version number. Follow versioning number for stable one as `v_major_minor_patch` and for alpha or beta version as `v_major_minor_patch_alpha_alpha_number` and upload XCFramework zip file created in SPM Creation process.

```
https://console.cloud.google.com/storage/browser/cpass-sdk/libs/iOS/public/JMMedia/dynamic
```

## Updating Package.swift file

1. Clone `https://github.com/JioMeet/JMMediaStackSDK_iOS` Github repo
2. Checkout to `dev` branch
3. Create a branch from dev branch with version number.
4. Copy and Paste XCFramework Zip file created in First step or one you have uploaded.
5. Open terminal in same directory containing `Package.swift` file.
6. Run command `swift package compute-checksum JMMediaStackSDK.xcframework.zip`.
7. You will get alph-anumeric checksum string.
8. Open `Package.swift` file in Xcode or Visual Studio(Prefer Visual Studio).
9. Replace `url` and `checksum` values with new one in below piece of code.

```swift
.binaryTarget(
    name: "JMMediaStackSDK",
    url: "https://storage.googleapis.com/cpass-sdk/libs/iOS/public/JMMedia/dynamic/v_1_0_0_alpha_2/JMMediaStackSDK.xcframework.zip",
    checksum: "c69652222aaf8c69a6afd96110a440664e4af4b59f37a86f3d403168ef368f81"
),
```

10. Save the file
11. Push Code to Github repo.
12. Draft a release from release branch with description.
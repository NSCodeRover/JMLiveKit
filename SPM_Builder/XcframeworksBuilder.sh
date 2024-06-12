#!/bin/bash
set -e

WORKING_DIR=$(pwd)

XCFrameworks_Output_Folder="SPM_XCFramework_Output"

# Create Frameworks Array
# Do not use comma to seperate array elements. Use space.
AllFrameworksNames=("JMMediaStackSDK")

# Workspace path
WorkSpace_Path="JMMediaStackSDK/JMMediaStackSDK.xcodeproj"

# Build Scheme to be used to create frameworks
BUILD_SCHEME="JMMediaStackSDK"

# Archive paths for Simulator and Physical devices
SIMULATOR_ARCHIVE_PATH="${XCFrameworks_Output_Folder}/simulator.xcarchive"
IOS_DEVICE_ARCHIVE_PATH="${XCFrameworks_Output_Folder}/iOS.xcarchive"

# Delete any existing Archive
echo "Deleting any existing Archives"
rm -rf "${SIMULATOR_ARCHIVE_PATH}"
rm -rf "${IOS_DEVICE_ARCHIVE_PATH}"

echo "Creating Frameworks"

# Create Simulator Destination Archive
xcodebuild archive ONLY_ACTIVE_ARCH=NO -project ${WorkSpace_Path} -scheme ${BUILD_SCHEME} -destination="generic/platform=iOS Simulator" -archivePath "${SIMULATOR_ARCHIVE_PATH}" -sdk iphonesimulator SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

# Create Device Destination Archive
xcodebuild archive -project ${WorkSpace_Path} -scheme ${BUILD_SCHEME} -destination="generic/platform=iOS" -archivePath "${IOS_DEVICE_ARCHIVE_PATH}" -sdk iphoneos SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

# Run Loop to create XCFrameworks
for frameworkName in ${AllFrameworksNames[@]}; do

    # Delete any existing Framework
    echo "Deleting any existing Archives"
    rm -rf "${XCFrameworks_Output_Folder}/${frameworkName}.xcframework"
    rm -rf "${XCFrameworks_Output_Folder}/${frameworkName}.xcframework.zip"

    echo "Creating ${frameworkName} XCFramework"

    Simulator_Framework_Output_Path="${SIMULATOR_ARCHIVE_PATH}/Products/Library/Frameworks/${frameworkName}.framework"
    Device_Framework_Output_Path="${IOS_DEVICE_ARCHIVE_PATH}/Products/Library/Frameworks/${frameworkName}.framework"
    XCFramework_Output_Path="${XCFrameworks_Output_Folder}/${frameworkName}.xcframework"

    # Create XCFramework
    xcodebuild -create-xcframework -framework ${Simulator_Framework_Output_Path} -framework ${Device_Framework_Output_Path} -output ${XCFramework_Output_Path}

    # Zip XCFramework file
    cd "${XCFrameworks_Output_Folder}"
    zip -r "${frameworkName}.xcframework.zip" "${frameworkName}.xcframework"
    cd ..
done

rm -rf "${SIMULATOR_ARCHIVE_PATH}"
rm -rf "${IOS_DEVICE_ARCHIVE_PATH}"
open "${XCFrameworks_Output_Folder}"
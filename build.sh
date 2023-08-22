#!/bin/bash

# Stop script on errors.
set -e

export PROJECT_DIR=$(pwd)
export BUILD_DIR=$(pwd)/SampleApp/MediaStack

echo "PROJECT_DIR = $PROJECT_DIR"

function sampleAppPodInstall() {
    echo "Sample app = $BUILD_DIR"
    cd $BUILD_DIR
    pod install
}

sampleAppPodInstall
open $BUILD_DIR/MediaStack.xcworkspace

#!/bin/bash

# JMLiveKit Subspecs Migration Script
# This script helps migrate from the old single-pod structure to the new subspec structure

set -e

echo "🚀 JMLiveKit Subspecs Migration Script"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in a project directory
if [ ! -f "Podfile" ]; then
    print_error "No Podfile found in current directory. Please run this script from your project root."
    exit 1
fi

print_status "Found Podfile. Starting migration process..."

# Backup current Podfile
if [ ! -f "Podfile.backup" ]; then
    cp Podfile Podfile.backup
    print_success "Created backup of current Podfile as Podfile.backup"
else
    print_warning "Podfile.backup already exists. Skipping backup creation."
fi

# Check if JMLiveKit is currently used
if grep -q "JMLiveKit" Podfile; then
    print_status "Found JMLiveKit in Podfile. Analyzing current usage..."
    
    # Check for main app targets
    if grep -q "target.*do" Podfile; then
        print_status "Found target definitions. Will update them to use subspecs."
    else
        print_warning "No target definitions found. Please manually update your Podfile."
    fi
else
    print_warning "No JMLiveKit found in Podfile. Nothing to migrate."
    exit 0
fi

print_status "Migration steps to perform:"
echo "1. Update main app targets to use 'JMLiveKit/Core'"
echo "2. Update extension targets to use 'JMLiveKit/ScreenShare'"
echo "3. Update version to 2.6.21"
echo "4. Clean and reinstall pods"

echo ""
read -p "Do you want to proceed with the migration? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Migration cancelled by user."
    exit 0
fi

print_status "Starting migration..."

# Create a temporary Podfile for migration
cat > Podfile.migration << 'EOF'
# JMLiveKit Subspecs Migration - Temporary Podfile
# Please review and replace your existing Podfile with this content

platform :ios, '13.0'
use_frameworks!

# Main app target
target 'JMMediaSampleApp' do
  # Core functionality for main app (both work the same)
  pod 'JMLiveKit', '~> 2.6.22'           # Defaults to Core subspec
  # OR
  # pod 'JMLiveKit/Core', '~> 2.6.22'    # Explicit Core subspec
  
  # Other dependencies (update versions as needed)
  pod 'MMWormhole', '~> 2.2'
  pod 'GoogleMLKit/FaceDetection', '~> 3.2'
  pod 'GoogleMLKit/SegmentationSelfie', '~> 3.2'
end

# Broadcast extension target
target 'broadcast' do
  use_frameworks!
  # Extension-safe APIs only
  pod 'JMLiveKit/ScreenShare', '~> 2.6.22'
end

# Other extension targets (if any)
target 'MediaStackScreenShare' do
  use_frameworks!
  pod 'JMLiveKit/ScreenShare', '~> 2.6.22'
end

target 'ScreenShareExtension' do
  use_frameworks!
  pod 'JMLiveKit/ScreenShare', '~> 2.6.22'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      
      # Ensure proper architecture settings
      config.build_settings['VALID_ARCHS'] = 'arm64 x86_64'
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
      
      # Add Swift version
      config.build_settings['SWIFT_VERSION'] = '5.0'
    end
  end
end
EOF

print_success "Created migration Podfile template as Podfile.migration"
print_status "Please review Podfile.migration and update your Podfile accordingly."

echo ""
print_status "Next steps:"
echo "1. Review Podfile.migration and update your Podfile"
echo "2. Run: pod deintegrate"
echo "3. Run: pod install"
echo "4. Clean build folder in Xcode"
echo "5. Build and test your project"

echo ""
print_warning "Important notes:"
echo "- The Core subspec includes camera and UI functionality"
echo "- The ScreenShare subspec is extension-safe (no camera APIs)"
echo "- Update your import statements if needed"
echo "- Test both main app and extensions thoroughly"

echo ""
print_status "Migration script completed. Please follow the steps above to complete the migration." 
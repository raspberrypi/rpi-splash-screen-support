#!/bin/bash

set -e

# Constants
MAX_WIDTH=1000
MAX_HEIGHT=1000
REQUIRED_DEPTH=24
CURRENT_DIR=$(pwd)

# Parse command line arguments
usage() {
    echo "Usage: $0 <splash-image> [options]"
    echo "Options:"
    echo "  --version=VERSION    Qt version to build (default: $QT_VERSION)"
    echo "  -h, --help           Show this help message"
    exit 1
}

if [ $# -eq 0 ]; then
    echo "Error: No splash image provided"
    usage
    exit 1
fi

for arg in "$@"; do
    case $arg in
        --version=*)
            QT_VERSION="${arg#*=}"
            ;;
        -h|--help)
            usage
            ;;
    esac
done

IMAGE_PATH=$1

if [ ! -f "$CURRENT_DIR/$IMAGE_PATH" ]; then
    echo "Error: Splash image file not found"
    exit 1
fi
IMAGE_INFO=$(file "$CURRENT_DIR/$IMAGE_PATH")

# Check if the image is a valid TGA file
if ! echo "$IMAGE_INFO" | grep -q "Targa image"; then
    echo "Error: Splash image is not a valid TGA file"
    exit 1
fi

# Make sure image dimensions not too large
regex="([0-9]+) x ([0-9]+) x ([0-9]+)"

# Perform the regex match
if [[ $IMAGE_INFO =~ $regex ]]; then
    # Assign the captured groups to variables
    width=${BASH_REMATCH[1]}
    height=${BASH_REMATCH[2]}
    depth=${BASH_REMATCH[3]}
    if [ $depth -ne $REQUIRED_DEPTH ]; then
    echo "Error: Splash image must be $REQUIRED_DEPTH-bit, provided image is $depth bit"
    exit 1
    fi
    if [ $width -gt $MAX_WIDTH ] || [ $height -gt $MAX_HEIGHT ]; then
        echo "Splash image must be less than $MAX_WIDTH x $MAX_HEIGHT px"
        echo "Provided image is $width x $height"
        exit 1
    fi
else
    echo "Could not determine image properties"
    echo "Warning: Continuing anyway, please check image is correct format:"
    echo "Image format must be TGA, 24-bit, dimensions < 1000x1000px"
fi

# Passed checks
# Add correct hook to /etc/initramfs-tools/hooks/
echo "Copying image to /lib/firmware/logo.tga"
cp $CURRENT_DIR/$IMAGE_PATH /lib/firmware/logo.tga

echo "Adding hook to /etc/initramfs-tools/hooks/"
cp /usr/share/fullscreen-splash/default-hook.sh /etc/initramfs-tools/hooks/splash-screen-hook.sh
sed -i "s|<splash-image-path>|logo.tga|" /etc/initramfs-tools/hooks/splash-screen-hook.sh

echo "updating initramfs"
update-initramfs -k all -u

# Update cmdline.txt to enable splash screen
if grep -q "fullscreen_logo" /boot/firmware/cmdline.txt; then
    echo "cmdline.txt already contains entry for fullscreen_logo"
    echo "You must update cmdline.txt manually to enable splash screen"
    echo "Add the following line to cmdline.txt:"
    echo " fullscreen_logo_path=logo.tga"
    echo " fullscreen_logo=1"
else
    echo "cmdline.txt does not contain entry for fullscreen_logo"
    echo "Adding entry to cmdline.txt"
    sed -i 's/$/ fullscreen_logo=1 fullscreen_logo_name=logo.tga vt.global_cursor_default=0/' /boot/firmware/cmdline.txt
    sed -i "s/console=tty1//" /boot/firmware/cmdline.txt
fi
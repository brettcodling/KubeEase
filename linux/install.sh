#!/bin/bash

# KubeEase Installation Script for Linux
# This script installs KubeEase system-wide

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}Please do not run this script as root. It will ask for sudo when needed.${NC}"
  exit 1
fi

# Check if build exists
if [ ! -d "../build/linux/x64/release/bundle" ]; then
  echo -e "${RED}Error: Build directory not found!${NC}"
  echo "Please run 'flutter build linux --release' first."
  exit 1
fi

echo -e "${GREEN}Installing KubeEase...${NC}"

# Install directory
INSTALL_DIR="/opt/kube_ease"

# Remove old installation if exists
if [ -d "$INSTALL_DIR" ]; then
  echo -e "${YELLOW}Removing old installation...${NC}"
  sudo rm -rf "$INSTALL_DIR"
fi

# Copy entire bundle to /opt
echo "Copying files to $INSTALL_DIR..."
sudo cp -r ../build/linux/x64/release/bundle "$INSTALL_DIR"

# Make executable
sudo chmod +x "$INSTALL_DIR/kube_ease"

# Copy icon to proper icon theme directories
echo "Installing icon..."
sudo mkdir -p /usr/share/icons/hicolor/512x512/apps
sudo cp ../assets/icon.png /usr/share/icons/hicolor/512x512/apps/kube-ease.png
# Also copy to pixmaps as fallback
sudo mkdir -p /usr/share/pixmaps
sudo cp ../assets/icon.png /usr/share/pixmaps/kube-ease.png

# Create symlink for terminal access
echo "Creating terminal command..."
sudo ln -sf "$INSTALL_DIR/kube_ease" /usr/local/bin/kube-ease

# Create desktop entry
echo "Creating desktop entry..."
sudo tee /usr/share/applications/kube-ease.desktop > /dev/null <<EOF
[Desktop Entry]
Type=Application
Name=KubeEase
Comment=Kubernetes Cluster Manager - Visual interface for kubectl
Exec=$INSTALL_DIR/kube_ease
Icon=kube-ease
Terminal=false
Categories=Development;Utility;System;
Keywords=kubernetes;kubectl;k8s;docker;containers;
StartupWMClass=com.kubeease.KubeEase
EOF

# Update desktop database
if command -v update-desktop-database &> /dev/null; then
  echo "Updating desktop database..."
  sudo update-desktop-database /usr/share/applications
fi

# Update icon cache
if command -v gtk-update-icon-cache &> /dev/null; then
  echo "Updating icon cache..."
  sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
fi

echo -e "${GREEN}✓ Installation complete!${NC}"
echo ""
echo "You can now run KubeEase by:"
echo "  1. Typing 'kube-ease' in the terminal"
echo "  2. Searching for 'KubeEase' in your application menu"
echo ""
echo -e "${YELLOW}Note: Make sure kubectl is installed and configured.${NC}"


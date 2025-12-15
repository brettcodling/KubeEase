#!/bin/bash

# KubeEase Uninstallation Script for Linux

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

echo -e "${YELLOW}Uninstalling KubeEase...${NC}"

# Remove installation directory
if [ -d "/opt/kube_ease" ]; then
  echo "Removing installation directory..."
  sudo rm -rf /opt/kube_ease
else
  echo "Installation directory not found (already removed?)"
fi

# Remove desktop entry
if [ -f "/usr/share/applications/kube-ease.desktop" ]; then
  echo "Removing desktop entry..."
  sudo rm /usr/share/applications/kube-ease.desktop
else
  echo "Desktop entry not found (already removed?)"
fi

# Remove symlink
if [ -L "/usr/local/bin/kube-ease" ]; then
  echo "Removing terminal command..."
  sudo rm /usr/local/bin/kube-ease
else
  echo "Terminal command not found (already removed?)"
fi

# Remove icons
if [ -f "/usr/share/icons/hicolor/512x512/apps/kube-ease.png" ]; then
  echo "Removing icon..."
  sudo rm /usr/share/icons/hicolor/512x512/apps/kube-ease.png
fi

if [ -f "/usr/share/pixmaps/kube-ease.png" ]; then
  sudo rm /usr/share/pixmaps/kube-ease.png
fi

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

echo -e "${GREEN}✓ KubeEase has been uninstalled.${NC}"


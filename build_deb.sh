#!/bin/bash
set -e

# Usage: ./build_deb.sh <version>
# Example: ./build_deb.sh 1.0.4

VERSION="$1"

if [[ -z "$VERSION" ]]; then
  echo "Error: version argument is required."
  echo "Usage: $0 <version>  (e.g. $0 1.0.4)"
  exit 1
fi

STAGING="/tmp/kubeease-deb"
OUTPUT="kubeease_${VERSION}_amd64.deb"

echo "Building KubeEase v${VERSION}..."

flutter build linux --release --dart-define=APP_VERSION="$VERSION"

echo "Packaging .deb..."

rm -rf "$STAGING"
mkdir -p \
  "$STAGING/DEBIAN" \
  "$STAGING/opt/kube-ease" \
  "$STAGING/usr/share/applications" \
  "$STAGING/usr/share/icons/hicolor/512x512/apps" \
  "$STAGING/usr/share/pixmaps" \
  "$STAGING/usr/local/bin"

cp -r build/linux/x64/release/bundle/* "$STAGING/opt/kube-ease/"
cp assets/icon.png "$STAGING/usr/share/icons/hicolor/512x512/apps/kube-ease.png"
cp assets/icon.png "$STAGING/usr/share/pixmaps/kube-ease.png"

cat > "$STAGING/usr/share/applications/kube-ease.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=KubeEase
Comment=Kubernetes Cluster Manager - Visual interface for kubectl
Exec=/opt/kube-ease/kube_ease
Icon=kube-ease
Terminal=false
Categories=Development;Utility;System;
Keywords=kubernetes;kubectl;k8s;docker;containers;
StartupWMClass=com.kubeease.KubeEase
EOF

cat > "$STAGING/DEBIAN/control" << EOF
Package: kubeease
Version: $VERSION
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Brett Codling <brettcodling94@gmail.com>
Description: Modern Kubernetes cluster manager
 KubeEase provides an intuitive desktop interface for managing your
 Kubernetes resources with features like interactive terminals, file
 transfer, log streaming, and port forwarding.
 .
 Requires kubectl to be installed and configured.
EOF

cat > "$STAGING/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e
ln -sf /opt/kube-ease/kube_ease /usr/local/bin/kube-ease
chmod +x /opt/kube-ease/kube_ease
if command -v gtk-update-icon-cache &> /dev/null; then
  gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
fi
if command -v update-desktop-database &> /dev/null; then
  update-desktop-database /usr/share/applications || true
fi
if ! command -v kubectl &> /dev/null; then
  echo "WARNING: kubectl is not installed or not in PATH"
  echo "KubeEase requires kubectl to function properly"
  echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/"
fi
EOF
chmod +x "$STAGING/DEBIAN/postinst"

cat > "$STAGING/DEBIAN/postrm" << 'EOF'
#!/bin/bash
set -e
rm -f /usr/local/bin/kube-ease
if command -v gtk-update-icon-cache &> /dev/null; then
  gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
fi
if command -v update-desktop-database &> /dev/null; then
  update-desktop-database /usr/share/applications || true
fi
EOF
chmod +x "$STAGING/DEBIAN/postrm"

dpkg-deb --build "$STAGING" "$OUTPUT"
rm -rf "$STAGING"

echo ""
echo "Done: $OUTPUT"
ls -lh "$OUTPUT"

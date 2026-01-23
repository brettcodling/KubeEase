# KubeEase

A modern, cross-platform Kubernetes cluster manager built with Flutter. KubeEase provides an intuitive desktop interface for managing your Kubernetes resources with features like interactive terminals, file transfer, log streaming, and port forwarding.

## Features

### 🚀 Core Functionality
- **Multi-Context Support** - Switch between different Kubernetes contexts seamlessly with automatic external change detection
- **Namespace Filtering** - Select and filter resources across multiple namespaces with search capability
- **Namespace Memory** - Automatically remembers your namespace selections per context
- **Resource Management** - View and manage Pods, Deployments, Secrets, and CronJobs
- **Real-time Updates** - Live streaming of resource states and events
- **External Sync** - Automatically detects and syncs with kubectl context changes
- **Automatic Token Refresh** - Seamlessly handles expired authentication tokens for cloud-managed clusters (GKE, EKS, AKS)
- **Resource Metrics** - Real-time CPU and memory usage monitoring with historical charts

### 🖥️ Interactive Tools
- **Container Terminals** - Open interactive bash/sh sessions directly to pod containers
- **File Transfer** - Upload and download files to/from containers with visual file browser
- **Log Streaming** - Real-time log viewing with follow mode
- **Port Forwarding** - Forward container ports to localhost with visual management
- **Session Management** - Minimize and restore terminal/log sessions without losing state

### 📁 File Management
- **Smart Upload** - Upload files to the current directory in your terminal session
- **Visual Download** - Browse and select multiple files/directories with a visual file picker
- **File Filtering** - Search and filter files in the download dialog for quick selection
- **Overwrite Protection** - Warnings when downloading files that already exist locally
- **Bulk Operations** - Download multiple files at once
- **Directory Tracking** - Automatically tracks your current directory in terminal sessions

### 💡 User Experience
- **Dark Theme** - Modern dark UI optimized for extended use
- **Responsive Design** - Adaptive layout with minimum window size enforcement
- **Selectable Text** - Copy pod names, IPs, labels, and other details easily
- **Visual Indicators** - Color-coded status badges and health indicators
- **Input Protection** - Terminal blocks input until fully initialized to prevent errors
- **Debug Menu** - Built-in debug tools for testing and troubleshooting (debug builds only)

## Screenshots

*Coming soon*

## Installation

### Prerequisites
- Flutter SDK (3.0 or higher)
- kubectl configured with access to your Kubernetes cluster
- Linux, macOS, or Windows desktop environment

### Build from Source

1. Clone the repository:
```bash
git clone https://github.com/brettcodling/KubeEase.git
cd KubeEase
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the application:
```bash
flutter run -d linux  # or macos, windows
```

4. Build a release version:
```bash
flutter build linux  # or macos, windows
```

## Usage

### Getting Started

1. **Launch KubeEase** - The app will automatically load your kubeconfig from `~/.kube/config`
2. **Select Context** - Click the context dropdown in the app bar to switch between clusters
3. **Choose Namespaces** - Click the namespace filter button to select which namespaces to view
4. **Browse Resources** - Use the left sidebar to switch between resource types (Pods, Deployments, etc.)

> **📖 For detailed instructions, see the [User Guide](USER_GUIDE.md)**

### Working with Pods

- **View Details** - Click any pod to see detailed information, containers, events, and conditions
- **Monitor Metrics** - View real-time CPU and memory usage with historical charts showing resource requests and limits
- **Open Terminal** - Click the terminal icon to open an interactive shell in a container
- **View Logs** - Click the logs icon to stream container logs in real-time
- **Port Forward** - Click the forward icon next to any container port to forward it to localhost

### File Transfer

#### Upload Files
1. Open a terminal session to a container
2. Navigate to the target directory (e.g., `cd /var/www`)
3. Click the **upload button** in the terminal toolbar
4. Select a file from your local system
5. File uploads to the current directory automatically

#### Download Files
1. Open a terminal session to a container
2. Navigate to the directory containing files you want
3. Click the **download button** in the terminal toolbar
4. **Filter files** (optional) - Type in the search box to filter the file list
5. Select one or more files/directories from the visual file picker
6. Use **Select All** to select all filtered files at once
7. Choose a local directory to save files
8. Review overwrite warnings if files already exist
9. Files download with progress tracking

### Managing Sessions

- **Minimize** - Click the minimize button on any terminal or log session to dock it at the bottom
- **Restore** - Click a minimized session to bring it back to full view
- **Close** - Sessions automatically close if the pod is deleted
- **Input Protection** - Terminal blocks input until fully initialized (prevents typing errors)

### Port Forwarding

- **Start Forward** - Click the forward button (→) next to any port in the pod details
- **View Active Forwards** - Active port forwards show a badge icon in the app bar
- **Stop Forward** - Click the stop button (⏹) on an active forward, or use the dropdown menu
- **Auto Cleanup** - All port forwards are automatically stopped when the app closes

### Resource Metrics

KubeEase provides real-time monitoring of container resource usage:

- **Live Metrics** - CPU and memory usage updated every 10 seconds
- **Historical Charts** - Visual graphs showing the last 70 seconds of resource usage
- **Resource Limits** - Charts display configured requests and limits as reference lines
- **Per-Container** - Metrics shown individually for each container in a pod
- **Smart Tooltips** - Hover over data points to see exact values with properly aligned tooltips

**Metrics Display:**
- **CPU Usage** - Shown in cores (e.g., 0.250 cores = 250 millicores)
- **Memory Usage** - Shown in MB
- **Request Line** - Orange dashed line showing the configured resource request
- **Limit Line** - Red dashed line showing the configured resource limit
- **Actual Usage** - Blue line showing real-time resource consumption

**Note:** Metrics require `kubectl top` to be functional on your cluster (metrics-server must be installed).

### Context Management

- **Auto-Sync** - KubeEase automatically detects when you change contexts via kubectl
- **Namespace Memory** - Your namespace selections are remembered per context
- **Seamless Switching** - Switch contexts without losing your workflow preferences

### Authentication & Token Management

KubeEase automatically handles authentication token expiration for cloud-managed Kubernetes clusters:

- **Automatic Refresh** - Detects expired tokens (401 errors) and automatically refreshes credentials
- **Seamless Operation** - No user intervention required when tokens expire
- **Cloud Provider Support** - Works with GKE, EKS, AKS, and other cloud providers
- **Long-Running Sessions** - Run the app indefinitely without authentication interruptions

**How it works:**
1. Cloud providers (GKE, EKS, AKS) use short-lived authentication tokens (typically 1 hour)
2. When a token expires, KubeEase detects the 401 error automatically
3. The app reinitializes the Kubernetes client to fetch fresh tokens
4. Failed operations are automatically retried with the new credentials
5. You continue working without any interruption

### Debug Menu (Development Only)

When running in debug mode (`flutter run`), KubeEase provides a debug menu for testing and troubleshooting:

- **Access** - Click the orange bug icon (🐛) in the app bar
- **Simulate 401 Error** - Test the automatic token refresh mechanism
- **Future Options** - Extensible menu for additional debug features

**Note:** The debug menu is automatically removed from release builds and will not appear in production installations.

## Configuration

KubeEase uses your existing kubectl configuration. Ensure your `~/.kube/config` file is properly configured with:
- Valid cluster endpoints
- Authentication credentials (certificates, tokens, etc.)
- Context definitions

## Development

### Project Structure

```
lib/
├── main.dart                 # Application entry point
├── screens/                  # UI screens
│   ├── cluster_view_screen.dart
│   ├── pod_detail_screen.dart
│   ├── deployment_detail_screen.dart
│   ├── secret_detail_screen.dart
│   └── cron_job_detail_screen.dart
├── widgets/                  # Reusable UI components
│   ├── resource_content.dart
│   ├── logs_overlay.dart
│   └── ...
├── services/                 # Business logic and API clients
│   ├── kubernetes_service.dart
│   ├── session_manager.dart
│   ├── port_forward_manager.dart
│   └── pods/
└── models/                   # Data models
```

### Key Dependencies

- **k8s** (1.27.0+dev.2) - Kubernetes API client for Dart
- **xterm** (3.5.0) - Terminal emulator widget
- **pty** (0.3.1) - Pseudo-terminal support for interactive shells
- **window_manager** (0.4.2) - Desktop window management
- **file_picker** (4.6.1) - Native file picker for upload/download
- **watcher** (1.2.0) - File system monitoring for kubeconfig changes
- **fl_chart** (1.1.1) - Beautiful charts for metrics visualization

### Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Documentation

- **[User Guide](USER_GUIDE.md)** - Comprehensive guide covering all features
- **[README](README.md)** - Quick start and overview (this file)

## Roadmap

### Completed ✅
- [x] Interactive terminal sessions with PTY support
- [x] File upload/download with visual file picker
- [x] Multi-select file downloads
- [x] Overwrite protection for downloads
- [x] Current directory tracking in terminals
- [x] External kubeconfig change detection
- [x] Namespace memory per context
- [x] Terminal input protection during initialization
- [x] Persistent namespace preferences
- [x] Search/filter in file picker
- [x] Real-time resource metrics with historical charts
- [x] Automatic authentication token refresh
- [x] Support for custom resources (CRDs)

### Planned 🚀
- [ ] Support for more resource types (Services, ConfigMaps, StatefulSets, etc.)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built with [Flutter](https://flutter.dev/)
- Kubernetes API client: [k8s](https://pub.dev/packages/k8s)
- Terminal emulator: [xterm.dart](https://pub.dev/packages/xterm)
- Pseudo-terminal: [pty](https://pub.dev/packages/pty)
- File picker: [file_picker](https://pub.dev/packages/file_picker)
- File watcher: [watcher](https://pub.dev/packages/watcher)
- Charts: [fl_chart](https://pub.dev/packages/fl_chart)

## Support

If you encounter any issues or have questions:
- Open an issue on [GitHub](https://github.com/brettcodling/KubeEase/issues)
- Check existing issues for solutions

---

**Note**: KubeEase is a desktop application and requires kubectl to be installed and configured on your system. It does not replace kubectl but provides a visual interface for common operations.
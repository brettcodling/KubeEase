# KubeEase

A modern, cross-platform Kubernetes cluster manager built with Flutter. KubeEase provides an intuitive desktop interface for managing your Kubernetes resources with features like interactive terminals, log streaming, and port forwarding.

## Features

### 🚀 Core Functionality
- **Multi-Context Support** - Switch between different Kubernetes contexts seamlessly
- **Namespace Filtering** - Select and filter resources across multiple namespaces
- **Resource Management** - View and manage Pods, Deployments, Secrets, and CronJobs
- **Real-time Updates** - Live streaming of resource states and events

### 🖥️ Interactive Tools
- **Container Terminals** - Open interactive bash/sh sessions directly to pod containers
- **Log Streaming** - Real-time log viewing with follow mode
- **Port Forwarding** - Forward container ports to localhost with visual management
- **Session Management** - Minimize and restore terminal/log sessions without losing state

### 💡 User Experience
- **Dark Theme** - Modern dark UI optimized for extended use
- **Responsive Design** - Adaptive layout with minimum window size enforcement
- **Selectable Text** - Copy pod names, IPs, labels, and other details easily
- **Visual Indicators** - Color-coded status badges and health indicators

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

### Working with Pods

- **View Details** - Click any pod to see detailed information, containers, events, and conditions
- **Open Terminal** - Click the terminal icon to open an interactive shell in a container
- **View Logs** - Click the logs icon to stream container logs in real-time
- **Port Forward** - Click the forward icon next to any container port to forward it to localhost

### Managing Sessions

- **Minimize** - Click the minimize button on any terminal or log session to dock it at the bottom
- **Restore** - Click a minimized session to bring it back to full view
- **Close** - Sessions automatically close if the pod is deleted

### Port Forwarding

- **Start Forward** - Click the forward button (→) next to any port in the pod details
- **View Active Forwards** - Active port forwards show a badge icon in the app bar
- **Stop Forward** - Click the stop button (⏹) on an active forward, or use the dropdown menu
- **Auto Cleanup** - All port forwards are automatically stopped when the app closes

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

- **k8s** - Kubernetes API client for Dart
- **xterm** - Terminal emulator widget
- **pty** - Pseudo-terminal support for interactive shells
- **window_manager** - Desktop window management

### Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Roadmap

- [ ] Support for more resource types (Services, ConfigMaps, StatefulSets, etc.)
- [ ] Resource editing and YAML export
- [ ] Multi-cluster dashboard view
- [ ] Custom resource definitions (CRD) support
- [ ] Metrics and resource usage graphs
- [ ] Theme customization options

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built with [Flutter](https://flutter.dev/)
- Kubernetes API client: [k8s](https://pub.dev/packages/k8s)
- Terminal emulator: [xterm.dart](https://pub.dev/packages/xterm)

## Support

If you encounter any issues or have questions:
- Open an issue on [GitHub](https://github.com/brettcodling/KubeEase/issues)
- Check existing issues for solutions

---

**Note**: KubeEase is a desktop application and requires kubectl to be installed and configured on your system. It does not replace kubectl but provides a visual interface for common operations.
# KubeEase User Guide

Welcome to KubeEase! This comprehensive guide will help you get the most out of your Kubernetes cluster management experience.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Interface Overview](#interface-overview)
3. [Working with Contexts](#working-with-contexts)
4. [Managing Namespaces](#managing-namespaces)
5. [Viewing Resources](#viewing-resources)
6. [Pod Management](#pod-management)
7. [Terminal Sessions](#terminal-sessions)
8. [File Transfer](#file-transfer)
9. [Log Viewing](#log-viewing)
10. [Port Forwarding](#port-forwarding)
11. [Session Management](#session-management)
12. [Tips & Tricks](#tips--tricks)
13. [Troubleshooting](#troubleshooting)

---

## Getting Started

### Prerequisites

Before using KubeEase, ensure you have:

- **kubectl** installed and configured on your system
- A valid kubeconfig file at `~/.kube/config`
- Access credentials for your Kubernetes cluster(s)
- Linux, macOS, or Windows desktop environment

### First Launch

1. **Start KubeEase** - Launch the application from your applications menu or terminal
2. **Automatic Configuration** - KubeEase automatically loads your kubeconfig from `~/.kube/config`
3. **Initial View** - You'll see the main interface with the current context loaded

> **Note**: If you see an authentication error, verify that your kubeconfig is properly configured and you have valid credentials.

---

## Interface Overview

### Main Components

The KubeEase interface consists of several key areas:

#### 1. **Top App Bar**
- **Ship Helm Icon** - Application logo and branding
- **Context Selector** - Dropdown to switch between Kubernetes contexts
- **Namespace Filter Button** - Opens the namespace selection drawer
- **Port Forward Badge** - Shows count of active port forwards (when applicable)

#### 2. **Left Sidebar (Resource Menu)**
- **Pods** - View and manage pod resources
- **Deployments** - View deployment information
- **Secrets** - Browse Kubernetes secrets
- **CronJobs** - Manage scheduled jobs

#### 3. **Main Content Area**
- Displays the list of resources based on your selection
- Shows real-time status updates
- Provides quick actions for each resource

#### 4. **Bottom Session Bar**
- Displays minimized terminal and log sessions
- Click to restore sessions to full view
- Shows session type and target information

---

## Working with Contexts

Kubernetes contexts allow you to switch between different clusters or user configurations.

### Viewing Available Contexts

1. Click the **context dropdown** in the top app bar
2. View all available contexts from your kubeconfig
3. The current context is highlighted

### Switching Contexts

1. Click the **context dropdown**
2. Select the desired context from the list
3. KubeEase will:
   - Cancel all active watchers
   - Clear current selections
   - Load namespaces from the new context
   - Restore your previously selected namespaces for this context (if any)
   - Navigate back to the home screen

### Context Memory

KubeEase remembers your namespace selections for each context:
- When you switch contexts, your previous namespace selections are restored
- This memory is session-based (not persisted between app restarts)
- Makes it easy to switch between contexts without reconfiguring each time

### External Context Changes

KubeEase automatically detects when you change contexts externally (via kubectl):
- Monitors `~/.kube/config` for changes
- Automatically updates when external changes are detected
- Clears selections and navigates to home screen
- Ensures the app stays in sync with your kubectl configuration

---

## Managing Namespaces

Namespaces help you organize and filter Kubernetes resources.

### Opening the Namespace Drawer

Click the **filter icon** (funnel) in the top app bar to open the namespace drawer on the right side.

### Selecting Namespaces

#### Individual Selection
1. Open the namespace drawer
2. Check the boxes next to the namespaces you want to view
3. Uncheck boxes to remove namespaces from your view
4. Changes apply immediately

#### Bulk Selection
- **Select All** - Click the "Select All" button to choose all namespaces
- **Clear All** - Click the "Clear All" button to deselect all namespaces

#### Search and Filter
1. Use the search box at the top of the drawer
2. Type to filter namespaces by name
3. Search is case-insensitive and matches partial names
4. Select/deselect from filtered results

### Namespace Requirements

> **Important**: You must select at least one namespace to view resources. If no namespaces are selected, you'll see a message prompting you to select namespaces.

---

## Viewing Resources

### Resource Types

KubeEase supports viewing the following resource types:

#### Pods
- View all pods across selected namespaces
- See pod status, age, and restart count
- Quick access to terminals, logs, and port forwarding

#### Deployments
- View deployment configurations
- See replica counts and status
- Monitor deployment health

#### Secrets
- Browse Kubernetes secrets
- View secret metadata
- See data keys (values are hidden for security)

#### CronJobs
- View scheduled jobs
- See schedule and last run time
- Monitor job status

### Resource List Features

Each resource card displays:
- **Name** - Resource identifier
- **Namespace** - Which namespace it belongs to
- **Status** - Current state with color-coded badges
- **Age** - How long the resource has existed
- **Additional Info** - Resource-specific details

### Real-time Updates

- Resource lists update automatically
- Status changes appear in real-time
- No manual refresh needed
- Updates pause when viewing detail screens (resumes on return)

---

## Pod Management

### Viewing Pod Details

1. Click on any pod card in the list
2. The detail screen shows:
   - **Overview** - Pod name, namespace, status, IP address
   - **Containers** - List of all containers in the pod
   - **Labels** - Key-value labels attached to the pod
   - **Conditions** - Pod condition status
   - **Events** - Recent events related to the pod

### Pod Status Indicators

- **Running** - Green badge, pod is running normally
- **Pending** - Yellow badge, pod is being scheduled
- **Failed** - Red badge, pod has failed
- **Succeeded** - Blue badge, pod completed successfully
- **Unknown** - Gray badge, status cannot be determined

### Container Information

For each container, you can see:
- Container name
- Image being used
- Exposed ports
- Ready status

### Quick Actions

From the pod detail screen, you can:
- Open a terminal session
- View container logs
- Forward ports to localhost
- Copy pod information

---

## Terminal Sessions

### Opening a Terminal

#### From Pod List
1. Hover over a pod card
2. Click the **terminal icon** (monitor symbol)
3. Select the container (if pod has multiple containers)

#### From Pod Detail Screen
1. Navigate to the pod details
2. Click the **terminal icon** next to the desired container
3. Terminal opens in a new view

### Using the Terminal

#### Initial Connection
- Wait for "Initializing terminal..." message to disappear
- A semi-transparent overlay prevents typing until ready
- Terminal is ready when you see the shell prompt
- Prevents input issues during initialization

#### Terminal Features
- **Full Interactive Shell** - Bash or sh depending on container
- **Command History** - Use up/down arrows to navigate history
- **Tab Completion** - Tab key for command completion (if supported by shell)
- **Copy/Paste** - Standard keyboard shortcuts work
- **Resize** - Terminal adapts to window size changes
- **Scrollback** - 10,000 lines of history

#### Current Directory Tracking
- KubeEase automatically tracks your current directory
- Monitors shell prompt output to detect directory changes
- Used for file upload/download operations
- Works with standard bash/sh prompts

### Terminal Toolbar

The terminal includes a toolbar with the following buttons:

#### Upload File
1. Click the **upload icon** (upload arrow)
2. Select a file from your local system
3. File uploads to the **current directory** in the terminal
4. Progress shown in a snackbar notification
5. Success/failure message displayed when complete

#### Download Files
1. Click the **download icon** (download arrow)
2. Wait while KubeEase fetches the file list from current directory
3. **File Selection Dialog** appears showing all files/directories
4. Select one or more items to download:
   - Check individual items
   - Use "Select All" to select everything
5. Click "Download X file(s)" button
6. Choose a local directory to save files
7. **Overwrite Warning** (if applicable):
   - If any selected items already exist locally, a warning appears
   - Lists all items that will be overwritten
   - Choose "Cancel" to abort or "Overwrite" to proceed
8. Files download with progress indicator
9. Success message shows count of downloaded files

---

## File Transfer

### Upload Files to Container

**Prerequisites**: Have a terminal session open to the target container

**Steps**:
1. Navigate to the desired directory in the terminal (e.g., `cd /var/www`)
2. Click the **upload button** in the terminal toolbar
3. Select a file from your local system using the file picker
4. File uploads to the current directory
5. Wait for confirmation message

**Features**:
- Uploads to the current working directory in the terminal
- Automatic directory tracking (no need to specify path)
- Progress indicator during upload
- Success/failure notifications
- Uses `kubectl cp` under the hood

**Example**:
```bash
# In terminal, navigate to target directory
cd /var/www/html

# Click upload button, select index.html
# File uploads to /var/www/html/index.html
```

### Download Files from Container

**Prerequisites**: Have a terminal session open to the target container

**Steps**:
1. Navigate to the directory containing files you want to download
2. Click the **download button** in the terminal toolbar
3. Wait for file list to load (shows "Loading files..." dialog)
4. Select files/directories from the list:
   - Individual selection by checking boxes
   - "Select All" to choose everything
   - Download button shows count: "Download X file(s)"
5. Click the download button
6. Choose a local directory to save files
7. If files exist, review overwrite warning:
   - Lists all conflicting items in red
   - Choose to cancel or overwrite
8. Wait for download to complete
9. Check success message for results

**Features**:
- Visual file browser for current directory
- Multi-select capability
- Overwrite protection with warnings
- Bulk download support
- Progress tracking
- Success/failure reporting

**Tips**:
- Hidden files (starting with `.`) are included in the list
- Directories can be selected and downloaded
- Search/filter not available (navigate to specific directories instead)
- Downloads preserve original filenames

---

## Log Viewing

### Opening Logs

#### From Pod List
1. Hover over a pod card
2. Click the **logs icon** (document symbol)
3. Select the container (if pod has multiple containers)

#### From Pod Detail Screen
1. Navigate to the pod details
2. Click the **logs icon** next to the desired container
3. Logs open in a new view

### Log Viewer Features

#### Real-time Streaming
- Logs stream in real-time (follow mode)
- New log lines appear automatically
- Auto-scrolls to show latest entries
- No manual refresh needed

#### Log Controls
- **Auto-scroll Toggle** - Enable/disable automatic scrolling
- **Clear Logs** - Clear the current log buffer
- **Copy** - Select and copy log text
- **Search** - Find specific text in logs (if available)

#### Log Display
- Monospace font for readability
- Timestamps included (if available from container)
- Color-coded severity levels (if supported)
- Scrollable history

### Managing Log Sessions

- **Minimize** - Click minimize to dock at bottom
- **Restore** - Click minimized session to restore
- **Close** - Close button to end log streaming
- **Auto-close** - Session closes if pod is deleted

---

## Port Forwarding

Port forwarding allows you to access container ports on your local machine.

### Starting a Port Forward

#### From Pod Detail Screen
1. Navigate to the pod details
2. Find the container with the port you want to forward
3. Click the **forward arrow icon** (→) next to the port number
4. Port forward starts immediately
5. Badge appears in app bar showing active forwards count

### Viewing Active Port Forwards

1. Click the **port forward badge** in the top app bar
2. Dropdown shows all active forwards:
   - Pod name and namespace
   - Container name
   - Local port → Remote port mapping
   - Stop button for each forward

### Accessing Forwarded Ports

Once a port forward is active:
- Access via `localhost:<local-port>` in your browser or application
- Example: If forwarding port 8080, visit `http://localhost:8080`
- Local port matches the container port by default

### Stopping Port Forwards

**Individual Forward**:
1. Click the port forward badge
2. Click the **stop button** (⏹) next to the forward you want to stop

**All Forwards**:
- All port forwards automatically stop when you close KubeEase

### Port Forward Status

- **Active** - Green indicator, forward is working
- **Failed** - Red indicator, forward encountered an error
- **Stopped** - Forward has been terminated

### Troubleshooting Port Forwards

If a port forward fails:
- Check that the pod is running
- Verify the port number is correct
- Ensure the local port is not already in use
- Check your network connectivity to the cluster

---

## Session Management

KubeEase allows you to minimize and restore terminal and log sessions without losing state.

### Session Types

- **Terminal Sessions** - Interactive shell connections
- **Log Sessions** - Real-time log streaming

### Minimizing Sessions

1. Click the **minimize button** (−) in the session window
2. Session docks to the bottom session bar
3. Session continues running in the background
4. Terminal input/output and log streaming continue

### Restoring Sessions

1. Locate the minimized session in the bottom bar
2. Click on the session card
3. Session restores to full view
4. All history and state preserved

### Session Bar Features

Each minimized session shows:
- **Session Type Icon** - Terminal or log indicator
- **Pod Name** - Which pod the session is connected to
- **Container Name** - Which container (if applicable)
- **Namespace** - Which namespace the pod is in

### Session Persistence

- Sessions persist when navigating between screens
- Terminal history is maintained
- Log buffer is preserved
- Port forwards remain active

### Closing Sessions

- Click the **close button** (×) on a session
- Sessions auto-close if the target pod is deleted
- All sessions close when KubeEase exits

---

## Tips & Tricks

### Keyboard Shortcuts

- **Ctrl+C** - Copy selected text
- **Ctrl+V** - Paste in terminal
- **Ctrl+Shift+C** - Copy in terminal (alternative)
- **Ctrl+Shift+V** - Paste in terminal (alternative)

### Efficient Workflow

#### Multi-Namespace Monitoring
1. Select multiple namespaces to view resources across them
2. Use the search feature to quickly find specific namespaces
3. Context switching remembers your namespace selections

#### Quick Pod Access
1. Keep frequently accessed pods in a dedicated namespace
2. Use the search/filter to quickly locate pods
3. Minimize terminal sessions to keep them accessible

#### File Management
1. Navigate to the target directory before uploading
2. Use bulk download to grab multiple files at once
3. Pay attention to overwrite warnings to avoid data loss

#### Session Organization
1. Minimize sessions you want to keep but aren't actively using
2. Close sessions you no longer need to reduce clutter
3. Use descriptive pod names to easily identify minimized sessions

### Performance Tips

- **Limit Namespace Selection** - Selecting fewer namespaces improves performance
- **Close Unused Sessions** - Reduce resource usage by closing inactive sessions
- **Monitor Resource Count** - Large numbers of resources may slow down the UI

### Text Selection and Copying

- **Pod Names** - Click to select, then copy
- **IP Addresses** - Selectable from pod details
- **Labels** - Copy label keys and values
- **Log Output** - Select and copy log text
- **Terminal Output** - Select and copy command output

### Working with Multiple Containers

When a pod has multiple containers:
1. Terminal and log icons show a dropdown
2. Select the specific container you want to access
3. Each container can have its own terminal/log session
4. Sessions are tracked independently per container

---

## Troubleshooting

### Common Issues and Solutions

#### "No Namespaces Selected" Message

**Problem**: Main screen shows "No Namespaces Selected"

**Solution**:
1. Click the namespace filter button (funnel icon)
2. Select at least one namespace
3. Resources will appear automatically

#### Authentication Errors

**Problem**: Error message about authentication failure

**Solutions**:
- Verify your kubeconfig is valid: `kubectl cluster-info`
- Check that your credentials haven't expired
- Ensure you have proper RBAC permissions
- Try switching to a different context

#### Terminal Won't Accept Input

**Problem**: Can't type in terminal immediately after opening

**Solution**:
- Wait for the "Initializing terminal..." overlay to disappear
- This is normal - the terminal blocks input until the shell is ready
- Usually takes 1-2 seconds

#### Port Forward Fails

**Problem**: Port forward doesn't start or fails immediately

**Solutions**:
- Verify the pod is in "Running" state
- Check that the port number is correct
- Ensure the local port isn't already in use
- Try a different local port
- Check cluster network connectivity

#### File Upload/Download Not Working

**Problem**: Files don't upload or download

**Solutions**:
- Verify you have a terminal session open
- Check that kubectl is installed and in your PATH
- Ensure you have write permissions in the target directory (upload)
- Verify the files exist in the current directory (download)
- Check available disk space

#### Resources Not Updating

**Problem**: Resource list doesn't show latest changes

**Solutions**:
- Check your network connection to the cluster
- Verify the namespace is still selected
- Try switching to a different resource type and back
- Restart KubeEase if the issue persists

#### Context Switch Not Working

**Problem**: Can't switch contexts or contexts don't appear

**Solutions**:
- Verify your kubeconfig has multiple contexts: `kubectl config get-contexts`
- Check that the kubeconfig file is valid
- Ensure you have access to the target cluster
- Try running `kubectl config use-context <context-name>` manually

#### Logs Not Streaming

**Problem**: Log viewer is empty or not updating

**Solutions**:
- Verify the container is running and producing logs
- Check that you selected the correct container
- Some containers may not output to stdout/stderr
- Try closing and reopening the log session

#### Session Disappeared

**Problem**: Minimized session is no longer in the session bar

**Explanation**:
- Sessions automatically close if the target pod is deleted
- This is expected behavior to prevent orphaned sessions
- You'll need to open a new session to the pod (if it still exists)

### Getting Help

If you encounter issues not covered here:

1. **Check kubectl** - Verify the same operation works with kubectl
2. **Review Logs** - Check the application console for error messages
3. **GitHub Issues** - Search existing issues at https://github.com/brettcodling/KubeEase/issues
4. **Report Bugs** - Open a new issue with:
   - Steps to reproduce
   - Expected vs actual behavior
   - KubeEase version
   - Operating system
   - Kubernetes cluster version

---

## Advanced Features

### External Context Monitoring

KubeEase automatically detects when you change contexts using kubectl:

**How it works**:
1. Monitors `~/.kube/config` for file changes
2. Detects when the current context changes
3. Automatically updates the UI
4. Clears current selections
5. Navigates back to home screen

**Benefits**:
- Stay in sync with kubectl commands
- No manual refresh needed
- Prevents confusion from context mismatches

### Namespace Memory

KubeEase remembers your namespace selections per context:

**How it works**:
1. When you select namespaces, they're stored for the current context
2. Switching contexts saves your current selections
3. Returning to a context restores your previous selections
4. Memory is session-based (cleared on app restart)

**Benefits**:
- Faster context switching
- No need to reselect namespaces each time
- Maintains your workflow preferences

### Session State Preservation

Terminal and log sessions maintain state across navigation:

**Preserved State**:
- Terminal command history
- Terminal scrollback buffer
- Current working directory
- Log output buffer
- Session configuration

**Not Preserved**:
- Sessions close if pod is deleted
- Sessions don't persist between app restarts
- Port forwards stop when app closes

---

## Best Practices

### Security

- **Secrets** - Be cautious when viewing secrets; values are hidden but keys are visible
- **Terminal Access** - Only open terminals to pods you trust
- **Port Forwards** - Close port forwards when not in use
- **File Transfers** - Verify file contents before uploading to production pods

### Resource Management

- **Namespace Selection** - Only select namespaces you need to monitor
- **Session Cleanup** - Close sessions when finished to free resources
- **Port Forward Limits** - Don't create excessive port forwards
- **Log Streaming** - Close log sessions for high-volume logs when not needed

### Workflow Optimization

- **Context Organization** - Use descriptive context names in your kubeconfig
- **Namespace Naming** - Follow consistent namespace naming conventions
- **Pod Labels** - Use labels to organize and identify pods
- **Session Management** - Minimize sessions you want to keep, close ones you don't

---

## Frequently Asked Questions

### Does KubeEase replace kubectl?

No, KubeEase is a visual interface that complements kubectl. It uses kubectl under the hood for some operations and requires kubectl to be installed.

### Can I edit resources in KubeEase?

Currently, KubeEase is focused on viewing and interacting with resources. Resource editing is on the roadmap for future releases.

### Does KubeEase work with all Kubernetes clusters?

KubeEase works with any Kubernetes cluster that kubectl can access, including:
- Local clusters (minikube, kind, k3s)
- Cloud providers (GKE, EKS, AKS)
- Self-hosted clusters
- OpenShift (with standard kubeconfig)

### Are my credentials stored by KubeEase?

No, KubeEase uses your existing kubeconfig file and doesn't store credentials separately. All authentication is handled through kubectl's standard mechanisms.

### Can I use KubeEase with multiple clusters simultaneously?

You can switch between contexts (clusters) easily, but you can only view one cluster at a time. Multi-cluster dashboard view is planned for a future release.

### What happens to sessions when I close KubeEase?

- Terminal sessions are terminated
- Log streaming stops
- Port forwards are stopped
- No state is persisted between app launches

### Can I customize the theme or appearance?

Currently, KubeEase uses a dark theme optimized for extended use. Theme customization is on the roadmap for future releases.

---

## Glossary

- **Context** - A Kubernetes configuration that includes cluster, user, and namespace information
- **Namespace** - A logical partition within a Kubernetes cluster for organizing resources
- **Pod** - The smallest deployable unit in Kubernetes, containing one or more containers
- **Container** - A lightweight, standalone executable package that includes everything needed to run software
- **Port Forward** - A tunnel that forwards traffic from your local machine to a pod
- **Session** - An active terminal or log connection to a container
- **Kubeconfig** - Configuration file that contains cluster access information
- **kubectl** - Command-line tool for interacting with Kubernetes clusters
- **RBAC** - Role-Based Access Control, Kubernetes' authorization mechanism

---

## Appendix

### Supported Resource Types

| Resource Type | View | Details | Terminal | Logs | Port Forward |
|--------------|------|---------|----------|------|--------------|
| Pods | ✅ | ✅ | ✅ | ✅ | ✅ |
| Deployments | ✅ | ✅ | ❌ | ❌ | ❌ |
| Secrets | ✅ | ✅ | ❌ | ❌ | ❌ |
| CronJobs | ✅ | ✅ | ❌ | ❌ | ❌ |

### Keyboard Shortcuts Reference

| Action | Shortcut |
|--------|----------|
| Copy | Ctrl+C |
| Paste | Ctrl+V |
| Copy (Terminal) | Ctrl+Shift+C |
| Paste (Terminal) | Ctrl+Shift+V |

### File Transfer Limitations

- Maximum file size: Limited by kubectl cp (typically several GB)
- Transfer speed: Depends on cluster network performance
- Concurrent transfers: One at a time per terminal session
- Directory upload: Not supported (upload files individually)
- Directory download: Supported (downloads as-is)

---

## Version Information

This user guide is for KubeEase version 1.0.0 and later.

For the latest updates and release notes, visit:
https://github.com/brettcodling/KubeEase

---

**Thank you for using KubeEase!**

We hope this guide helps you manage your Kubernetes clusters more efficiently. If you have suggestions for improving this guide or the application, please open an issue on GitHub.



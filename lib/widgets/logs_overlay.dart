import 'package:flutter/material.dart';
import '../services/session_manager.dart';
import '../main.dart';
import 'logs_viewer.dart';
import 'terminal_viewer.dart';

/// Widget that manages the session overlay system (minimized cards + full-screen dialog)
/// Handles both logs and terminal sessions
class SessionOverlay extends StatefulWidget {
  final Widget child;

  const SessionOverlay({super.key, required this.child});

  @override
  State<SessionOverlay> createState() => _SessionOverlayState();
}

class _SessionOverlayState extends State<SessionOverlay> {
  final SessionManager _sessionManager = SessionManager();
  Offset _buttonPosition = const Offset(16, 16); // Position from bottom-right

  @override
  void initState() {
    super.initState();
    _sessionManager.addListener(_onSessionsChanged);
  }

  @override
  void dispose() {
    _sessionManager.removeListener(_onSessionsChanged);
    super.dispose();
  }

  void _onSessionsChanged() {
    setState(() {});

    // Show full-screen dialog when there's an active session
    if (_sessionManager.activeSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sessionManager.activeSession != null) {
          _showSessionDialog(_sessionManager.activeSession!);
        }
      });
    }
  }

  void _showSessionDialog(Session session) {
    // Use the global navigator key to get the context
    final navigatorContext = KubernetesManagerApp.navigatorKey.currentContext;
    if (navigatorContext == null) return;

    showDialog(
      context: navigatorContext,
      barrierDismissible: false,
      builder: (context) => _SessionDialog(session: session),
    ).then((_) {
      // Dialog was closed, clear active session if it's still the same one
      if (_sessionManager.activeSession?.id == session.id) {
        _sessionManager.closeActive();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (builderContext) {
        return Stack(
          children: [
            widget.child,
            // Show floating icon when there are minimized sessions AND no active session
            if (_sessionManager.minimizedSessions.isNotEmpty && _sessionManager.activeSession == null)
              Positioned(
                bottom: _buttonPosition.dy,
                right: _buttonPosition.dx,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      // Update position as user drags (inverted because we're using bottom/right positioning)
                      _buttonPosition = Offset(
                        (_buttonPosition.dx - details.delta.dx).clamp(16.0, MediaQuery.of(context).size.width - 100),
                        (_buttonPosition.dy - details.delta.dy).clamp(16.0, MediaQuery.of(context).size.height - 100),
                      );
                    });
                  },
                  child: _MinimizedSessionsButton(sessions: _sessionManager.minimizedSessions),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Full-screen dialog for viewing a session (logs or terminal)
class _SessionDialog extends StatelessWidget {
  final Session session;

  const _SessionDialog({required this.session});

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(session.title),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.minimize),
              onPressed: () {
                SessionManager().minimizeActive();
                Navigator.of(context).pop();
              },
              tooltip: 'Minimize',
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                SessionManager().closeActive();
                Navigator.of(context).pop();
              },
              tooltip: 'Close',
            ),
          ],
        ),
        body: _buildSessionBody(session),
      ),
    );
  }

  Widget _buildSessionBody(Session session) {
    switch (session.type) {
      case SessionType.logs:
        return LogsViewer(
          kubernetesClient: session.kubernetesClient,
          namespace: session.namespace,
          jobName: session.podName,
          containerName: session.containerName,
          isPodLog: session.isPodLog,
        );
      case SessionType.terminal:
        return TerminalViewer(
          session: session,
        );
    }
  }
}

/// Floating button that shows a list of minimized sessions
class _MinimizedSessionsButton extends StatefulWidget {
  final List<Session> sessions;

  const _MinimizedSessionsButton({required this.sessions});

  @override
  State<_MinimizedSessionsButton> createState() => _MinimizedSessionsButtonState();
}

class _MinimizedSessionsButtonState extends State<_MinimizedSessionsButton> {
  bool _isMenuOpen = false;

  void _showSessionsList(BuildContext context) async {
    // Use the global navigator state
    final navigatorState = KubernetesManagerApp.navigatorKey.currentState;
    if (navigatorState == null) return;

    final overlayState = navigatorState.overlay;
    if (overlayState == null) return;

    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = overlayState.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    setState(() {
      _isMenuOpen = true;
    });

    await showMenu(
      context: overlayState.context,
      position: position,
      constraints: const BoxConstraints(
        minWidth: 300,
        maxWidth: 400,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 8,
      items: widget.sessions.map((session) {
        return PopupMenuItem(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Tooltip(
            message: session.title,
            waitDuration: const Duration(milliseconds: 500),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    session.icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(
                  session.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () {
                    KubernetesManagerApp.navigatorKey.currentState?.pop();
                    SessionManager().closeSession(session.id);
                  },
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                onTap: () {
                  KubernetesManagerApp.navigatorKey.currentState?.pop();
                  SessionManager().restoreSession(session.id);
                },
              ),
            ),
          ),
        );
      }).toList(),
    );

    setState(() {
      _isMenuOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Hide the button when the menu is open
    if (_isMenuOpen) {
      return const SizedBox.shrink();
    }

    // Determine icon based on session types
    final hasTerminal = widget.sessions.any((s) => s.type == SessionType.terminal);
    final hasLogs = widget.sessions.any((s) => s.type == SessionType.logs);
    final IconData displayIcon;

    if (hasTerminal && hasLogs) {
      displayIcon = Icons.layers_outlined;
    } else if (hasTerminal) {
      displayIcon = Icons.terminal;
    } else {
      displayIcon = Icons.article_outlined;
    }

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: () => _showSessionsList(context),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                displayIcon,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.sessions.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


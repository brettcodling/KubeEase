/// Model class representing a Kubernetes Event for a Pod
class PodEvent {
  final String type;
  final String reason;
  final String message;
  final String? timestamp;
  final int count;
  final String source;

  PodEvent({
    required this.type,
    required this.reason,
    required this.message,
    this.timestamp,
    required this.count,
    required this.source,
  });

  /// Factory constructor to create PodEvent from Kubernetes API response
  factory PodEvent.fromK8sEvent(dynamic event) {
    // Extract event type (Normal, Warning, Error)
    final type = event.type ?? 'Normal';
    
    // Extract reason (e.g., "Scheduled", "Pulling", "Started")
    final reason = event.reason ?? 'Unknown';
    
    // Extract message
    final message = event.message ?? '';
    
    // Extract timestamp (use lastTimestamp or firstTimestamp)
    String? timestamp;
    final lastTimestamp = event.lastTimestamp ?? event.firstTimestamp;
    if (lastTimestamp != null) {
      try {
        final DateTime eventTime;
        if (lastTimestamp is DateTime) {
          eventTime = lastTimestamp;
        } else if (lastTimestamp is String) {
          eventTime = DateTime.parse(lastTimestamp);
        } else {
          eventTime = DateTime.now();
        }
        
        final now = DateTime.now();
        final difference = now.difference(eventTime);
        
        if (difference.inDays > 0) {
          timestamp = '${difference.inDays}d ago';
        } else if (difference.inHours > 0) {
          timestamp = '${difference.inHours}h ago';
        } else if (difference.inMinutes > 0) {
          timestamp = '${difference.inMinutes}m ago';
        } else {
          timestamp = '${difference.inSeconds}s ago';
        }
      } catch (e) {
        timestamp = null;
      }
    }
    
    // Extract count (how many times this event occurred)
    final count = event.count ?? 1;

    // Extract source component - try different possible fields
    String source = 'Unknown';
    try {
      if (event.reportingComponent != null && event.reportingComponent.isNotEmpty) {
        source = event.reportingComponent;
      } else if (event.reportingInstance != null && event.reportingInstance.isNotEmpty) {
        source = event.reportingInstance;
      }
    } catch (e) {
      source = 'Unknown';
    }

    return PodEvent(
      type: type,
      reason: reason,
      message: message,
      timestamp: timestamp,
      count: count,
      source: source,
    );
  }
}


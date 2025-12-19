import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing persistent user preferences
/// Handles storing and retrieving namespace selections per context
class PreferencesService {
  static const String _namespacePrefix = 'namespace_selection_';
  
  static PreferencesService? _instance;
  SharedPreferences? _prefs;
  
  /// Private constructor for singleton pattern
  PreferencesService._();
  
  /// Get the singleton instance
  static PreferencesService get instance {
    _instance ??= PreferencesService._();
    return _instance!;
  }
  
  /// Initialize the preferences service
  /// Must be called before using any other methods
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('PreferencesService initialized');
  }
  
  /// Save namespace selections for a specific context
  /// 
  /// [contextName] - The Kubernetes context name
  /// [namespaces] - Set of selected namespace names
  Future<void> saveNamespaceSelection(String contextName, Set<String> namespaces) async {
    if (_prefs == null) {
      debugPrint('PreferencesService not initialized, cannot save namespace selection');
      return;
    }
    
    final key = _namespacePrefix + contextName;
    final namespaceList = namespaces.toList();
    
    await _prefs!.setStringList(key, namespaceList);
    debugPrint('Saved ${namespaceList.length} namespaces for context: $contextName');
  }
  
  /// Load namespace selections for a specific context
  /// 
  /// [contextName] - The Kubernetes context name
  /// Returns a Set of namespace names, or empty set if none saved
  Set<String> loadNamespaceSelection(String contextName) {
    if (_prefs == null) {
      debugPrint('PreferencesService not initialized, cannot load namespace selection');
      return {};
    }
    
    final key = _namespacePrefix + contextName;
    final namespaceList = _prefs!.getStringList(key);
    
    if (namespaceList != null && namespaceList.isNotEmpty) {
      debugPrint('Loaded ${namespaceList.length} namespaces for context: $contextName');
      return namespaceList.toSet();
    }
    
    return {};
  }
  
  /// Clear namespace selections for a specific context
  /// 
  /// [contextName] - The Kubernetes context name
  Future<void> clearNamespaceSelection(String contextName) async {
    if (_prefs == null) {
      debugPrint('PreferencesService not initialized, cannot clear namespace selection');
      return;
    }
    
    final key = _namespacePrefix + contextName;
    await _prefs!.remove(key);
    debugPrint('Cleared namespace selection for context: $contextName');
  }
  
  /// Clear all namespace selections for all contexts
  Future<void> clearAllNamespaceSelections() async {
    if (_prefs == null) {
      debugPrint('PreferencesService not initialized, cannot clear all namespace selections');
      return;
    }
    
    final keys = _prefs!.getKeys();
    final namespaceKeys = keys.where((key) => key.startsWith(_namespacePrefix));
    
    for (final key in namespaceKeys) {
      await _prefs!.remove(key);
    }
    
    debugPrint('Cleared all namespace selections');
  }
  
  /// Get all contexts that have saved namespace selections
  List<String> getContextsWithSavedSelections() {
    if (_prefs == null) {
      debugPrint('PreferencesService not initialized');
      return [];
    }
    
    final keys = _prefs!.getKeys();
    final namespaceKeys = keys.where((key) => key.startsWith(_namespacePrefix));
    
    return namespaceKeys
        .map((key) => key.substring(_namespacePrefix.length))
        .toList();
  }
}


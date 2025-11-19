import 'package:flutter/foundation.dart';

class GameSettings with ChangeNotifier {
  // Private variable to hold the state
  bool _isOmniscientMode = false;

  // Public "getter" for other widgets to read the value
  bool get isOmniscientMode => _isOmniscientMode;

  // Function to toggle the mode
  void toggleOmniscientMode() {
    _isOmniscientMode = !_isOmniscientMode;
    // This is the most important part:
    // It notifies all "listening" widgets that this value has changed.
    notifyListeners();
  }
}

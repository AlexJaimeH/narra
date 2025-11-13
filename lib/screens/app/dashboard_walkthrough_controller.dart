import 'package:flutter/foundation.dart';

class DashboardWalkthroughController {
  VoidCallback? _onTap;

  void setTapHandler(VoidCallback? handler) {
    _onTap = handler;
  }

  bool handleTap() {
    final handler = _onTap;
    if (handler == null) {
      return false;
    }

    handler();
    return true;
  }
}

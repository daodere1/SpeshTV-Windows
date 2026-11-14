import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

List<String> tvTransformIssues(Layer root) {
  final issues = <String>[];
  void visit(Layer layer, String path) {
    final here = '$path/${layer.runtimeType}';
    if (layer is OffsetLayer &&
        (!layer.offset.dx.isFinite || !layer.offset.dy.isFinite)) {
      issues.add('$here offset=${layer.offset}');
    }
    if (layer is TransformLayer) {
      final values = layer.transform?.storage;
      if (values != null && values.any((v) => !v.isFinite || v.abs() > 3.4e38)) {
        issues.add('$here matrix=$values');
      }
    }
    if (layer is FollowerLayer) {
      final values = layer.getLastTransform()?.storage;
      if (values != null && values.any((v) => !v.isFinite || v.abs() > 3.4e38)) {
        issues.add('$here follower=$values');
      }
    }
    if (layer is ContainerLayer) {
      var child = layer.firstChild;
      var index = 0;
      while (child != null) {
        visit(child, '$here[${index++}]');
        child = child.nextSibling;
      }
    }
  }
  visit(root, 'view');
  return issues;
}

/// Temporary, bounded trace: no titles, account data, or tokens are recorded.
class TvTransformTrace {
  Timer? _timer;
  bool _pending = false;
  bool _disposed = false;
  int _samples = 0;

  void start() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_pending || _disposed) return;
      if (_samples >= 120) { dispose(); return; }
      _pending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pending = false;
        if (_disposed) return;
        final issues = <String>[];
        for (final view in RendererBinding.instance.renderViews) {
          // The release layer tree is needed to distinguish Dart from engine errors.
          // ignore: invalid_use_of_protected_member
          final root = view.layer;
          if (root != null) issues.addAll(tvTransformIssues(root));
        }
        _samples++;
        if (issues.isNotEmpty || _samples % 10 == 0) {
          debugPrint('[SpeshTransform] sample=$_samples invalid=${issues.length}');
          for (final issue in issues.take(8)) { debugPrint('[SpeshTransform] $issue'); }
        }
      });
    });
  }

  void dispose() { _disposed = true; _timer?.cancel(); }
}

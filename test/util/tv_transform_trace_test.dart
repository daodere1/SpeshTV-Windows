import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/tv_transform_trace.dart';

void main() {
  test('finite transform layers produce no diagnostic issues', () {
    final root = OffsetLayer();
    root.append(TransformLayer(transform: Matrix4.identity()));
    expect(tvTransformIssues(root), isEmpty);
    root.dispose();
  });

  test('nonfinite offsets identify the nested layer path', () {
    final root = OffsetLayer();
    root.append(TransformLayer(transform: Matrix4.identity(),
      offset: const Offset(double.infinity, 0)));
    final issues = tvTransformIssues(root);
    expect(issues, hasLength(1));
    expect(issues.single, contains('TransformLayer'));
    expect(issues.single, contains('Infinity'));
    root.dispose();
  });
}

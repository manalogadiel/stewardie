import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Measures natural card heights before giving both cards the taller height.
/// Unlike intrinsic layout, this supports descendants using LayoutBuilder.
class EqualHeightRow extends MultiChildRenderObjectWidget {
  const EqualHeightRow({super.key, required super.children});
  @override
  RenderObject createRenderObject(BuildContext context) => _EqualRow();
}

class _CardData extends ContainerBoxParentData<RenderBox> {}

class _EqualRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CardData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CardData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CardData) child.parentData = _CardData();
  }

  @override
  void performLayout() {
    final width = (constraints.maxWidth - 12) / 2;
    var height = 0.0;
    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
      height = math.max(height, child.size.height);
      child = childAfter(child);
    }
    child = firstChild;
    var x = 0.0;
    while (child != null) {
      child.layout(
        // Keep height loose so a descendant's content change (for example a
        // six-week calendar month) can invalidate this row's measurement.
        // A tight height makes that child a relayout boundary with stale size.
        BoxConstraints(minWidth: width, maxWidth: width, minHeight: height),
        parentUsesSize: true,
      );
      height = math.max(height, child.size.height);
      (child.parentData! as _CardData).offset = Offset(x, 0);
      x += width + 12;
      child = childAfter(child);
    }
    size = constraints.constrain(Size(constraints.maxWidth, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

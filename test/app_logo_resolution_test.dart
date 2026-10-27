import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/widgets/app_logo.dart';

void main() {
  for (final ratio in [1.0, 2.0, 3.0]) {
    testWidgets('logo decodes only its displayed pixels at DPR $ratio', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(devicePixelRatio: ratio),
            child: const Center(child: AppLogo()),
          ),
        ),
      );
      final widget = tester.widget<Image>(find.byType(Image));
      final provider = widget.image as ResizeImage;
      expect(provider.width, (72 * ratio).ceil());
      expect(
        (provider.imageProvider as AssetImage).assetName,
        'assets/icon/icon_source.png',
      );
      expect(tester.getSize(find.byType(AppLogo)), const Size(72, 72));
      expect(widget.excludeFromSemantics, isTrue);
    });
  }
}

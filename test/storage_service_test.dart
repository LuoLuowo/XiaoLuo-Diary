import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:xiaoluo_diary/services/storage_service.dart';

void main() {
  test('识别照片 EXIF 原始拍摄时间', () async {
    final folder = await Directory.systemTemp.createTemp('xiaoluo_exif_');
    final file = File(p.join(folder.path, 'photo.jpg'));
    final image = img.Image(width: 8, height: 8);
    image.exif.exifIfd[0x9003] = img.IfdValueAscii('2024:05:06 07:08:09');
    await file.writeAsBytes(img.encodeJpg(image));

    final capturedAt = await StorageService().imageCaptureDate(file.path);

    expect(capturedAt, DateTime(2024, 5, 6, 7, 8, 9));
    await folder.delete(recursive: true);
  });
}

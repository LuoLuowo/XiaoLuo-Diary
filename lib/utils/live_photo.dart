import 'package:path/path.dart' as p;

/// Live Photo motion clips are stored in the normal video folder so that they
/// participate in export/restore, but are linked to their still image by name.
String livePhotoVideoName(String imagePath) =>
    'live_${_stableImageName(imagePath)}.mp4';

bool isLivePhotoVideo(String path) =>
    _stableImageName(path).toLowerCase().startsWith('live_') &&
    path.toLowerCase().endsWith('.mp4');

String? livePhotoVideoForImage(String imagePath, Iterable<String> videos) {
  final target = livePhotoVideoName(imagePath).toLowerCase();
  for (final video in videos) {
    if (p.basename(video).toLowerCase().endsWith(target)) return video;
  }
  return null;
}

String _stableImageName(String path) {
  // Backup restore adds a short hash before a filename. Keep the original
  // filename portion so a restored photo can still find its motion clip.
  return p.basename(path).replaceFirst(RegExp(r'^(?:[a-fA-F0-9]{12}-)+'), '');
}

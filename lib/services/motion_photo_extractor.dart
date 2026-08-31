import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Extracts the MP4 payload, not a recompressed bitmap. Some galleries use the
/// legacy MicroVideoOffset; newer JPEG/HEIC files use Container:Item or mpvd.
/// Locate the actual ISO-BMFF stream and validate its video track in all cases.
/// Scans in bounded chunks, so a large original never lives entirely in RAM.
Future<String?> extractMotionPhoto(String source, String target) async {
  final file = File(source);
  final reader = await file.open();
  (int, int)? range;
  try {
    final length = await reader.length();
    final prefix = await reader.read(64);
    final jpeg = prefix.length >= 2 && prefix[0] == 0xff && prefix[1] == 0xd8;
    final isoImage =
        prefix.length >= 12 &&
        latin1.decode(prefix.sublist(4, 8)) == 'ftyp' &&
        RegExp(
          'heic|heix|hevc|hevx|mif1|msf1|avif|avis',
        ).hasMatch(latin1.decode(prefix.sublist(8)));
    if (!jpeg && !isoImage) return null;

    const chunkSize = 256 * 1024;
    var position = 0;
    var candidates = 0;
    while (position < length && range == null) {
      await reader.setPosition(position);
      final chunk = await reader.read(chunkSize);
      if (chunk.length < 8) break;
      final text = latin1.decode(chunk);
      var found = text.indexOf('ftyp', 4);
      while (found >= 4) {
        final start = position + found - 4;
        // The first ftyp in a HEIC file describes the still, not the motion.
        if (start > 0) {
          if (++candidates > 512) return null; // malformed/adversarial input
          final end = await _videoEnd(reader, start, length);
          if (end != null) {
            range = (start, end);
            break;
          }
        }
        found = text.indexOf('ftyp', found + 4);
      }
      if (chunk.length < chunkSize) break;
      position += chunk.length - 16; // preserve box headers across chunks
    }
  } finally {
    await reader.close();
  }
  if (range == null) return null;
  final output = File(target);
  await output.parent.create(recursive: true);
  try {
    await file.openRead(range.$1, range.$2).pipe(output.openWrite());
    return output.path;
  } catch (_) {
    if (await output.exists()) await output.delete();
    rethrow;
  }
}

Future<({String type, int content, int end})?> _box(
  RandomAccessFile reader,
  int position,
  int limit,
) async {
  if (position + 8 > limit) return null;
  await reader.setPosition(position);
  final header = await reader.read(16);
  if (header.length < 8) return null;
  final data = ByteData.sublistView(header);
  var size = data.getUint32(0);
  var headerSize = 8;
  if (size == 1) {
    if (header.length < 16) return null;
    size = data.getUint64(8);
    headerSize = 16;
  } else if (size == 0) {
    size = limit - position;
  }
  if (size < headerSize || size > limit - position) return null;
  return (
    type: latin1.decode(header.sublist(4, 8)),
    content: position + headerSize,
    end: position + size,
  );
}

Future<int?> _videoEnd(RandomAccessFile reader, int start, int limit) async {
  final first = await _box(reader, start, limit);
  if (first == null ||
      first.type != 'ftyp' ||
      first.end - first.content < 8 ||
      first.end - first.content > 4096) {
    return null;
  }
  await reader.setPosition(first.content);
  final brands = latin1.decode(await reader.read(first.end - first.content));
  if (!RegExp('isom|iso[2-9]|mp4[12]|avc1|M4V |qt  |MSNV|3gp').hasMatch(brands))
    return null;
  var position = first.end;
  var hasVideo = false;
  var hasData = false;
  var lastEnd = first.end;
  for (var count = 0; count < 10000 && position < limit; count++) {
    final box = await _box(reader, position, limit);
    if (box == null ||
        !const {
          'moov',
          'mdat',
          'free',
          'skip',
          'wide',
          'uuid',
          'moof',
          'mfra',
          'sidx',
          'styp',
          'pdin',
          'meta',
        }.contains(box.type))
      break;
    if (box.type == 'moov') {
      hasVideo = await _hasVideoTrack(reader, box.content, box.end, 0);
    }
    if (box.type == 'mdat' && box.end > box.content) hasData = true;
    lastEnd = box.end;
    position = box.end;
  }
  // A mere "ftyp" byte sequence inside EXIF/thumbnail data is not enough.
  return hasVideo && hasData ? lastEnd : null;
}

Future<bool> _hasVideoTrack(
  RandomAccessFile reader,
  int start,
  int end,
  int depth,
) async {
  var position = start;
  for (var count = 0; count < 1000 && position < end; count++) {
    final box = await _box(reader, position, end);
    if (box == null) return false;
    if (depth == 2 && box.type == 'hdlr' && box.end - box.content >= 12) {
      await reader.setPosition(box.content + 8);
      if (latin1.decode(await reader.read(4)) == 'vide') return true;
    }
    final child = depth == 0 ? 'trak' : 'mdia';
    if (depth < 2 &&
        box.type == child &&
        await _hasVideoTrack(reader, box.content, box.end, depth + 1)) {
      return true;
    }
    position = box.end;
  }
  return false;
}

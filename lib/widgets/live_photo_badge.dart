import 'package:flutter/material.dart';

/// A non-interactive label: tapping anywhere still opens the photo itself.
class LivePhotoBadge extends StatelessWidget {
  const LivePhotoBadge({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xDEFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1F000000)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.motion_photos_on, size: 15, color: Color(0xFF25282A)),
          SizedBox(width: 4),
          Text(
            '实况',
            style: TextStyle(
              fontSize: 11,
              height: 1.1,
              color: Color(0xFF25282A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

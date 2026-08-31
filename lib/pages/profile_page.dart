import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/loading_operation.dart';
import 'package:provider/provider.dart';
import '../models/profile.dart';
import '../services/app_state.dart';
import '../services/storage_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final UserProfile original = context.read<AppState>().profile;
  late final nickname = TextEditingController(text: original.nickname);
  late final signature = TextEditingController(text: original.signature);
  late final birthday = TextEditingController(text: original.birthday);
  late final homeText = TextEditingController(text: original.homeText);
  late String avatar = original.avatarPath;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('个人资料'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(onPressed: _save, child: const Text('保存')),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: avatar.isNotEmpty
                        ? FileImage(File(avatar))
                        : null,
                    child: avatar.isEmpty
                        ? const Text('罗', style: TextStyle(fontSize: 30))
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton.filled(
                      onPressed: () async {
                        final storage = context.read<StorageService>();
                        try {
                          final paths = await runLoading(
                            context,
                            '正在选择并处理头像…',
                            (_) => storage.pickImages(),
                          );
                          if (paths.isNotEmpty && mounted)
                            setState(() => avatar = paths.first);
                        } catch (error) {
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('添加头像失败：$error')),
                            );
                        }
                      },
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: nickname,
              decoration: const InputDecoration(labelText: '昵称'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: signature,
              decoration: const InputDecoration(labelText: '个性签名'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: birthday,
              decoration: const InputDecoration(
                labelText: '生日（可选）',
                hintText: '例如：1998-05-20',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: homeText,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '主页展示文字'),
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> _save() async {
    await context.read<AppState>().saveProfile(
      original.copyWith(
        nickname: nickname.text.trim().isEmpty ? '小罗' : nickname.text.trim(),
        signature: signature.text.trim(),
        birthday: birthday.text.trim(),
        homeText: homeText.text.trim(),
        avatarPath: avatar,
      ),
    );
    if (mounted) Navigator.pop(context);
  }
}

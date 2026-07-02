import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:simple_chat/account/account.dart';
import 'package:simple_chat/account/account_repo.dart';
import 'package:simple_chat/profile/vcard_service.dart';
import 'package:simple_chat/service_locator/service_locator.dart';

class ProfilePage extends StatefulWidget {
  final AccountBloc accountBloc;
  const ProfilePage({Key? key, required this.accountBloc}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _accountRepo = sl.get<AccountRepo>();
  bool _uploading = false;
  String? _uploadError;
  File? _localPreview;

  UiAccount? get _uiAccount {
    final state = widget.accountBloc.state;
    if (state is AccountRegistered && state.account != null) {
      final targetId = '${state.account!.username}@${state.account!.domain}';
      for (final a in _accountRepo.currentAccounts) {
        if (a.id == targetId) return a;
      }
    }
    return null;
  }

  Future<void> _pickAndUploadPhoto() async {
    final account = _uiAccount;
    if (account == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;

    setState(() {
      _uploading = true;
      _uploadError = null;
      _localPreview = File(picked.path);
    });

    try {
      var compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        minWidth: 256,
        minHeight: 256,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      if (compressed == null) {
        throw Exception('Falha ao processar imagem');
      }

      int quality = 70;
      while (compressed!.length > VCardService.maxImageBytes && quality > 20) {
        quality -= 15;
        compressed = await FlutterImageCompress.compressWithFile(
          picked.path,
          minWidth: 200,
          minHeight: 200,
          quality: quality,
          format: CompressFormat.jpeg,
        );
        if (compressed == null) break;
      }

      if (compressed == null || compressed.length > VCardService.maxImageBytes) {
        throw Exception('Não foi possível comprimir a imagem o suficiente');
      }

      final ok = await VCardService.setAvatar(account, compressed);
      if (!ok) throw Exception('Servidor recusou a atualização da foto');

      setState(() => _uploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto atualizada!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() {
        _uploading = false;
        _uploadError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.accountBloc.state;
    String displayName = 'Usuário';
    if (state is AccountRegistered && state.account != null) {
      displayName = state.account!.username;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        children: [
          Container(
            color: const Color(0xFFF5F5F5),
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _uploading ? null : _pickAndUploadPhoto,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF4CD964), width: 3),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: const Color(0xFF1976D2),
                          backgroundImage: _localPreview != null
                              ? FileImage(_localPreview!)
                              : null,
                          child: _localPreview == null
                              ? Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      if (_uploading)
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1976D2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.circle, size: 10, color: Color(0xFF4CD964)),
                    SizedBox(width: 6),
                    Text('Online', style: TextStyle(color: Colors.black54)),
                  ],
                ),
                if (_uploadError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _uploadError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: Color(0xFF1976D2)),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Log out', style: TextStyle(color: Colors.redAccent)),
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text('Suas conversas continuarão salvas neste dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.accountBloc.add(Logout());
            },
            child: const Text('Sair', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

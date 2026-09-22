import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../auth/controllers/auth_controller.dart';
import '../../telegram/telegram_media_service.dart';
import 'collections_screen.dart';
import 'controllers/media_controller.dart';
import 'photos_screen.dart';
import 'repositories/media_repository.dart';
import 'widgets/nuvex_bottom_bar.dart';

/// The authenticated Nuvex Home workspace screen.
///
/// Contains strictly two navigation destinations:
/// 1. Photos (PhotosScreen)
/// 2. Collections (CollectionsScreen)
class HomeScreen extends StatefulWidget {
  final AuthController? controller;
  final MediaController? mediaController;

  const HomeScreen({super.key, this.controller, this.mediaController});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final MediaController _mediaController;

  @override
  void initState() {
    super.initState();
    _mediaController =
        widget.mediaController ??
        MediaController(
          repository: widget.controller?.telegramService != null
              ? MediaRepository(
                  mediaService: TelegramMediaService(
                    authService: widget.controller!.telegramService,
                  ),
                )
              : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: NuvexColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: NuvexColors.iceBackground,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            PhotosScreen(
              controller: widget.controller,
              mediaController: _mediaController,
            ),
            CollectionsScreen(
              controller: widget.controller,
              mediaController: _mediaController,
            ),
          ],
        ),
        bottomNavigationBar: NuvexBottomBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (_currentIndex != index) {
              setState(() {
                _currentIndex = index;
              });
            }
          },
        ),
      ),
    );
  }
}

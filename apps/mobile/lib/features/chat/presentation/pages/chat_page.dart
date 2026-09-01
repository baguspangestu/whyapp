import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/monetization/message_access_service.dart';
import '../../../../core/network/socket_client.dart';
import '../../../../core/widgets/presence_avatar.dart';
import '../bloc/chat_bloc.dart';
import '../widgets/message_bubble.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.conversationId,
    required this.title,
    required this.isOnline,
    this.isIdle = false,
    this.peerId,
    this.avatarUrl,
  });

  final String conversationId;
  final String title;
  final bool isOnline;
  final bool isIdle;
  final String? peerId;
  final String? avatarUrl;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final Stream<Map<String, dynamic>> _presenceStream;
  bool _isAuthorizingSend = false;
  bool _forceScrollToLatest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _presenceStream = getIt<SocketClient>().presenceStream.where(
      (event) => event['userId'] == widget.peerId,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _scrollToBottom();
  }

  void _scrollToBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final bottom = _scrollController.position.minScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          bottom,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(bottom);
      }
    });
  }

  bool get _isNearLatest {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels <= 96;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isAuthorizingSend) return;

    final accessService = getIt<MessageAccessService>();
    if (!accessService.isUnlocked) {
      FocusManager.instance.primaryFocus?.unfocus();
      final option = await _showSendAccessSheet();
      if (!mounted || option == null) return;

      setState(() => _isAuthorizingSend = true);
      late final MessageAccessResult result;
      if (option == _SendAccessOption.watchAd) {
        result = await accessService.showRewardedAd();
      } else if (accessService.isUsingFakeBilling) {
        final confirmed = await _showSimulatedPlayPurchase();
        result = confirmed == true
            ? await accessService.subscribeMonthly()
            : MessageAccessResult.cancelled;
      } else {
        result = await accessService.subscribeMonthly();
      }
      if (!mounted) return;
      setState(() => _isAuthorizingSend = false);

      if (result != MessageAccessResult.granted) {
        final message = switch (result) {
          MessageAccessResult.cancelled => 'Dibatalkan. Pesan belum dikirim.',
          MessageAccessResult.unavailable =>
            option == _SendAccessOption.watchAd
                ? 'Iklan belum tersedia. Coba lagi sebentar.'
                : 'Produk belum tersedia di Google Play.',
          _ => 'Belum berhasil. Pesan tidak dihapus, silakan coba lagi.',
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        return;
      }
    }

    context.read<ChatBloc>().add(ChatMessageSent(text));
    _forceScrollToLatest = true;
    getIt<SocketClient>().reportActivity();
    _controller.clear();
  }

  Future<_SendAccessOption?> _showSendAccessSheet() {
    final colors = Theme.of(context).colorScheme;
    return showModalBottomSheet<_SendAccessOption>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pilih cara kirim',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Tonton satu iklan untuk mengirim pesan ini, atau buka akses kirim tanpa iklan.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(sheetContext, _SendAccessOption.watchAd),
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text('Tonton iklan'),
                    Text(
                      'Kirim 1 pesan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(
                sheetContext,
                _SendAccessOption.subscribeMonthly,
              ),
              icon: const Icon(Icons.workspace_premium_outlined),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    const Text('Langganan · Rp500.000/bulan'),
                    const Text(
                      'Ditagih setiap bulan lewat Google Play',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showSimulatedPlayPurchase() {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SimulatedPlayPurchaseSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        titleSpacing: 0,
        title: StreamBuilder<Map<String, dynamic>>(
          stream: _presenceStream,
          builder: (context, snapshot) {
            final presence = snapshot.data;
            final isOnline = presence?['isOnline'] as bool? ?? widget.isOnline;
            final isIdle =
                (presence?['isIdle'] as bool?) ??
                (presence == null
                    ? widget.isIdle
                    : presence['status'] == 'IDLE');
            final statusLabel = isIdle
                ? 'Idle'
                : isOnline
                ? 'Online'
                : 'Offline';
            return Row(
              children: [
                PresenceAvatar(
                  name: widget.title,
                  imageUrl: widget.avatarUrl,
                  isOnline: isOnline,
                  isIdle: isIdle,
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                      ),
                      Text(
                        statusLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isIdle
                              ? const Color(0xFFF59E0B)
                              : isOnline
                              ? const Color(0xFF22C55E)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Video call',
            onPressed: () {},
            icon: const Icon(Icons.videocam_outlined),
          ),
          IconButton(
            tooltip: 'Voice call',
            onPressed: () {},
            icon: const Icon(Icons.call_outlined),
          ),
          PopupMenuButton<String>(
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'contact', child: Text('View contact')),
              PopupMenuItem(value: 'search', child: Text('Search')),
              PopupMenuItem(value: 'clear', child: Text('Clear chat')),
            ],
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          image: DecorationImage(
            image: AssetImage(
              Theme.of(context).brightness == Brightness.dark
                  ? 'assets/images/chat_wallpaper_dark.png'
                  : 'assets/images/chat_wallpaper_light.png',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: BlocConsumer<ChatBloc, ChatState>(
                listener: (context, state) {
                  if (state.status == ChatStatus.failure &&
                      state.message != null) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(state.message!)));
                  }
                  if (state.messages.isEmpty) {
                    return;
                  }
                  if (_forceScrollToLatest || _isNearLatest) {
                    _forceScrollToLatest = false;
                    _scrollToBottom(animate: true);
                  }
                },
                builder: (context, state) {
                  if (state.status == ChatStatus.loading ||
                      state.status == ChatStatus.initial) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.messages.isEmpty) {
                    return const Center(child: Text('Say hello'));
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message =
                          state.messages[state.messages.length - 1 - index];
                      return MessageBubble(message: message);
                    },
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onTap: () => _scrollToBottom(animate: true),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        minLines: 1,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Message',
                          hintStyle: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          filled: true,
                          fillColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          prefixIcon: Icon(
                            Icons.emoji_emotions_outlined,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 84,
                            maxWidth: 84,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.attach_file_rounded,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              SizedBox(width: 14),
                              Icon(
                                Icons.camera_alt_outlined,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              SizedBox(width: 12),
                            ],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    ValueListenableBuilder<bool>(
                      valueListenable:
                          getIt<MessageAccessService>().isUnlockedListenable,
                      builder: (context, isSubscribed, _) {
                        final icon = _isAuthorizingSend
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : isSubscribed
                            ? const Icon(Icons.send_rounded, size: 22)
                            : const _LockedSendIcon();
                        if (isSubscribed) {
                          return IconButton.filled(
                            tooltip: 'Kirim pesan',
                            onPressed: _isAuthorizingSend ? null : _send,
                            icon: icon,
                          );
                        }
                        return IconButton.filled(
                          tooltip: 'Pilih cara kirim',
                          onPressed: _isAuthorizingSend ? null : _send,
                          icon: icon,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SendAccessOption { watchAd, subscribeMonthly }

class _LockedSendIcon extends StatelessWidget {
  const _LockedSendIcon();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.send_rounded, size: 22),
        Positioned(
          right: -5,
          top: -5,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(shape: BoxShape.circle),
            child: Icon(Icons.lock_rounded, size: 9),
          ),
        ),
      ],
    );
  }
}

class _SimulatedPlayPurchaseSheet extends StatefulWidget {
  const _SimulatedPlayPurchaseSheet();

  @override
  State<_SimulatedPlayPurchaseSheet> createState() =>
      _SimulatedPlayPurchaseSheetState();
}

enum _FakePurchaseState { idle, processing, success }

class _SimulatedPlayPurchaseSheetState
    extends State<_SimulatedPlayPurchaseSheet> {
  double _slideValue = 0;
  _FakePurchaseState _purchaseState = _FakePurchaseState.idle;

  static const _background = Color(0xFF121212);
  static const _secondaryText = Color(0xFFB7B7B7);
  static const _divider = Color(0xFF424242);
  static const _playBlue = Color(0xFFA8C7FA);
  static const _playBlueDark = Color(0xFF0B3D91);

  Future<void> _finishFakePurchase() async {
    if (_purchaseState != _FakePurchaseState.idle) return;
    setState(() {
      _slideValue = 1;
      _purchaseState = _FakePurchaseState.processing;
    });
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _purchaseState = _FakePurchaseState.success);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      color: Colors.white70,
      fontSize: 14,
      height: 1.4,
    );

    const underlineStyle = TextStyle(
      color: Colors.white70,
      fontSize: 14,
      height: 1.4,
      decoration: TextDecoration.underline,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      height:
          MediaQuery.sizeOf(context).height *
          (_purchaseState == _FakePurchaseState.idle ? 0.92 : 0.36),
      child: Material(
        color: _background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 360),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _purchaseState == _FakePurchaseState.idle
              ? Column(
                  key: const ValueKey(_FakePurchaseState.idle),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 12, 14),
                      child: Row(
                        children: [
                          const Text(
                            'Google Play',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context, false),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SimulatedProductHeader(),
                            SizedBox(height: 26),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Mulai hari ini',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Rp 500.000/bulan',
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '+ pajak',
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 28),
                            Text(
                              'Tambahan Pajak ⓘ',
                              style: TextStyle(
                                color: _secondaryText,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 26),
                            Text(
                              'Batalkan Langganan kapan saja di Google Play',
                              style: TextStyle(
                                color: _secondaryText,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 24),
                            Divider(color: _divider),
                            _FakeCheckoutRow(
                              assetPath: 'assets/images/google_play_points.png',
                              title: 'Play Points • Bronze',
                              subtitle: '+999 poin',
                            ),
                            Divider(color: _divider),
                            _FakeCheckoutRow(
                              assetPath: 'assets/images/dana.png',
                              title: 'Dana: •••• 5222',
                              trailing: true,
                            ),
                            Divider(color: _divider),
                            SizedBox(height: 18),
                            Text.rich(
                              TextSpan(
                                style: baseStyle,
                                children: [
                                  const TextSpan(
                                    text:
                                        "Dengan berlangganan, Anda setuju bahwa langganan Anda akan diperpanjang secara otomatis hingga dibatalkan. Kami akan memberi tahu Anda jika harga berubah, sebagaimana dijelaskan dalam ",
                                  ),
                                  TextSpan(
                                    text: "Persyaratan Layanan Google Play",
                                    style: underlineStyle,
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {},
                                  ),
                                  const TextSpan(text: ". "),
                                  TextSpan(
                                    text: "Pelajari cara membatalkan",
                                    style: underlineStyle,
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {},
                                  ),
                                  const TextSpan(text: ". "),
                                  TextSpan(
                                    text: "Selengkapnya",
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        // buka detail selengkapnya
                                      },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
                      child: _buildSlideToSubscribe(),
                    ),
                  ],
                )
              : _FakePurchaseStatusPage(state: _purchaseState),
        ),
      ),
    );
  }

  Widget _buildSlideToSubscribe() {
    const thumbRadius = 27.0;
    const iconVisualWidth = 24.0;
    const stackPadding = 6.0; // sesuai EdgeInsets.all(6.0) yang kamu tambahkan

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        // Lebar aktual di dalam Stack setelah dikurangi padding kiri+kanan
        final stackWidth = trackWidth - (stackPadding * 2);
        final maxThumbTravel = stackWidth - (thumbRadius * 2);

        return Container(
          height: 64,
          decoration: BoxDecoration(
            color: _playBlue,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Padding(
            padding: const EdgeInsets.all(stackPadding),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Text(
                  'Geser untuk berlangganan',
                  style: TextStyle(
                    color: Color(0xFF102A56),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 0,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: _playBlueDark,
                    overlayColor: Colors.transparent,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: thumbRadius,
                    ),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: _slideValue,
                    onChanged: (value) => setState(() => _slideValue = value),
                    onChangeEnd: (value) {
                      if (value >= 0.88) {
                        _finishFakePurchase();
                      } else {
                        setState(() => _slideValue = 0);
                      }
                    },
                  ),
                ),
                Positioned(
                  left:
                      thumbRadius +
                      (_slideValue * maxThumbTravel) -
                      (iconVisualWidth / 2),
                  child: const IgnorePointer(
                    child: Icon(
                      Icons.double_arrow_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FakePurchaseStatusPage extends StatelessWidget {
  const _FakePurchaseStatusPage({required this.state});

  final _FakePurchaseState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('purchase-status'),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Google Play',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.82, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: state == _FakePurchaseState.processing
                  ? const _ProcessingPurchaseStatus(
                      key: ValueKey(_FakePurchaseState.processing),
                    )
                  : const _SuccessfulPurchaseStatus(
                      key: ValueKey(_FakePurchaseState.success),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProcessingPurchaseStatus extends StatelessWidget {
  const _ProcessingPurchaseStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: 66,
                child: CircularProgressIndicator(
                  color: Color(0xFFA8C7FA),
                  backgroundColor: Color(0xFF424242),
                  strokeWidth: 3,
                ),
              ),
              Icon(Icons.lock_outline_rounded, color: Colors.white, size: 30),
            ],
          ),
        ),
        SizedBox(height: 18),
        Text(
          'Memproses',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SuccessfulPurchaseStatus extends StatelessWidget {
  const _SuccessfulPurchaseStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFFA8C7FA),
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: 66,
            child: Icon(
              Icons.check_rounded,
              color: Color(0xFF102A56),
              size: 38,
            ),
          ),
        ),
        SizedBox(height: 18),
        Text(
          'Pembayaran berhasil',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SimulatedProductHeader extends StatelessWidget {
  const _SimulatedProductHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFF8B1D4E)),
            child: SizedBox(
              width: 50,
              height: 50,
              child: Image.asset(
                'assets/images/app_icon_question.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WhyApp Premium',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'WhyApp',
              style: TextStyle(
                color: _SimulatedPlayPurchaseSheetState._secondaryText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FakeCheckoutRow extends StatelessWidget {
  const _FakeCheckoutRow({
    required this.assetPath,
    required this.title,
    this.subtitle,
    this.trailing = false,
  });

  final String assetPath;
  final String title;
  final String? subtitle;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Image.asset(
            assetPath,
            width: 32,
            height: 32,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: _SimulatedPlayPurchaseSheetState._secondaryText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing)
            const Icon(Icons.chevron_right_rounded, color: Colors.white70),
        ],
      ),
    );
  }
}

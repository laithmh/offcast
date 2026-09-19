import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/network/discovery_beacon.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/permission_helper.dart';
import '../../../core/widgets/exit_confirmation_dialog.dart';
import '../../../core/widgets/neumorphic_widgets.dart';
import '../bloc/sender_bloc.dart';
import '../bloc/sender_event.dart';
import '../bloc/sender_state.dart';
import '../data/sender_webrtc_service.dart';
import 'widgets/connected_sender_view.dart';
import 'widgets/manual_ip_override_card.dart';
import 'widgets/quality_preset_card.dart';
import 'widgets/target_host_card.dart';

/// Entry screen for the Sender / Transmitter role.
/// Sets up BLoC and WebRTC service providers and coordinates broadcast state.
class SenderScreen extends StatefulWidget {
  const SenderScreen({super.key});

  @override
  State<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends State<SenderScreen> {
  late final SenderWebRTCService _webrtcService;
  late final SenderBloc _senderBloc;

  @override
  void initState() {
    super.initState();
    _webrtcService = SenderWebRTCService();
    _senderBloc = SenderBloc(webrtcService: _webrtcService);
  }

  @override
  void dispose() {
    _senderBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SenderWebRTCService>.value(value: _webrtcService),
      ],
      child: BlocProvider<SenderBloc>.value(
        value: _senderBloc,
        child: const _SenderView(),
      ),
    );
  }
}

class _SenderView extends StatefulWidget {
  const _SenderView();

  @override
  State<_SenderView> createState() => _SenderViewState();
}

class _SenderViewState extends State<_SenderView>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  late final TextEditingController _pinController;
  late final AnimationController _scanPulseController;
  final _formKey = GlobalKey<FormState>();
  bool _showAdvancedSettings = false;
  bool _hasNotificationPermission = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ipController = TextEditingController();
    _portController = TextEditingController(text: '8080');
    _pinController = TextEditingController();
    _scanPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _checkPermissionState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionState();
    }
  }

  Future<void> _checkPermissionState() async {
    final status = await Permission.notification.status;
    if (mounted) setState(() => _hasNotificationPermission = status.isGranted);
  }

  @override
  void dispose() {
    _scanPulseController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _ipController.dispose();
    _portController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _startSharing() async {
    final bloc = context.read<SenderBloc>();
    if (bloc.state.isBusy) return;

    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

    // Validate local network connectivity
    final clientIp = bloc.state.clientIp ?? await NetworkHelper.getMyDeviceIp();
    if (clientIp == null || clientIp.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No Wi-Fi or Hotspot connection detected. Please connect this device to the Receiver’s Wi-Fi Hotspot.',
            ),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final rawHost = _ipController.text.trim();
    final effectiveHost = rawHost.isNotEmpty
        ? rawHost
        : (bloc.state.targetHost.isNotEmpty
              ? bloc.state.targetHost
              : '192.168.43.1');

    final rawPort = _portController.text.trim();
    final effectivePort = int.tryParse(rawPort) ?? bloc.state.targetPort;

    // Validate IPv4 format
    final ipv4Regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipv4Regex.hasMatch(effectiveHost)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid IP address format: $effectiveHost'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted && mounted) {
      final granted = await PermissionHelper.requestPermissions(context);
      if (!granted) return;
    }

    if (!mounted) return;
    final rawPin = _pinController.text.trim();
    final effectivePin = rawPin.isNotEmpty ? rawPin : bloc.state.pairingPin;

    bloc.add(
      SenderStartSharingRequested(
        targetHost: effectiveHost,
        targetPort: effectivePort,
        preset: bloc.state.preset,
        codecEngine: bloc.state.codecEngine,
        streamSource: bloc.state.streamSource,
        pairingPin: effectivePin.isNotEmpty ? effectivePin : null,
      ),
    );
  }

  void _stopSharing() {
    context.read<SenderBloc>().add(const SenderStopSharingRequested());
  }

  Future<bool?> _showExitConfirmation(BuildContext context) {
    return ExitConfirmationDialog.show(
      context,
      title: 'Stop Broadcast?',
      message: 'An active transmission is in progress. Leaving will disconnect the receiver display.',
      cancelLabel: 'Keep Streaming',
      confirmLabel: 'Stop & Exit',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SenderBloc, SenderState>(
      listenWhen: (prev, curr) {
        return prev.status != curr.status ||
            prev.isAutoDiscovered != curr.isAutoDiscovered ||
            prev.discoveredDevice != curr.discoveredDevice ||
            prev.pairingPin != curr.pairingPin ||
            prev.errorMessage != curr.errorMessage;
      },
      listener: (context, state) {
        if (state.isAutoDiscovered || state.discoveredDevice != null) {
          _ipController.text = state.targetHost;
          _portController.text = state.targetPort.toString();
          if (state.discoveredDevice?.pin != null &&
              state.discoveredDevice!.pin!.isNotEmpty) {
            _pinController.text = state.discoveredDevice!.pin!;
          } else if (state.pairingPin.isNotEmpty &&
              _pinController.text.isEmpty) {
            _pinController.text = state.pairingPin;
          }
        }

        if (state.status == SenderConnectionState.streaming) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Viewfinder active! Open your Camera app to shoot.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }

        if (state.status == SenderConnectionState.failed &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      },
      builder: (context, state) {
        Widget content;
        if (state.isStreaming) {
          content = ConnectedSenderView(
            state: state,
            onDisconnect: _stopSharing,
          );
        } else {
          content = _buildConfigScaffold(state);
        }

        return PopScope(
          canPop: !state.isStreaming,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldPop = await _showExitConfirmation(context);
            if (shouldPop == true && context.mounted) {
              _stopSharing();
              Navigator.of(context).pop();
            }
          },
          child: content,
        );
      },
    );
  }

  Widget _buildConfigScaffold(SenderState state) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Sender Mode'),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Center(
            child: NeumorphicIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              size: 40,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          final horizontalPadding = constraints.maxWidth < 380 ? 14.0 : 20.0;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16.0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderSection(),
                      if (!_hasNotificationPermission) ...[
                        const SizedBox(height: 16),
                        _buildPermissionNotice(),
                      ],
                      const SizedBox(height: 20),
                      TargetHostCard(
                        state: state,
                        scanPulseController: _scanPulseController,
                        pinController: _pinController,
                      ),
                      const SizedBox(height: 20),
                      QualityPresetCard(state: state, isWide: isWide),
                      if (state.isBusy) ...[
                        const SizedBox(height: 16),
                        _buildConnectingStatusCard(state),
                      ],
                      const SizedBox(height: 24),
                      _buildActionButtons(state),
                      const SizedBox(height: 16),
                      ManualIpOverrideCard(
                        ipController: _ipController,
                        portController: _portController,
                        isExpanded: _showAdvancedSettings,
                        onToggleExpanded: () => setState(
                          () => _showAdvancedSettings = !_showAdvancedSettings,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectingStatusCard(SenderState state) {
    String stepTitle;
    String stepSubtitle;
    IconData icon;

    switch (state.status) {
      case SenderConnectionState.capturingScreen:
        stepTitle = 'Authorizing Screen Capture';
        stepSubtitle = 'Please accept the Android screen capture prompt...';
        icon = Icons.screen_share_rounded;
        break;
      case SenderConnectionState.connectingSignaling:
        stepTitle = 'Connecting to Receiver';
        stepSubtitle =
            'Binding Wi-Fi socket to ${state.targetHost.isNotEmpty ? state.targetHost : "Receiver"}...';
        icon = Icons.wifi_tethering_rounded;
        break;
      case SenderConnectionState.connectedSignaling:
      case SenderConnectionState.negotiatingWebRTC:
        stepTitle = 'Establishing WebRTC Stream';
        stepSubtitle = 'Negotiating zero-latency P2P video pipeline...';
        icon = Icons.sync_rounded;
        break;
      default:
        stepTitle = 'Connecting';
        stepSubtitle = 'Setting up wireless broadcast...';
        icon = Icons.sensors_rounded;
    }

    return NeumorphicCard(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: AppTheme.surfaceElevated,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                  ),
                ),
                Icon(icon, size: 14, color: AppTheme.accent),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stepTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stepSubtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wireless Viewfinder Broadcast',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Mirror your screen to the Director Monitor over direct Wi-Fi Hotspot with ultra-low latency.',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionNotice() {
    return NeumorphicCard(
      borderRadius: 16,
      color: AppTheme.warningLight,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_rounded,
            color: AppTheme.warning,
            size: 24,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foreground Notification Permission',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Required on Android 13+ to maintain live capture in the background.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await PermissionHelper.requestPermissions(context);
              _checkPermissionState();
            },
            child: const Text(
              'Grant',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(SenderState state) {
    final hasWifi = state.clientIp != null;
    final isBusy = state.isBusy;

    String buttonText;
    if (isBusy) {
      switch (state.status) {
        case SenderConnectionState.capturingScreen:
          buttonText = 'Starting Capture...';
          break;
        case SenderConnectionState.connectingSignaling:
          buttonText = 'Connecting to Monitor...';
          break;
        case SenderConnectionState.connectedSignaling:
          buttonText = 'Preparing Stream...';
          break;
        case SenderConnectionState.negotiatingWebRTC:
          buttonText = 'Negotiating WebRTC...';
          break;
        default:
          buttonText = 'Connecting...';
      }
    } else if (!hasWifi) {
      buttonText = 'Connect to Hotspot to Stream';
    } else {
      buttonText = 'Start Viewfinder Broadcast';
    }

    return NeumorphicButton(
      onPressed: isBusy
          ? null
          : (hasWifi
                ? _startSharing
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please connect to the Receiver’s Wi-Fi Hotspot first.',
                        ),
                        backgroundColor: AppTheme.warning,
                      ),
                    );
                  }),
      isPrimary: true,
      backgroundColor: isBusy
          ? AppTheme.primary.withValues(alpha: 0.75)
          : (hasWifi ? AppTheme.primary : AppTheme.surfaceElevated),
      textColor: (hasWifi || isBusy) ? Colors.white : AppTheme.textMuted,
      borderRadius: 18,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isBusy) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
          ] else ...[
            Icon(
              !hasWifi ? Icons.wifi_off_rounded : Icons.play_arrow_rounded,
              size: 20,
              color: hasWifi ? Colors.white : AppTheme.textMuted,
            ),
            const SizedBox(width: 8),
          ],
          Text(buttonText),
        ],
      ),
    );
  }
}

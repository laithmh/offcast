import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/webrtc_constants.dart';
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
import 'widgets/stream_source_card.dart';
import 'widgets/talent_prompter_view.dart';
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
    super.dispose();
  }

  Future<void> _startSharing() async {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

    final bloc = context.read<SenderBloc>();
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

    if (bloc.state.streamSource == StreamSourceType.studioCamera) {
      final camGranted = await PermissionHelper.requestCameraAndMicPermissions(
        context,
      );
      if (!camGranted) return;
    } else {
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted && mounted) {
        final granted = await PermissionHelper.requestPermissions(context);
        if (!granted) return;
      }
    }

    if (!mounted) return;
    bloc.add(
      SenderStartSharingRequested(
        targetHost: effectiveHost,
        targetPort: effectivePort,
        preset: bloc.state.preset,
        codecEngine: bloc.state.codecEngine,
        streamSource: bloc.state.streamSource,
        cameraFacing: bloc.state.cameraFacing,
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
      listener: (context, state) {
        if (state.isAutoDiscovered || state.discoveredDevice != null) {
          _ipController.text = state.targetHost;
          _portController.text = state.targetPort.toString();
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
        if (state.isStreaming &&
            state.streamSource == StreamSourceType.studioCamera &&
            state.isPrompterOverlay) {
          content = TalentPrompterView(
            config: state.prompterConfig,
            onToggleHud: () => context.read<SenderBloc>().add(
              const SenderPrompterOverlayToggled(),
            ),
          );
        } else if (state.isStreaming) {
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
                      StreamSourceCard(state: state),
                      const SizedBox(height: 20),
                      TargetHostCard(
                        state: state,
                        scanPulseController: _scanPulseController,
                      ),
                      const SizedBox(height: 20),
                      QualityPresetCard(state: state, isWide: isWide),
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

  Widget _buildHeaderSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Camera & Screen Broadcast',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Transmit zero-latency video to the Director Monitor over direct Wi-Fi Hotspot.',
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
    final isCamera = state.streamSource == StreamSourceType.studioCamera;

    return NeumorphicButton(
      onPressed: hasWifi
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
            },
      isPrimary: true,
      backgroundColor: hasWifi ? AppTheme.primary : AppTheme.surfaceElevated,
      textColor: hasWifi ? Colors.white : AppTheme.textMuted,
      borderRadius: 18,
      icon: !hasWifi
          ? Icons.wifi_off_rounded
          : (isCamera ? Icons.videocam_rounded : Icons.play_arrow_rounded),
      child: Text(
        !hasWifi
            ? 'Connect to Hotspot to Stream'
            : (isCamera
                  ? 'Start Studio Camera & Prompter'
                  : 'Start Screen Mirroring'),
      ),
    );
  }
}

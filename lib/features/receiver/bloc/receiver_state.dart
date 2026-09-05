import 'package:equatable/equatable.dart';

import '../../../core/constants/webrtc_constants.dart';
import '../../../core/models/prompter_model.dart';

enum ReceiverStatus {
  initial,
  starting,
  listening,
  clientConnected,
  streaming,
  error,
  stopped,
}

enum SocialFramingMode {
  none(label: 'Clean Feed', description: 'No framing overlay'),
  reels9x16(
    label: '9:16 Shorts / Reels',
    description: 'Vertical social safe zone',
  ),
  youtube16x9(label: '16:9 YouTube', description: 'Widescreen landscape guide'),
  square1x1(label: '1:1 Square', description: 'Instagram post safe zone'),
  ruleOfThirds(label: 'Rule of Thirds', description: 'Golden composition grid');

  final String label;
  final String description;
  const SocialFramingMode({required this.label, required this.description});
}

class ReceiverState extends Equatable {
  final ReceiverStatus status;
  final int port;
  final String? localIp;
  final List<String> availableIps;
  final bool isClientConnected;
  final bool isStreaming;
  final SocialFramingMode framingMode;
  final StreamSourceType streamSource;
  final PrompterConfig prompterConfig;
  final bool isDirectorPrompterOpen;
  final bool isPrompterOverlayVisible;
  final String pairingPin;
  final bool isPinRequired;
  final String? errorMessage;

  const ReceiverState({
    this.status = ReceiverStatus.initial,
    this.port = 8080,
    this.localIp,
    this.availableIps = const [],
    this.isClientConnected = false,
    this.isStreaming = false,
    this.framingMode = SocialFramingMode.none,
    this.streamSource = StreamSourceType.screen,
    this.prompterConfig = const PrompterConfig(),
    this.isDirectorPrompterOpen = false,
    this.isPrompterOverlayVisible = false,
    this.pairingPin = '',
    this.isPinRequired = true,
    this.errorMessage,
  });

  ReceiverState copyWith({
    ReceiverStatus? status,
    int? port,
    String? localIp,
    List<String>? availableIps,
    bool? isClientConnected,
    bool? isStreaming,
    SocialFramingMode? framingMode,
    StreamSourceType? streamSource,
    PrompterConfig? prompterConfig,
    bool? isDirectorPrompterOpen,
    bool? isPrompterOverlayVisible,
    String? pairingPin,
    bool? isPinRequired,
    String? errorMessage,
  }) {
    return ReceiverState(
      status: status ?? this.status,
      port: port ?? this.port,
      localIp: localIp ?? this.localIp,
      availableIps: availableIps ?? this.availableIps,
      isClientConnected: isClientConnected ?? this.isClientConnected,
      isStreaming: isStreaming ?? this.isStreaming,
      framingMode: framingMode ?? this.framingMode,
      streamSource: streamSource ?? this.streamSource,
      prompterConfig: prompterConfig ?? this.prompterConfig,
      isDirectorPrompterOpen:
          isDirectorPrompterOpen ?? this.isDirectorPrompterOpen,
      isPrompterOverlayVisible:
          isPrompterOverlayVisible ?? this.isPrompterOverlayVisible,
      pairingPin: pairingPin ?? this.pairingPin,
      isPinRequired: isPinRequired ?? this.isPinRequired,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    port,
    localIp,
    availableIps,
    isClientConnected,
    isStreaming,
    framingMode,
    streamSource,
    prompterConfig,
    isDirectorPrompterOpen,
    isPrompterOverlayVisible,
    pairingPin,
    isPinRequired,
    errorMessage,
  ];
}

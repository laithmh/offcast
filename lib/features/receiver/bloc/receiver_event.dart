import 'package:equatable/equatable.dart';

import '../../../core/constants/webrtc_constants.dart';
import '../../../core/models/prompter_model.dart';
import 'receiver_state.dart';

abstract class ReceiverEvent extends Equatable {
  const ReceiverEvent();

  @override
  List<Object?> get props => [];
}

class ReceiverStartServerRequested extends ReceiverEvent {
  final int port;

  const ReceiverStartServerRequested({this.port = 8080});

  @override
  List<Object?> get props => [port];
}

class ReceiverStopServerRequested extends ReceiverEvent {
  const ReceiverStopServerRequested();
}

class ReceiverClientStatusChanged extends ReceiverEvent {
  final bool isClientConnected;

  const ReceiverClientStatusChanged({required this.isClientConnected});

  @override
  List<Object?> get props => [isClientConnected];
}

class ReceiverStreamingStatusChanged extends ReceiverEvent {
  final bool isStreaming;

  const ReceiverStreamingStatusChanged({required this.isStreaming});

  @override
  List<Object?> get props => [isStreaming];
}

class ReceiverIpSelected extends ReceiverEvent {
  final String selectedIp;

  const ReceiverIpSelected(this.selectedIp);

  @override
  List<Object?> get props => [selectedIp];
}

class ReceiverNetworkPolled extends ReceiverEvent {
  final String? detectedIp;
  final List<String> availableIps;

  const ReceiverNetworkPolled({
    required this.detectedIp,
    required this.availableIps,
  });

  @override
  List<Object?> get props => [detectedIp, availableIps];
}

class ReceiverFramingModeCycled extends ReceiverEvent {
  const ReceiverFramingModeCycled();
}

class ReceiverFramingModeSelected extends ReceiverEvent {
  final SocialFramingMode mode;

  const ReceiverFramingModeSelected(this.mode);

  @override
  List<Object?> get props => [mode];
}

class ReceiverDirectorPrompterToggled extends ReceiverEvent {
  const ReceiverDirectorPrompterToggled();
}

class ReceiverPrompterStateSynced extends ReceiverEvent {
  final PrompterConfig config;

  const ReceiverPrompterStateSynced(this.config);

  @override
  List<Object?> get props => [config];
}

class ReceiverPrompterCommandDispatched extends ReceiverEvent {
  final String action;
  final Map<String, dynamic>? params;

  const ReceiverPrompterCommandDispatched(this.action, [this.params]);

  @override
  List<Object?> get props => [action, params];
}

class ReceiverPrompterScriptDispatched extends ReceiverEvent {
  final String scriptText;

  const ReceiverPrompterScriptDispatched(this.scriptText);

  @override
  List<Object?> get props => [scriptText];
}

class ReceiverPrompterOverlayToggled extends ReceiverEvent {
  const ReceiverPrompterOverlayToggled();
}

class ReceiverPrompterProgressUpdated extends ReceiverEvent {
  final double progress;

  const ReceiverPrompterProgressUpdated(this.progress);

  @override
  List<Object?> get props => [progress];
}

class ReceiverStreamSourceChanged extends ReceiverEvent {
  final StreamSourceType streamSource;

  const ReceiverStreamSourceChanged(this.streamSource);

  @override
  List<Object?> get props => [streamSource];
}

class ReceiverRegeneratePinRequested extends ReceiverEvent {
  const ReceiverRegeneratePinRequested();
}

class ReceiverPinSecurityToggled extends ReceiverEvent {
  final bool isRequired;

  const ReceiverPinSecurityToggled(this.isRequired);

  @override
  List<Object?> get props => [isRequired];
}


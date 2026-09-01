import 'package:equatable/equatable.dart';

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

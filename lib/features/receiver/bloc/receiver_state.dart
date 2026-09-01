import 'package:equatable/equatable.dart';

enum ReceiverStatus {
  initial,
  starting,
  listening,
  clientConnected,
  streaming,
  error,
  stopped,
}

class ReceiverState extends Equatable {
  final ReceiverStatus status;
  final int port;
  final String? localIp;
  final List<String> availableIps;
  final bool isClientConnected;
  final bool isStreaming;
  final String? errorMessage;

  const ReceiverState({
    this.status = ReceiverStatus.initial,
    this.port = 8080,
    this.localIp,
    this.availableIps = const [],
    this.isClientConnected = false,
    this.isStreaming = false,
    this.errorMessage,
  });

  ReceiverState copyWith({
    ReceiverStatus? status,
    int? port,
    String? localIp,
    List<String>? availableIps,
    bool? isClientConnected,
    bool? isStreaming,
    String? errorMessage,
  }) {
    return ReceiverState(
      status: status ?? this.status,
      port: port ?? this.port,
      localIp: localIp ?? this.localIp,
      availableIps: availableIps ?? this.availableIps,
      isClientConnected: isClientConnected ?? this.isClientConnected,
      isStreaming: isStreaming ?? this.isStreaming,
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
    errorMessage,
  ];
}

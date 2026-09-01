import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/receiver/presentation/receiver_screen.dart';
import '../../features/sender/presentation/sender_screen.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'home',
        builder: (BuildContext context, GoRouterState state) {
          return const HomeScreen();
        },
      ),
      GoRoute(
        path: '/sender',
        name: 'sender',
        builder: (BuildContext context, GoRouterState state) {
          return const SenderScreen();
        },
      ),
      GoRoute(
        path: '/receiver',
        name: 'receiver',
        builder: (BuildContext context, GoRouterState state) {
          return const ReceiverScreen();
        },
      ),
    ],
  );
}

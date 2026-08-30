import 'dart:async';

import 'package:flutter/material.dart';

import 'data/location_service.dart';
import 'data/repositories.dart';
import 'theme/ember_theme.dart';
import 'ui/game_controller.dart';
import 'ui/ignition_screen.dart';
import 'ui/map_screen.dart';
import 'ui/tray_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(EmberApp(
    game: GameController(
      locationService: GeolocatorLocationService(),
      destinationRepo: AssetDestinationRepository(),
      progressRepo: LocalProgressRepository(),
    ),
  ));
}

class EmberApp extends StatefulWidget {
  const EmberApp({super.key, required this.game});
  final GameController game;

  @override
  State<EmberApp> createState() => _EmberAppState();
}

class _EmberAppState extends State<EmberApp> {
  final _navKey = GlobalKey<NavigatorState>();
  StreamSubscription? _unlockSub;

  @override
  void initState() {
    super.initState();
    _unlockSub = widget.game.unlocks.listen((e) {
      _navKey.currentState?.push(
        MaterialPageRoute(builder: (_) => IgnitionScreen(event: e), fullscreenDialog: true),
      );
    });
    widget.game.start();
  }

  @override
  void dispose() {
    _unlockSub?.cancel();
    widget.game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Ember',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navKey,
        theme: emberTheme(),
        home: HomeShell(game: widget.game),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.game});
  final GameController game;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.game,
      builder: (context, _) {
        if (widget.game.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Ember.red)),
          );
        }
        return Scaffold(
          // IndexedStack keeps the GoogleMap alive across tab switches; a
          // rebuilt map costs a full platform-view re-creation.
          body: IndexedStack(
            index: _tab,
            children: [
              MapScreen(game: widget.game),
              TrayScreen(game: widget.game),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.map_outlined), label: 'MAP'),
              NavigationDestination(icon: Icon(Icons.grid_view_outlined), label: 'TRAY'),
            ],
          ),
        );
      },
    );
  }
}

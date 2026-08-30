import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../theme/ember_theme.dart';

/// The reward is a moment, not a dialog to dismiss. It clears itself so a run
/// of quick unlocks cannot bury the map under a stack of these.
const Duration kIgnitionDwell = Duration(milliseconds: 3600);

class IgnitionScreen extends StatefulWidget {
  const IgnitionScreen({super.key, required this.event});
  final UnlockEvent event;

  @override
  State<IgnitionScreen> createState() => _IgnitionScreenState();
}

class _IgnitionScreenState extends State<IgnitionScreen> {
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    _auto = Timer(kIgnitionDwell, _close);
  }

  void _close() {
    _auto?.cancel();
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.event.destination;
    final event = widget.event;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.25),
            radius: 1.05,
            colors: [Color(0xFFFFA5A5), Ember.coral, Ember.red, Ember.deepRed],
            stops: [0.0, 0.34, 0.72, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Image.asset(
                d.artLit,
                width: 168,
                height: 168,
                fit: BoxFit.contain,
                color: Colors.white,
                colorBlendMode: BlendMode.srcIn,
              ),
              const SizedBox(height: 18),
              const Text(
                'IGNITED',
                style: TextStyle(color: Colors.white70, letterSpacing: 5, fontSize: 11),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Text(
                  d.name.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Place ${event.ordinal} of ${event.total}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    Text(
                      d.tokenName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '#${event.ordinal.toString().padLeft(3, '0')} · ${d.rarity.name.toUpperCase()}',
                      style: const TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1.6),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Ember.red,
                    ),
                    onPressed: _close,
                    child: const Text('ADD TO TRAY'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

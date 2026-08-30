import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../theme/ember_theme.dart';
import 'game_controller.dart';

class TrayScreen extends StatelessWidget {
  const TrayScreen({super.key, required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('YOUR TRAY', style: t.textTheme.labelSmall),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${game.foundCount}',
                  style: const TextStyle(
                    color: Ember.red,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 7),
                Text('/ ${game.totalCount} IGNITED',
                    style: t.textTheme.labelSmall?.copyWith(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemCount: game.destinations.length,
                itemBuilder: (context, i) {
                  final d = game.destinations[i];
                  return _Tile(d: d, lit: game.unlockedIds.contains(d.id));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.d, required this.lit});
  final Destination d;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: lit ? Ember.red.withValues(alpha: 0.12) : Ember.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: lit ? Ember.red : Ember.line, width: lit ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: lit ? Ember.red : Ember.sage,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: lit ? Ember.coral : Ember.muted, width: 1.6),
            ),
          ),
          const Spacer(),
          Text(
            lit ? d.name : '???',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: lit ? Ember.ink : Ember.muted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            lit ? d.tokenName : d.rarity.name.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: lit ? Ember.deepRed : Ember.muted),
          ),
        ],
      ),
    );
  }
}

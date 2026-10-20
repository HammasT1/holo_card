import 'package:flutter/material.dart';

/// Width / height of every sample card.
const double kCardAspect = 5 / 7;

/// Corner radius shared by every sample card and its [HoloCard].
const BorderRadius kCardRadius = BorderRadius.all(Radius.circular(22));

class _CardShell extends StatelessWidget {
  const _CardShell({required this.gradient, required this.child});

  final Gradient gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: kCardAspect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: kCardRadius,
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
    );
  }
}

/// A developer profile card built only from widgets and icons.
class DeveloperCard extends StatelessWidget {
  /// Creates the card.
  const DeveloperCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1B2140), Color(0xFF0E1226)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('DEV', style: _tag),
              const Spacer(),
              Icon(Icons.bolt_rounded, color: Colors.amber.shade300),
              const SizedBox(width: 4),
              const Text('LV 42', style: _tag),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C5CFF), Color(0xFF22D3EE)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C5CFF).withAlpha(120),
                      blurRadius: 30,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(5),
                child: const CircleAvatar(
                  radius: 52,
                  backgroundColor: Color(0xFF12172E),
                  child: Icon(
                    Icons.code_rounded,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const Text(
            'Alex Rivera',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Senior Flutter Engineer',
            style: TextStyle(color: Colors.white.withAlpha(170)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: const [
              _Chip('Dart'),
              _Chip('Shaders'),
              _Chip('Animation'),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Stat('128', 'Repos'),
              _Stat('4.2k', 'Stars'),
              _Stat('312', 'Merges'),
            ],
          ),
        ],
      ),
    );
  }
}

/// A membership card built only from widgets and icons.
class MembershipCard extends StatelessWidget {
  /// Creates the card.
  const MembershipCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      gradient: const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF2A1458), Color(0xFF0D0820)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.public_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('ORBIT CLUB', style: _tag),
            ],
          ),
          const Spacer(),
          const Icon(Icons.memory_rounded, size: 46, color: Color(0xFFFFE08A)),
          const SizedBox(height: 18),
          const Text(
            '•••• •••• •••• 2048',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              letterSpacing: 2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Stat('Sam Okafor', 'MEMBER'),
              _Stat('09 / 29', 'VALID THRU'),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'GALAXY TIER',
            style: _tag.copyWith(color: const Color(0xFFFF4FD8)),
          ),
        ],
      ),
    );
  }
}

/// An achievement card built only from widgets and icons.
class AchievementCard extends StatelessWidget {
  /// Creates the card.
  const AchievementCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4A3410), Color(0xFF1C1206)],
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('ACHIEVEMENT', style: _tag),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFFFE08A), Color(0xFFB9791A)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE6A82B).withAlpha(110),
                  blurRadius: 36,
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              size: 72,
              color: Color(0xFF3A2606),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Summit Climber',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Reached 5,000 m in one week',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withAlpha(160)),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(
              value: 0.72,
              minHeight: 10,
              color: Color(0xFFE6A82B),
              backgroundColor: Color(0x33FFFFFF),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '7,200 / 10,000 XP',
            style: TextStyle(color: Colors.white.withAlpha(170)),
          ),
        ],
      ),
    );
  }
}

/// A product showcase card, with a button to prove child taps still work.
class ProductCard extends StatefulWidget {
  /// Creates the card.
  const ProductCard({super.key});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  int _added = 0;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2B3340), Color(0xFF10141B)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NEW', style: _tag),
          Expanded(
            child: Center(
              child: Icon(
                Icons.headphones_rounded,
                size: 130,
                color: Colors.blueGrey.shade100,
              ),
            ),
          ),
          const Text(
            'Aero One',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            'Wireless over-ear headphones',
            style: TextStyle(color: Colors.white.withAlpha(160)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                r'$249',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => setState(() => _added++),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                label: Text(_added == 0 ? 'Add' : 'Added $_added'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// An event pass card.
class PassCard extends StatelessWidget {
  /// Creates the card.
  const PassCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      gradient: const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0xFF062A33), Color(0xFF111033)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NIGHT SKY FESTIVAL', style: _tag),
          const Spacer(),
          const Icon(
            Icons.nightlight_round,
            size: 84,
            color: Color(0xFF9FF3DC),
          ),
          const SizedBox(height: 16),
          const Text(
            'All-Access Pass',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Three nights under the northern lights',
            style: TextStyle(color: Colors.white.withAlpha(160)),
          ),
          const Spacer(),
          const Row(
            children: [
              Icon(Icons.qr_code_2_rounded, size: 54, color: Colors.white),
              Spacer(),
              _Stat('A-117', 'SEAT'),
            ],
          ),
        ],
      ),
    );
  }
}

const TextStyle _tag = TextStyle(
  color: Colors.white,
  fontSize: 12,
  fontWeight: FontWeight.w800,
  letterSpacing: 2,
);

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(24),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha(140),
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

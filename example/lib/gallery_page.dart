import 'package:flutter/material.dart';
import 'package:holo_card/holo_card.dart';

import 'controls_panel.dart';
import 'sample_cards.dart';

/// The demo screen: a pager of cards and a live controls panel.
class GalleryPage extends StatefulWidget {
  /// Creates the page.
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  static const _cards = <Widget>[
    DeveloperCard(),
    MembershipCard(),
    AchievementCard(),
    ProductCard(),
    PassCard(),
  ];

  final _pageController = PageController(viewportFraction: 0.72);
  final _holoController = HoloCardController();
  final _effects = List<HoloEffect>.of(HoloEffect.presets);
  DemoSettings _settings = const DemoSettings();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _holoController.dispose();
    super.dispose();
  }

  Widget _stage() {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _cards.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 28),
              child: Center(
                child: HoloCard(
                  effect: _effects[i],
                  maxTiltAngle: _settings.maxTiltAngle,
                  glareIntensity: _settings.glare,
                  foilIntensity: _settings.foil,
                  enableGyroscope: _settings.gyroscope,
                  idleAnimation: _settings.idle,
                  borderRadius: kCardRadius,
                  controller: i == _page ? _holoController : null,
                  child: _cards[i],
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _cards.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                width: i == _page ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page ? Colors.white : Colors.white38,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _controls() => ControlsPanel(
        settings: _settings,
        onSettings: (s) => setState(() => _settings = s),
        effect: _effects[_page],
        onEffect: (e) => setState(() => _effects[_page] = e),
        controller: _holoController,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.2,
            colors: [Color(0xFF1A1F3A), Color(0xFF0A0C14)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 860) {
                return Row(
                  children: [
                    Expanded(child: _stage()),
                    SizedBox(width: 340, child: _controls()),
                  ],
                );
              }
              return Column(
                children: [
                  Expanded(flex: 5, child: _stage()),
                  Expanded(flex: 4, child: _controls()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

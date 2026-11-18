import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../ui/raad_theme.dart';

/// A swipeable virtual card widget with 3 color variants:
/// Silver, Gold, and White — matching RAAD brand identity.
///
/// It is part of the design only (the person's decision of 17 November):
/// there is no card, nothing here collects card or bank details, and screen
/// readers hear that it is not available yet.
class VirtualCardCarousel extends StatefulWidget {
  const VirtualCardCarousel({super.key});

  @override
  State<VirtualCardCarousel> createState() => _VirtualCardCarouselState();
}

class _VirtualCardCarouselState extends State<VirtualCardCarousel> {
  int _currentIndex = 0;

  static const _cards = [
    _CardVariant.silver,
    _CardVariant.gold,
    _CardVariant.white,
  ];

  void _next() {
    setState(() => _currentIndex = (_currentIndex + 1) % _cards.length);
  }

  void _prev() {
    setState(
      () => _currentIndex = (_currentIndex - 1 + _cards.length) % _cards.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.cardsTitle,
                  style: const TextStyle(
                    color: RaadColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              // Part of the design only: it says it is not available yet.
              Semantics(
                button: true,
                label: '${l10n.cardsAddToAppleWallet}. ${l10n.notAvailableYet}',
                excludeSemantics: true,
                child: InkWell(
                  key: const ValueKey('cards.appleWallet'),
                  onTap: _showNotAvailable,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: RaadColors.cyanAccent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: RaadColors.cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.apple,
                          color: RaadColors.background,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            l10n.cardsAddToAppleWallet,
                            style: const TextStyle(
                              color: RaadColors.background,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // The decorative card and its dots read as one item.
        Semantics(
          label: '${l10n.cardsPreview}. ${l10n.notAvailableYet}',
          excludeSemantics: true,
          child: _carousel(),
        ),
      ],
    );
  }

  Widget _carousel() {
    return Column(
      children: [
        // Card with swipe gesture detection
        GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            if (details.primaryVelocity! < -200) {
              _next();
            } else if (details.primaryVelocity! > 200) {
              _prev();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AspectRatio(
              aspectRatio: 1.586,
              child: _VirtualCard(variant: _cards[_currentIndex]),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_cards.length, (i) {
            final isActive = i == _currentIndex;
            final dotColor = _dotColor(_cards[i]);
            return GestureDetector(
              onTap: () => setState(() => _currentIndex = i),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? dotColor : dotColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Color _dotColor(_CardVariant variant) {
    switch (variant) {
      case _CardVariant.silver:
        return const Color(0xFFC0C0C0);
      case _CardVariant.gold:
        return const Color(0xFFC9A227);
      case _CardVariant.white:
        return Colors.white;
    }
  }

  void _showNotAvailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // No card exists and no card or bank detail is ever collected.
        content: Text(AppLocalizations.of(context).cardsAppleWalletSoon),
        backgroundColor: RaadColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

enum _CardVariant { silver, gold, white }

class _VirtualCard extends StatelessWidget {
  const _VirtualCard({required this.variant});
  final _CardVariant variant;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: _gradient,
        boxShadow: _shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Metallic sheen overlay — simple gradient, no ShaderMask
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.30),
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.12),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            // Subtle depth layer
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
            ),

            // Card content: fixed-size artwork, hidden from screen readers,
            // so its text keeps its size inside the card's fixed shape.
            MediaQuery.withNoTextScaling(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: RAAD brand + chip icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // RAAD branding
                        Row(
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              color: _textColor,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'RAAD',
                              style: TextStyle(
                                color: _textColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                        // EMV chip icon (decorative)
                        Container(
                          width: 32,
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _chipColors,
                            ),
                            border: Border.all(
                              color: _textColor.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.memory_rounded,
                              color: _textColor.withValues(alpha: 0.6),
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Masked card number
                    Text(
                      '•••• •••• •••• 1635',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Bottom row: label + network
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context).cardsVirtualCard
                                  .toUpperCase(),
                              style: TextStyle(
                                color: _textColor.withValues(alpha: 0.6),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _variantLabel(AppLocalizations.of(context)),
                              style: TextStyle(
                                color: _textColor.withValues(alpha: 0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        // Network wordmark
                        Text(
                          'VISA',
                          style: TextStyle(
                            color: _textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient get _gradient {
    switch (variant) {
      case _CardVariant.silver:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFBDBDBD),
            Color(0xFFEEEEEE),
            Color(0xFFB0B0B0),
            Color(0xFFD6D6D6),
          ],
          stops: [0.0, 0.4, 0.75, 1.0],
        );
      case _CardVariant.gold:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFB8860B), // dark gold
            Color(0xFFDAA520), // goldenrod
            Color(0xFFFFD700), // pure gold
            Color(0xFFFFC107), // amber
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        );
      case _CardVariant.white:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF00E5FF), // RAAD cyan accent
            Color(0xFF0062FF), // vivid blue
            Color(0xFF0033CC), // deep blue
            Color(0xFF001F54), // midnight blue
          ],
          stops: [0.0, 0.35, 0.75, 1.0],
        );
    }
  }

  List<BoxShadow> get _shadows {
    switch (variant) {
      case _CardVariant.silver:
        return [
          const BoxShadow(
            color: Color(0x60C0C0C0),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ];
      case _CardVariant.gold:
        return [
          const BoxShadow(
            color: Color(0x80C9A227),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ];
      case _CardVariant.white:
        return [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ];
    }
  }

  List<Color> get _chipColors {
    switch (variant) {
      case _CardVariant.silver:
        return [const Color(0xFFE0E0E0), const Color(0xFFA0A0A0)];
      case _CardVariant.gold:
        return [const Color(0xFFF0C040), const Color(0xFFA67C00)];
      case _CardVariant.white:
        return [const Color(0xFFECEFF1), const Color(0xFFB0BEC5)];
    }
  }

  Color get _textColor {
    switch (variant) {
      case _CardVariant.silver:
        return const Color(0xFF1A1A1A);
      case _CardVariant.gold:
        return const Color(0xFF1A1200);
      case _CardVariant.white:
        return const Color(0xFF1A1A2E);
    }
  }

  String _variantLabel(AppLocalizations l10n) => switch (variant) {
    _CardVariant.silver => l10n.cardsSilver,
    _CardVariant.gold => l10n.cardsGold,
    _CardVariant.white => l10n.cardsPlatinum,
  };
}

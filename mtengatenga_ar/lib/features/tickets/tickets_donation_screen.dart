import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

class TicketsDonationScreen extends StatefulWidget {
  const TicketsDonationScreen({super.key});

  @override
  State<TicketsDonationScreen> createState() => _TicketsDonationScreenState();
}

class _TicketsDonationScreenState extends State<TicketsDonationScreen> {
  int adult = 1;
  int student = 0;
  int international = 0;

  int donationPreset = 0; // 0=$5, 1=$10, 2=$20
  bool monthly = false;

  final TextEditingController _customDonation = TextEditingController();

  // hero image url from Stitch :contentReference[oaicite:1]{index=1}
  static const heroUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAW9Z4KzoiTwNkAkRI8heKUJuYHXAOKOXdWVDQ-QNvdSuElrMho60_9VQKEBHsr8pRyD3DqZIkBfmSxj9MMc_IADwV13yOibBIPY2kR84Op5WquHsQkZY_7b1CCSTz-oqNkyoRYiYnshlKf23REsWsyfE-0bmix1LESKRO5LzUKU_xbCBQ1pl5kHuVVUiLzSHAfGBHQ1DaV5RwURUYyu7aMxqfIjdM8LB1TE1d-Me4YmRlys2D9CyuwRrAX_9DElp0at_iPH3XkOPO9';

  int get ticketTotalMWK => adult * 2000 + student * 1000; // UI-only
  String get donationLabel {
    final custom = _customDonation.text.trim();
    if (custom.isNotEmpty) return '\$${custom} donation';
    return donationPreset == 0 ? '+ \$5.00 donation' : donationPreset == 1 ? '+ \$10.00 donation' : '+ \$20.00 donation';
  }

  @override
  void dispose() {
    _customDonation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFDFCF0); // soft-cream :contentReference[oaicite:2]{index=2}
    const border = Color(0x33D2B48C); // earth-border/30 :contentReference[oaicite:3]{index=3}
    const primary = Color(0xFFD2691E); // terracotta :contentReference[oaicite:4]{index=4}
    const clay = Color(0xFFB25642);
    const dark = Color(0xFF3C2A21);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Column(
            children: [
              _StickyHeader(
                title: 'TICKETS & DONATION',
                onBack: () => Navigator.pop(context),
                onQr: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scan ticket (UI only)')),
                  );
                },
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    _HeroCard(imageUrl: heroUrl),
                    const SizedBox(height: 18),

                    // Choose entry header
                    Row(
                      children: [
                        const Text(
                          'Choose Entry',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: dark,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.60),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: border),
                            boxShadow: const [
                              BoxShadow(blurRadius: 6, offset: Offset(0, 2), color: Color(0x0A000000)),
                            ],
                          ),
                          child: Text(
                            'Date: Today',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: dark.withOpacity(0.65),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Horizontal ticket cards (snap-like)
                    SizedBox(
                      height: 218,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.zero,
                        children: [
                          _TicketCard(
                            highlighted: true,
                            icon: Icons.person,
                            title: 'Adult',
                            subtitle: 'Standard entry (18+)',
                            badge: 'Best Value',
                            price: 'MWK 2,000',
                            count: adult,
                            onMinus: () => setState(() => adult = (adult - 1).clamp(0, 99)),
                            onPlus: () => setState(() => adult = (adult + 1).clamp(0, 99)),
                          ),
                          const SizedBox(width: 14),
                          _TicketCard(
                            highlighted: false,
                            icon: Icons.school,
                            title: 'Student',
                            subtitle: 'Valid ID required',
                            price: 'MWK 1,000',
                            count: student,
                            onMinus: () => setState(() => student = (student - 1).clamp(0, 99)),
                            onPlus: () => setState(() => student = (student + 1).clamp(0, 99)),
                            plusMuted: true,
                          ),
                          const SizedBox(width: 14),
                          _TicketCard(
                            highlighted: false,
                            icon: Icons.public,
                            title: 'International',
                            subtitle: 'Includes audio guide',
                            price: r'$10 USD',
                            count: international,
                            onMinus: () => setState(() => international = (international - 1).clamp(0, 99)),
                            onPlus: () => setState(() => international = (international + 1).clamp(0, 99)),
                            plusMuted: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Feature chips
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: const [
                          _FeaturePill(text: 'Museum Access'),
                          SizedBox(width: 10),
                          _FeaturePill(text: 'AR Experience'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    Container(height: 1, color: const Color(0x33D2B48C)),
                    const SizedBox(height: 18),

                    // Support section header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Support the Museum',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: dark,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                "Help preserve Malawi's cultural heritage.",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0x993C2A21),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: primary.withOpacity(0.20)),
                            boxShadow: const [
                              BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: Color(0x0A000000)),
                            ],
                          ),
                          child: const Icon(Icons.volunteer_activism, color: primary),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Preset donation buttons
                    Row(
                      children: [
                        Expanded(
                          child: _DonatePreset(
                            text: r'$5',
                            active: donationPreset == 0 && _customDonation.text.trim().isEmpty,
                            onTap: () => setState(() {
                              donationPreset = 0;
                              _customDonation.clear();
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DonatePreset(
                            text: r'$10',
                            active: donationPreset == 1 && _customDonation.text.trim().isEmpty,
                            onTap: () => setState(() {
                              donationPreset = 1;
                              _customDonation.clear();
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DonatePreset(
                            text: r'$20',
                            active: donationPreset == 2 && _customDonation.text.trim().isEmpty,
                            onTap: () => setState(() {
                              donationPreset = 2;
                              _customDonation.clear();
                            }),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Custom amount input
                    TextField(
                      controller: _customDonation,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 14, right: 8),
                          child: Text(
                            r'$',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: dark.withOpacity(0.40),
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        hintText: 'Enter custom amount',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                        hintStyle: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: dark.withOpacity(0.25),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Color(0x66D2B48C)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: primary, width: 2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Monthly toggle row
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: border),
                        boxShadow: const [
                          BoxShadow(blurRadius: 10, offset: Offset(0, 3), color: Color(0x0A000000)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Switch(
                            value: monthly,
                            onChanged: (v) => setState(() => monthly = v),
                            activeColor: primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Make this a monthly donation',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: dark.withOpacity(0.80),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ],
          ),

          // Fixed bottom bar :contentReference[oaicite:5]{index=5}
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: border)),
                boxShadow: const [
                  BoxShadow(blurRadius: 16, offset: Offset(0, -8), color: Color(0x0D000000)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL AMOUNT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                              color: dark.withOpacity(0.45),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'MWK ${ticketTotalMWK.toString()}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: dark,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            donationLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Buy Now (UI only)')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'BUY NOW',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_forward),
                            ],
                          ),
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
    );
  }
}

class _StickyHeader extends StatelessWidget {
  const _StickyHeader({
    required this.title,
    required this.onBack,
    required this.onQr,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onQr;

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF3C2A21);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xE6FDFCF0), // soft-cream/90 :contentReference[oaicite:6]{index=6}
        border: Border(bottom: BorderSide(color: Color(0x33D2B48C))),
      ),
      padding: const EdgeInsets.fromLTRB(12, 42, 12, 10),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(999),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.arrow_back, color: dark),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: dark,
              ),
            ),
          ),
          InkWell(
            onTap: onQr,
            borderRadius: BorderRadius.circular(999),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.qr_code_scanner, color: dark),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x33D2B48C)),
        boxShadow: const [
          BoxShadow(blurRadius: 16, offset: Offset(0, 6), color: Color(0x14000000)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(imageUrl, fit: BoxFit.cover),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xB3000000), Color(0x33000000), Colors.transparent],
              ),
            ),
          ),
          const Positioned(
            left: 16,
            bottom: 16,
            right: 16,
            child: _HeroText(),
          ),
        ],
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MTENGATENGA AR MUSEUM',
          style: TextStyle(
            color: Colors.white.withOpacity(0.80),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.0,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Plan Your Visit',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.schedule, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'Open Daily: 09:00 - 17:00',
              style: TextStyle(
                color: Colors.white.withOpacity(0.90),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.highlighted,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.price,
    required this.count,
    required this.onMinus,
    required this.onPlus,
    this.plusMuted = false,
  });

  final bool highlighted;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final String price;
  final int count;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final bool plusMuted;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFD2691E);
    const dark = Color(0xFF3C2A21);
    const border = Color(0x33D2B48C);

    return Container(
      width: 280,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: highlighted ? primary : border, width: highlighted ? 2 : 1),
        boxShadow: const [
          BoxShadow(blurRadius: 10, offset: Offset(0, 3), color: Color(0x0F000000)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -6,
            right: -6,
            child: Opacity(
              opacity: 0.06,
              child: Icon(icon, size: 96, color: dark),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900, color: dark)),
                        const SizedBox(height: 4),
                        Text(subtitle,
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: dark.withOpacity(0.55))),
                      ],
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: primary.withOpacity(0.20)),
                      ),
                      child: Text(
                        badge!.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: primary,
                        ),
                      ),
                    )
                ],
              ),
              const SizedBox(height: 18),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFB25642),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0x80FDFCF0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x33D2B48C)),
                ),
                child: Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove,
                      filled: false,
                      onTap: onMinus,
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '$count',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark),
                        ),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add,
                      filled: highlighted && !plusMuted,
                      muted: plusMuted && !highlighted,
                      onTap: onPlus,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.filled,
    required this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final bool filled;
  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFD2691E);
    const dark = Color(0xFF3C2A21);
    const border = Color(0x33D2B48C);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: filled
              ? primary
              : muted
                  ? const Color(0x33D2B48C)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: filled ? primary : border),
          boxShadow: const [
            BoxShadow(blurRadius: 6, offset: Offset(0, 2), color: Color(0x0A000000)),
          ],
        ),
        child: Icon(icon, color: filled ? Colors.white : dark),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFD2691E);
    const dark = Color(0xFF3C2A21);
    const border = Color(0x33D2B48C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(blurRadius: 6, offset: Offset(0, 2), color: Color(0x0A000000)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 16, color: primary),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
              color: dark.withOpacity(0.70),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonatePreset extends StatelessWidget {
  const _DonatePreset({required this.text, required this.active, required this.onTap});

  final String text;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFD2691E);
    const dark = Color(0xFF3C2A21);
    const border = Color(0x66D2B48C);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: active ? primary.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? primary : border, width: active ? 2 : 1),
          boxShadow: const [
            BoxShadow(blurRadius: 10, offset: Offset(0, 3), color: Color(0x0A000000)),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: active ? primary : dark.withOpacity(0.55),
            ),
          ),
        ),
      ),
    );
  }
}

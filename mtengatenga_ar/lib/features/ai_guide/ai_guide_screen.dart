import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

class AiGuideScreen extends StatefulWidget {
  const AiGuideScreen({super.key});

  @override
  State<AiGuideScreen> createState() => _AiGuideScreenState();
}

class _AiGuideScreenState extends State<AiGuideScreen> {
  bool _english = true;

  // From Stitch avatar urls :contentReference[oaicite:1]{index=1}
  static const _headerAvatar =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCmd10se543SevR435_lQoSf0aO8kSH1ZriDap55SBQIt3kimQlfZZm1Agnk_9VYnnjPtNOdnZhQMZwTmvkHBD2Julxa3GbFHqeKqTwXY29HybzXgJ-HAFUhVqdNOlh2f8jXy9AROwsEZwkxp48ItOpmJyIisKGtxZn1cs01Wy6wkhWcYKowzTRPJlzNMKVc7zZTf8d_sB0UTRxyvhnWLnI8pf9VzmjB2A4PEWrsBUiZqLhDXEERLBYsinH5QIEYTn6H0i3izjUm3cN';

  static const _aiBubbleAvatar =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuA7ozQS35wFZChzpJwm4tEq_7rpEwwvhosDMCYgxoXuHDLqHKRfUbqKe2gkku1HB0DyMaU4lvJhgiu06t8agrEnEB99s6Q4leJ5SQMyWAW600iHxzsKeaRna_t9G6H8HeLbSKttR5YrMhlSNTqwEB0YrLZp4qFXSJns3Ib4V_PBM_ojciy4JZCMFtBFxg8viZ5S9f6StMOtnQpg2610pV-ouQAzfBL3dymV2Eo6mbBunt9O-mdQPojNY8V8K33lxfODjpUAA66b2j5-';

  static const _aiBubbleAvatar2 =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBmYuyFXnuiAZ9KbxpT_54KFrsbs9jNFfdN0lL_Yp0WnC7olnjxtaplHsp7zgmozgfmAkOHkwSPHR0fCRtDb6nSCS0Cop1HweyWoOSBykaUvDRBZ2fJbS2dYzQKG7DSXjmnZSB6udOEDo5Je9Nav6LtuaSSATbhpzZN8TGzIdaSre8Tg21okueEKt7sHo7ZgFRI_LnX296PnSL0Sg4RKDvZgwDY1iFJ66Gkos_tFsgZ7qd5vY-djLQZOFsV3QjmpY33PF7jdoIayB0d';

  // From Stitch image card url :contentReference[oaicite:2]{index=2}
  static const _artifactImage =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuD-nVHlft5lIBgbKynlUMSM5muUV_ifQQaeNdi2EbH6C6Jxxvx3ylI8aRvVUUa8FKF0O-vCoKwqVd3bB01vCnrzEDihgeaBSBaEnCV9JvKFRj379J8CeZhSHpyAVyf4P5jfwRLeeS29ht3gIAaQXu2CPMdXnd0cchNoFzO-Db8CR4AX-yJylnzWwTe_dKe9muZqvGIKo-jWNuy7KkhMYKs-CdP7nXMmnua8bmdoXNW8FuyOazhTlVIg-lDEzefv0jBgXHOMTTHiOB_T';

  final _scroll = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCF8), // warm-off-white :contentReference[oaicite:3]{index=3}
      body: Stack(
        children: [
          Column(
            children: [
              _Header(
                avatarUrl: _headerAvatar,
                onClose: () => Navigator.pop(context),
              ),
              _LanguageToggle(
                english: _english,
                onChanged: (v) => setState(() => _english = v),
              ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 190),
                  children: const [
                    _CenterHint(),
                    SizedBox(height: 18),

                    _AiTextBubble(
                      avatarUrl: _aiBubbleAvatar,
                      label: 'AI Guide',
                      text:
                          "Moni! I see you're looking at the Iron Smelting Furnace. Would you like to know how it was built?",
                    ),
                    SizedBox(height: 14),

                    _YouBubble(
                      label: 'You',
                      text: 'What is this tool used for?',
                    ),
                    SizedBox(height: 14),

                    _AiImageBubble(
                      avatarUrl: _aiBubbleAvatar2,
                      label: 'AI Guide',
                      imageUrl: _artifactImage,
                      imageTag: 'Artifact #402',
                      text:
                          'This is a traditional hoe (Kasuda) used for farming maize. It represents the agricultural roots of the Chewa people.',
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Bottom voice panel (fixed)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomVoicePanel(),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.avatarUrl, required this.onClose});

  final String avatarUrl;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 46, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xCCFFFFFF), // white/80 :contentReference[oaicite:4]{index=4}
        border: Border(bottom: BorderSide(color: Color(0xFFE6E2DC))), // border-warm :contentReference[oaicite:5]{index=5}
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 2),
            color: Color(0x0A000000),
          )
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE07A5F), width: 2), // primary :contentReference[oaicite:6]{index=6}
                  image: DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover),
                ),
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Guide',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textMain,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Connected to AR Museum',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8D6E63),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFF1EEE6), // clay-light :contentReference[oaicite:7]{index=7}
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: AppColors.textMain),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.english, required this.onChanged});

  final bool english;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0x80FDFCF8),
      ),
      child: Center(
        child: Container(
          height: 44,
          width: 280,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1EEE6), // clay-light :contentReference[oaicite:8]{index=8}
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE6E2DC)), // border-warm :contentReference[oaicite:9]{index=9}
            boxShadow: const [
              BoxShadow(blurRadius: 2, offset: Offset(0, 1), color: Color(0x0A000000)),
            ],
          ),
          child: Row(
            children: [
              _LangPill(
                label: 'English',
                active: english,
                onTap: () => onChanged(true),
              ),
              _LangPill(
                label: 'Chichewa',
                active: !english,
                onTap: () => onChanged(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangPill extends StatelessWidget {
  const _LangPill({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: double.infinity,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? const [
                    BoxShadow(blurRadius: 3, offset: Offset(0, 1), color: Color(0x14000000)),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: active ? const Color(0xFFE07A5F) : const Color(0xFF8D6E63), // primary / muted :contentReference[oaicite:10]{index=10}
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterHint extends StatelessWidget {
  const _CenterHint();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.65,
      child: Column(
        children: const [
          SizedBox(height: 10),
          Icon(Icons.history_edu, size: 34, color: Color(0xFFBCAAA4)),
          SizedBox(height: 6),
          Text(
            'Malawi Cultural Heritage Guide',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8D6E63),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiTextBubble extends StatelessWidget {
  const _AiTextBubble({
    required this.avatarUrl,
    required this.label,
    required this.text,
  });

  final String avatarUrl;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _SmallAvatar(url: avatarUrl),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: Color(0xFF8D6E63),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EEE6), // clay-light :contentReference[oaicite:11]{index=11}
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(color: const Color(0xFFE6E2DC)), // border-warm :contentReference[oaicite:12]{index=12}
                  boxShadow: const [
                    BoxShadow(blurRadius: 4, offset: Offset(0, 1), color: Color(0x0A000000)),
                  ],
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AiImageBubble extends StatelessWidget {
  const _AiImageBubble({
    required this.avatarUrl,
    required this.label,
    required this.imageUrl,
    required this.imageTag,
    required this.text,
  });

  final String avatarUrl;
  final String label;
  final String imageUrl;
  final String imageTag;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _SmallAvatar(url: avatarUrl),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: Color(0xFF8D6E63),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EEE6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE6E2DC)),
                  boxShadow: const [
                    BoxShadow(blurRadius: 4, offset: Offset(0, 1), color: Color(0x0A000000)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SizedBox(
                      height: 130,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(imageUrl, fit: BoxFit.cover),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Color(0x66000000), Colors.transparent],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            bottom: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.textMain.withOpacity(0.60),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                imageTag,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _YouBubble extends StatelessWidget {
  const _YouBubble({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: Color(0xFF8D6E63),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFE07A5F), // primary :contentReference[oaicite:13]{index=13}
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(6),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(blurRadius: 10, offset: Offset(0, 3), color: Color(0x1A000000)),
                  ],
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  const _SmallAvatar({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE6E2DC)),
        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
    );
  }
}

class _BottomVoicePanel extends StatelessWidget {
  const _BottomVoicePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      decoration: const BoxDecoration(
        color: Color(0xF2FFFFFF), // white/95 :contentReference[oaicite:14]{index=14}
        border: Border(top: BorderSide(color: Color(0xFFE6E2DC))), // border-warm :contentReference[oaicite:15]{index=15}
        boxShadow: [
          BoxShadow(blurRadius: 22, offset: Offset(0, -4), color: Color(0x0D000000)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // quick chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: const [
                _QuickChip('Tell me a story'),
                SizedBox(width: 10),
                _QuickChip('Who made this?'),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _SmallRoundButton(icon: Icons.keyboard),
              _MicButton(),
              _SmallRoundButton(icon: Icons.history),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'HOLD TO SPEAK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
              color: Color(0xFF8D6E63),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFCF8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6E2DC)),
        boxShadow: const [
          BoxShadow(blurRadius: 4, offset: Offset(0, 1), color: Color(0x0A000000)),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.textMain,
        ),
      ),
    );
  }
}

class _SmallRoundButton extends StatelessWidget {
  const _SmallRoundButton({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFF1EEE6), // clay-light :contentReference[oaicite:16]{index=16}
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x80E6E2DC)),
        ),
        child: Icon(icon, color: AppColors.textMain.withOpacity(0.85)),
      ),
    );
  }
}

class _MicButton extends StatefulWidget {
  const _MicButton();

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // textured-brown button + subtle pulse ring :contentReference[oaicite:17]{index=17}
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final ringOpacity = 0.10 + 0.15 * _pulse.value;
        final ringScale = 1.10 + 0.08 * _pulse.value;

        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: ringScale,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5E3C).withOpacity(ringOpacity), // textured-brown/20 :contentReference[oaicite:18]{index=18}
                  shape: BoxShape.circle,
                ),
              ),
            ),
            InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: Color(0xFF8B5E3C), // textured-brown :contentReference[oaicite:19]{index=19}
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 18,
                      offset: Offset(0, 10),
                      color: Color(0x668B5E3C),
                    ),
                  ],
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 36),
              ),
            ),
          ],
        );
      },
    );
  }
}

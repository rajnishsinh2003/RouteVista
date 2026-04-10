import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with SingleTickerProviderStateMixin {
  int _selectedPlan = 1; // 0=monthly, 1=yearly, 2=lifetime
  late AnimationController _shimmerController;

  final List<Map<String, dynamic>> _plans = [
    {
      'title': 'Monthly',
      'price': '₹149',
      'period': '/month',
      'savings': '',
      'color': const Color(0xFF667EEA),
    },
    {
      'title': 'Yearly',
      'price': '₹999',
      'period': '/year',
      'savings': 'Save 44%',
      'color': const Color(0xFFFFD700),
      'popular': true,
    },
    {
      'title': 'Lifetime',
      'price': '₹1,999',
      'period': 'one-time',
      'savings': 'Best Value',
      'color': const Color(0xFF00BFA6),
    },
  ];

  final List<Map<String, dynamic>> _features = [
    {
      'icon': Icons.map_outlined,
      'title': 'Offline Maps',
      'desc': 'Download maps for offline navigation',
      'free': false,
      'pro': true,
    },
    {
      'icon': Icons.auto_awesome,
      'title': 'AI Trip Planner',
      'desc': 'Smart itinerary suggestions powered by AI',
      'free': false,
      'pro': true,
    },
    {
      'icon': Icons.block,
      'title': 'Ad-Free Experience',
      'desc': 'No ads, no interruptions',
      'free': false,
      'pro': true,
    },
    {
      'icon': Icons.route_rounded,
      'title': 'Multi-Stop Routes',
      'desc': 'Plan routes with up to 10 stops',
      'free': false,
      'pro': true,
    },
    {
      'icon': Icons.cloud_download_outlined,
      'title': 'Export Trip Reports',
      'desc': 'PDF reports with budget & route details',
      'free': false,
      'pro': true,
    },
    {
      'icon': Icons.support_agent,
      'title': 'Priority Support',
      'desc': '24/7 dedicated customer support',
      'free': false,
      'pro': true,
    },
    {
      'icon': Icons.explore_rounded,
      'title': 'Route Planning',
      'desc': 'Basic source to destination routing',
      'free': true,
      'pro': true,
    },
    {
      'icon': Icons.restaurant,
      'title': 'Quick Services',
      'desc': 'Find nearby restaurants, fuel, hospitals',
      'free': true,
      'pro': true,
    },
    {
      'icon': Icons.account_balance_wallet,
      'title': 'Budget Estimator',
      'desc': 'Basic trip cost estimation',
      'free': true,
      'pro': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF0D1B2A),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B), Color(0xFF065A60)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Animated crown icon
                      AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          return Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFFFD700).withValues(alpha: 0.2 + 0.3 * _shimmerController.value),
                                  const Color(0xFFFFD700).withValues(alpha: 0.1),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withValues(alpha: 0.2 + 0.2 * _shimmerController.value),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              size: 42,
                              color: Color(0xFFFFD700),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'RouteVista Pro',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unlock the full travel experience',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Plan Cards
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 28),

                  // Plans
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Choose Your Plan',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Plan selector cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: List.generate(3, (index) => _buildPlanCard(index)),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Subscribe button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _subscribe,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: const Color(0xFF1A1A2E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: const Color(0xFFFFD700).withValues(alpha: 0.4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.diamond_rounded, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              'Subscribe to ${_plans[_selectedPlan]['title']} — ${_plans[_selectedPlan]['price']}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '7-day free trial • Cancel anytime',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Feature comparison
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(
                          'Feature Comparison',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Free',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Pro',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Feature list
                  ...List.generate(_features.length, (i) => _buildFeatureRow(i)),

                  const SizedBox(height: 32),

                  // Testimonials
                  _buildTestimonialsSection(),

                  const SizedBox(height: 24),

                  // FAQ
                  _buildFAQSection(),

                  const SizedBox(height: 32),

                  // Restore purchases
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Checking for existing purchases...', style: GoogleFonts.poppins()),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: const Color(0xFF065A60),
                        ),
                      );
                    },
                    child: Text(
                      'Restore Purchases',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF065A60),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Payment will be charged via Google Play. Subscription renews automatically unless cancelled 24 hours before the end of the current period.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey[400],
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(int index) {
    final plan = _plans[index];
    final isSelected = _selectedPlan == index;
    final isPopular = plan['popular'] == true;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPlan = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? (plan['color'] as Color) : Colors.grey[200]!,
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (plan['color'] as Color).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              if (isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '⭐ POPULAR',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                )
              else
                const SizedBox(height: 22),
              Text(
                plan['title'],
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? const Color(0xFF1A1A2E) : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                plan['price'],
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? (plan['color'] as Color) : Colors.grey[700],
                ),
              ),
              Text(
                plan['period'],
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
              if ((plan['savings'] as String).isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    plan['savings'],
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              ] else
                const SizedBox(height: 22),
              const SizedBox(height: 6),
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSelected ? (plan['color'] as Color) : Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(int index) {
    final feature = _features[index];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF065A60).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(feature['icon'], size: 20, color: const Color(0xFF065A60)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature['title'],
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  feature['desc'],
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Free column
          SizedBox(
            width: 28,
            child: Icon(
              feature['free'] ? Icons.check_circle : Icons.cancel,
              size: 20,
              color: feature['free'] ? Colors.green : Colors.grey[300],
            ),
          ),
          const SizedBox(width: 10),
          // Pro column
          SizedBox(
            width: 28,
            child: Icon(
              feature['pro'] ? Icons.check_circle : Icons.cancel,
              size: 20,
              color: feature['pro'] ? const Color(0xFFFFD700) : Colors.grey[300],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonialsSection() {
    final testimonials = [
      {
        'name': 'Priya S.',
        'text': 'Offline maps saved my Ladakh trip! No signal for 200km but RouteVista Pro kept me on track.',
        'rating': 5,
        'avatar': 'P',
      },
      {
        'name': 'Rahul M.',
        'text': 'The AI trip planner created the perfect 7-day Rajasthan itinerary. Worth every rupee!',
        'rating': 5,
        'avatar': 'R',
      },
      {
        'name': 'Ananya K.',
        'text': 'No ads + multi-stop routing makes road trips so much smoother. Upgraded to lifetime!',
        'rating': 5,
        'avatar': 'A',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'What Pro Users Say',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A2E),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: testimonials.length,
            itemBuilder: (context, i) {
              final t = testimonials[i];
              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF065A60),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              t['avatar'] as String,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['name'] as String,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            Row(
                              children: List.generate(
                                t['rating'] as int,
                                (_) => const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFC107)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Text(
                        t['text'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFAQSection() {
    final faqs = [
      {
        'q': 'Can I cancel my subscription?',
        'a': 'Yes! You can cancel anytime from your Google Play subscriptions. Your Pro features will remain active until the end of your billing period.',
      },
      {
        'q': 'Is there a free trial?',
        'a': 'Yes! Every plan comes with a 7-day free trial. You won\'t be charged until the trial ends.',
      },
      {
        'q': 'What happens to my offline maps if I cancel?',
        'a': 'Downloaded maps will be removed after your subscription ends, but your saved trips and preferences will remain.',
      },
      {
        'q': 'Can I switch plans?',
        'a': 'Absolutely! You can upgrade or downgrade anytime. The difference will be prorated.',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FAQs',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          ...faqs.map((faq) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  title: Text(
                    faq['q']!,
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  children: [
                    Text(
                      faq['a']!,
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600], height: 1.5),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _subscribe() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 28),
            const SizedBox(width: 10),
            Text(
              'Start Free Trial',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You selected the ${_plans[_selectedPlan]['title']} plan at ${_plans[_selectedPlan]['price']}${_plans[_selectedPlan]['period'] == 'one-time' ? '' : _plans[_selectedPlan]['period']}.',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFFFFD700), size: 18),
                      const SizedBox(width: 8),
                      Text('7-day free trial', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFFFFD700), size: 18),
                      const SizedBox(width: 8),
                      Text('Cancel anytime', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFFFFD700), size: 18),
                      const SizedBox(width: 8),
                      Text('All Pro features unlocked', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text('Welcome to RouteVista Pro! 🎉', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  backgroundColor: const Color(0xFF065A60),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: const Color(0xFF1A1A2E),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Start Trial', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

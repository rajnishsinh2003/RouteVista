import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/review_model.dart';
import '../services/place_service.dart';
import '../services/bookmark_service.dart';

class PlaceDetailScreen extends StatefulWidget {
  final String name;
  final String location;
  final String imageUrl;
  final double rating;
  final String category;
  final String description;
  final List<String> highlights;
  final VoidCallback? onNavigate;
  final VoidCallback? onSave;

  const PlaceDetailScreen({
    super.key,
    required this.name,
    required this.location,
    required this.imageUrl,
    required this.rating,
    this.category = '',
    this.description = '',
    this.highlights = const [],
    this.onNavigate,
    this.onSave,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  bool _isSaved = false;
  final _commentController = TextEditingController();
  double _userRating = 5.0;
  bool _isSubmitting = false;
  List<File> _userPhotos = [];
  final ImagePicker _picker = ImagePicker();
  String? _dynamicDescription;
  String? _dynamicImageUrl;
  bool _isLoadingWiki = false;

  String get _placeId => widget.name.toLowerCase().replaceAll(' ', '_');

  @override
  void initState() {
    super.initState();
    _loadUserPhotos();
    _loadDynamicData();
    _checkBookmarkStatus();
  }

  Future<void> _checkBookmarkStatus() async {
    final isSaved = await BookmarkService.isBookmarked(widget.name);
    if (mounted) setState(() => _isSaved = isSaved);
  }

  Future<void> _loadDynamicData() async {
    if (widget.description.isEmpty) {
      setState(() => _isLoadingWiki = true);
      final data = await PlaceService.fetchWikipediaData(widget.name);
      if (mounted && data != null) {
        setState(() {
          _dynamicDescription = data['description'];
          _dynamicImageUrl = data['imageUrl'];
          _isLoadingWiki = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingWiki = false);
      }
    }
  }

  Future<void> _loadUserPhotos() async {
    if (kIsWeb) return; // dart:io not supported on web
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${appDir.path}/photos/$_placeId');
    if (await photosDir.exists()) {
      final files = photosDir.listSync().whereType<File>().toList();
      setState(() => _userPhotos = files);
    }
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo upload is only available on mobile.')),
      );
      return;
    }
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${appDir.path}/photos/$_placeId');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final String fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File localImage = await File(image.path).copy('${photosDir.path}/$fileName');

    setState(() => _userPhotos.insert(0, localImage));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF065A60),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: (widget.imageUrl.isNotEmpty ? widget.imageUrl : _dynamicImageUrl) ?? '',
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(color: Colors.grey[300]),
                    errorWidget: (c, u, e) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.landscape, size: 60, color: Colors.grey),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00BFA6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.category,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        Text(
                          widget.name,
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.white70, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              widget.location,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating & Quick Info
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _infoChip(Icons.star_rounded, '${widget.rating}', const Color(0xFFFFC107)),
                      _infoChip(Icons.access_time, 'Open 06:00-20:00', Colors.green),
                      _infoChip(Icons.currency_rupee, 'Free Entry', Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // About
                  Text(
                    'About',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingWiki)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: Color(0xFF00BFA6)),
                    ))
                  else
                    Text(
                      widget.description.isNotEmpty
                          ? widget.description
                          : _dynamicDescription ?? 'No description available for this place yet.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.6,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Highlights
                  Text(
                    'Highlights',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...(widget.highlights.isNotEmpty ? widget.highlights : _getHighlights(widget.name)).map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF065A60).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.check_circle, color: Color(0xFF065A60), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            h,
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                  )),

                  const SizedBox(height: 24),

                  // ── PHOTO GALLERY ───────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Photos',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                      IconButton(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF065A60), size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPhotoGallery(),

                  const SizedBox(height: 32),

                  // ── REVIEWS SECTION ────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'User Reviews',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                      _addReviewButton(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildReviewsList(),

                  const SizedBox(height: 32),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              GestureDetector(
                onTap: () async {
                  await BookmarkService.toggleBookmark({
                    'name': widget.name,
                    'location': widget.location,
                    'image': widget.imageUrl.isNotEmpty ? widget.imageUrl : _dynamicImageUrl,
                    'rating': widget.rating,
                    'category': widget.category,
                    'description': widget.description.isNotEmpty ? widget.description : _dynamicDescription,
                  });
                  await _checkBookmarkStatus();
                  if (widget.onSave != null) widget.onSave!();
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF065A60), width: 2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: const Color(0xFF065A60)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF065A60),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (widget.onNavigate != null) widget.onNavigate!();
                  },
                  icon: const Icon(Icons.navigation_rounded),
                  label: Text(
                    'Navigate Here',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getDefaultDescription(String placeName) {
    final descriptions = {
      'Taj Mahal': 'The Taj Mahal is an ivory-white marble mausoleum on the right bank of the river Yamuna in Agra, Uttar Pradesh. It was commissioned in 1631 by the fifth Mughal emperor, Shah Jahan, to house the tomb of his beloved wife, Mumtaz Mahal. Often described as one of the Seven Wonders of the World, it attracts millions of visitors annually and is a UNESCO World Heritage Site.',
      'Goa Beaches': 'Goa, the smallest state in India, is renowned for its stunning beaches, vibrant nightlife, Portuguese heritage architecture, and delicious seafood cuisine. From the bustling shores of Baga and Calangute to the serene sands of Palolem and Agonda, Goa offers something for every type of traveler. The state is also home to beautiful churches, spice plantations, and wildlife sanctuaries.',
      'Jaipur City Palace': 'The City Palace in Jaipur is a magnificent blend of Rajasthani and Mughal architecture. Built by Maharaja Sawai Jai Singh II, it includes the Chandra Mahal and Mubarak Mahal palaces along with other buildings. The palace complex is surrounded by walls and gardens. Part of the palace is still a royal residence, while the rest houses museums displaying royal costumes, paintings, and armory.',
      'Kerala Backwaters': 'The Kerala backwaters are a chain of brackish lagoons and lakes lying parallel to the Arabian Sea coast in Kerala. They include five large lakes linked by canals, both manmade and natural. A houseboat cruise through the backwaters is one of the most iconic experiences in India. The serene waterways are fringed by palm trees, rice paddies, and quaint villages.',
      'Varanasi Ghats': 'Varanasi, one of the oldest continuously inhabited cities in the world, sits on the banks of the sacred River Ganges. The ghats of Varanasi are a series of steps leading down to the river where pilgrims perform ritual ablutions. The evening Ganga Aarti ceremony at Dashashwamedh Ghat is a mesmerizing spectacle of fire, chanting, and devotion that attracts thousands daily.',
    };
    return descriptions[placeName] ??
        '$placeName is a popular tourist destination in India known for its rich cultural heritage, stunning architecture, and vibrant atmosphere. Visitors can explore historical monuments, enjoy local cuisine, and experience the unique traditions of the region. The best time to visit is during the cooler months from October to March.';
  }

  List<String> _getHighlights(String placeName) {
    final highlights = {
      'Taj Mahal': ['UNESCO World Heritage Site', 'Seven Wonders of the World', 'Mughal Architecture Masterpiece', 'Best at Sunrise & Sunset'],
      'Goa Beaches': ['Pristine Sandy Beaches', 'Water Sports & Activities', 'Portuguese Heritage', 'Vibrant Nightlife & Cuisine'],
      'Jaipur City Palace': ['Royal Rajasthani Architecture', 'Museum with Royal Artifacts', 'Beautiful Courtyards & Gardens', 'Light & Sound Show'],
      'Kerala Backwaters': ['Houseboat Cruises', 'Lush Green Landscapes', 'Traditional Kerala Cuisine', 'Bird Watching & Nature Walks'],
      'Varanasi Ghats': ['Sacred Ganga Aarti Ceremony', 'Ancient Temples & Shrines', 'Boat Rides at Dawn', 'Spiritual & Cultural Hub'],
    };
    return highlights[placeName] ?? ['Popular Tourist Spot', 'Rich Cultural Heritage', 'Local Cuisine & Shopping', 'Photography & Sightseeing'];
  }

  // ── Review Helper Widgets ────────────────────────

  Widget _addReviewButton() {
    return TextButton.icon(
      onPressed: _showReviewDialog,
      icon: const Icon(Icons.add_comment_rounded, size: 18, color: Color(0xFF065A60)),
      label: Text('Write a review', style: GoogleFonts.poppins(color: const Color(0xFF065A60), fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _buildReviewsList() {
    // Guard: Firestore requires Firebase to be configured
    final bool firestoreAvailable = Firebase.apps.isNotEmpty;
    if (!firestoreAvailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(Icons.reviews_outlined, color: Colors.grey[300], size: 40),
              const SizedBox(height: 8),
              Text(
                'Reviews not available in demo mode.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('placeId', isEqualTo: _placeId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Could not load reviews.',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00BFA6)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('No reviews yet. Be the first to share your experience!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final review = ReviewModel.fromFirestore(snapshot.data!.docs[index]);
            return _reviewCard(review);
          },
        );
      },
    );
  }

  Widget _reviewCard(ReviewModel review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF065A60).withOpacity(0.1),
                radius: 16,
                child: Text(review.userName[0].toUpperCase(), style: const TextStyle(fontSize: 12, color: Color(0xFF065A60))),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(review.userName, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(
                    '${review.timestamp.day}/${review.timestamp.month}/${review.timestamp.year}',
                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: List.generate(5, (i) => Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: i < review.rating ? const Color(0xFFFFC107) : Colors.grey[300],
                )),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(review.comment, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[800])),
        ],
      ),
    );
  }

  void _showReviewDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to leave a review')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Rate your experience', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  icon: Icon(
                    Icons.star_rounded,
                    color: i < _userRating ? const Color(0xFFFFC107) : Colors.grey[300],
                    size: 32,
                  ),
                  onPressed: () => setDialogState(() => _userRating = i + 1.0),
                )),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                maxLines: 3,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Tell others about your visit...',
                  hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00BFA6))),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF065A60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: _isSubmitting ? null : () => _submitReview(ctx),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Submit', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReview(BuildContext dialogContext) async {
    if (_commentController.text.trim().isEmpty) return;

    // Guard: Firestore requires Firebase to be configured
    if (Firebase.apps.isEmpty) {
      if (mounted) Navigator.pop(dialogContext);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reviews require Firebase setup. Coming soon!')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final review = ReviewModel(
        id: '',
        userId: user?.uid ?? '',
        userName: user?.displayName ?? 'Traveler',
        placeId: _placeId,
        comment: _commentController.text.trim(),
        rating: _userRating,
        timestamp: DateTime.now(),
      );

      await FirebaseFirestore.instance.collection('reviews').add(review.toMap());
      
      _commentController.clear();
      if (mounted) Navigator.pop(dialogContext);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you for your review!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildPhotoGallery() {
    if (kIsWeb) {
      return Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, color: Colors.grey[400], size: 28),
            const SizedBox(height: 6),
            Text('Photo gallery available on mobile app.',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      );
    }
    if (_userPhotos.isEmpty) {
      return Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, color: Colors.grey[400], size: 28),
            const SizedBox(height: 6),
            Text('No photos yet. Add your memories!',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _userPhotos.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            width: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(image: FileImage(_userPhotos[index]), fit: BoxFit.cover),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
            ),
          );
        },
      ),
    );
  }
}

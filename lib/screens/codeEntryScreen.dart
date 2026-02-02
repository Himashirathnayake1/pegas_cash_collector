import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'home_screen.dart';
import '../services/mock_data_service.dart';
import '../services/branch_auth_service.dart';
import '../services/branch_context.dart';
import '../utils/app_theme.dart';

class AccessCodeEntryScreen extends StatefulWidget {
  @override
  _AccessCodeEntryScreenState createState() => _AccessCodeEntryScreenState();
}

class _AccessCodeEntryScreenState extends State<AccessCodeEntryScreen>
    with TickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final BranchAuthService _branchAuthService = BranchAuthService();
  String? _errorMessage;
  bool _isChecking = false;
  String? _selectedBranch;
  String? _selectedRole;
  bool _isLoadingBranches = true;
  List<String> _branches = [];

  final List<String> _roles = ['cashCollector', 'adder', 'store'];
  final Map<String, String> _roleLabels = {
    'cashCollector': 'Cash Collector',
    'adder': 'Adder',
    'store': 'Store Keeper',
  };

  // Animation controllers
  late final AnimationController _pulse, _fadeSlide, _dots, _particles, _glow;
  late final Animation<double> _scale, _fade, _glowAnimation;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _pulse =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    _fadeSlide = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..forward();
    _dots =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();
    _particles =
        AnimationController(vsync: this, duration: const Duration(seconds: 20))
          ..repeat();
    _glow =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);

    _scale = Tween(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _fade = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeSlide, curve: Curves.easeOut));
    _slide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(parent: _fadeSlide, curve: Curves.easeOutCubic));
    _glowAnimation = Tween(begin: 0.3, end: 0.8)
        .animate(CurvedAnimation(parent: _glow, curve: Curves.easeInOut));

    // Load branches from Firestore
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      print('🔄 Loading branches...');
      final branches = await _branchAuthService.fetchBranchIds();
      
      if (branches.isEmpty) {
        print('⚠️ No branches returned from Firestore');
        print('   If branches are set up, check Firestore rules and network connectivity');
      }
      
      setState(() {
        _branches = branches;
        _isLoadingBranches = false;
      });
      
      print('✅ Branches loaded: $_branches');
    } catch (e) {
      print('❌ Error loading branches: $e');
      setState(() {
        _isLoadingBranches = false;
        _errorMessage = 'Failed to load branches: $e';
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _fadeSlide.dispose();
    _dots.dispose();
    _particles.dispose();
    _glow.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<bool> _verifyAccessCode(String inputCode) async {
    // Verify against Firestore
    if (_selectedBranch == null || _selectedRole == null) {
      print('❌ Branch or role not selected');
      return false;
    }
    
    print('🔐 Attempting to verify code for branch=$_selectedBranch, role=$_selectedRole, code=$inputCode');
    return await _branchAuthService.verifyAccessCode(
      branchId: _selectedBranch!,
      role: _selectedRole!,
      accessCode: inputCode,
    );
  }

  void _onSubmit() async {
    final input = _codeController.text.trim();

    if (_selectedBranch == null) {
      setState(() => _errorMessage = "Select Your branch.");
      return;
    }

    if (_selectedRole == null) {
      setState(() => _errorMessage = "Please select a role.");
      return;
    }

    if (input.isEmpty) {
      setState(() => _errorMessage = "Please enter the access code.");
      return;
    }

    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    final isValid = await _verifyAccessCode(input);

    setState(() => _isChecking = false);

    if (isValid) {
      // Save branch and role to context
      BranchContext().setBranchAndRole(_selectedBranch!, _selectedRole!);
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => RoutePage(selectedArea: _selectedBranch!)),
      );
    } else {
      // Clear the code field
      _codeController.clear();

      // Show error popup dialog
      _showWrongCodeDialog();
    }
  }

  void _showWrongCodeDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Wrong Code!',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'The access code you entered is incorrect. Please try again with the correct code.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Try Again',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingDot(int index) {
    return AnimatedBuilder(
      animation: _dots,
      builder: (_, __) {
        final progress = (_dots.value * 3 - index).clamp(0.0, 1.0);
        return Transform.scale(
          scale: 1 + (1 - progress) * 0.5,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentTeal.withOpacity(0.5 + progress * 0.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentTeal.withOpacity(0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AnimatedBuilder(
        animation: _particles,
        builder: (_, __) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryDark,
                AppColors.primaryMedium,
                AppColors.primaryLight,
              ],
            ),
          ),
          child: CustomPaint(
            painter: _ParticlePainter(_particles.value, _glowAnimation.value),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated Logo with Glow Effect
                    AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (_, child) => Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentBlue
                                  .withOpacity(_glowAnimation.value * 0.5),
                              blurRadius: 60,
                              spreadRadius: 20,
                            ),
                            BoxShadow(
                              color: AppColors.accentTeal
                                  .withOpacity(_glowAnimation.value * 0.3),
                              blurRadius: 80,
                              spreadRadius: 30,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                      child: ScaleTransition(
                        scale: _scale,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.15),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                ),
                                border: Border.all(
                                  color: AppColors.accentTeal.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Image.asset(
                                'assets/images/cash.png',
                                width: 90,
                                height: 90,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 35),

                    // App Title with Shimmer
                    FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: Shimmer.fromColors(
                          baseColor: AppColors.accentTeal,
                          highlightColor: AppColors.accentBlue,
                          child: Text(
                            'Pegas Flex',
                            style: GoogleFonts.orbitron(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    FadeTransition(
                      opacity: _fade,
                      child: Text(
                        'Cash Collection Management',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Glass Card Container
                    FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.12),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.15),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Branch Selection
                                  _buildLabel("Select Branch"),
                                  const SizedBox(height: 12),
                                  _isLoadingBranches
                                      ? _buildLoadingDropdown()
                                      : _buildBranchDropdown(),

                                  const SizedBox(height: 20),

                                  // Role Selection
                                  _buildLabel("Select Role"),
                                  const SizedBox(height: 12),
                                  _buildRoleDropdown(),

                                  const SizedBox(height: 28),

                                  // Access Code Field
                                  _buildLabel("Enter Access Code"),
                                  const SizedBox(height: 12),
                                  _buildCodeInput(),

                                  const SizedBox(height: 24),

                                  // Submit Button
                                  _buildSubmitButton(),

                                  // Error Message
                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.error.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              AppColors.error.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.error_outline,
                                              color: AppColors.error, size: 18),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              _errorMessage!,
                                              style: TextStyle(
                                                  color: AppColors.error,
                                                  fontSize: 14),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildLoadingDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.location_city_outlined,
              color: AppColors.textMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Loading branches...",
              style: TextStyle(color: AppColors.textMuted, fontSize: 16),
            ),
          ),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accentTeal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _selectedBranch != null
                ? AppColors.accentTeal.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBranch,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.location_city_outlined,
                    color: AppColors.textMuted, size: 20),
                const SizedBox(width: 12),
                Text(
                  "Choose a branch",
                  style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                ),
              ],
            ),
          ),
          isExpanded: true,
          icon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.accentTeal),
          ),
          dropdownColor: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          items: _branches.map((String branch) {
            return DropdownMenuItem<String>(
              value: branch,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentTeal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.location_city,
                          color: AppColors.accentTeal, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(branch[0].toUpperCase() + branch.substring(1)),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedBranch = newValue;
              _selectedRole = null; // Reset role when branch changes
              _errorMessage = null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _selectedRole != null
                ? AppColors.accentBlue.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.person_outline,
                    color: AppColors.textMuted, size: 20),
                const SizedBox(width: 12),
                Text(
                  "Choose your role",
                  style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                ),
              ],
            ),
          ),
          isExpanded: true,
          icon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.accentBlue),
          ),
          dropdownColor: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          items: _roles.map((String role) {
            return DropdownMenuItem<String>(
              value: role,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.person,
                          color: AppColors.accentBlue, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(_roleLabels[role] ?? role),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedRole = newValue;
              _errorMessage = null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildRouteDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _selectedBranch != null
              ? AppColors.accentTeal.withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBranch,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.route_outlined,
                    color: AppColors.textMuted, size: 20),
                const SizedBox(width: 12),
                Text(
                  "Choose your route",
                  style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                ),
              ],
            ),
          ),
          isExpanded: true,
          icon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.accentTeal),
          ),
          dropdownColor: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          items: _branches.map((String branch) {
            return DropdownMenuItem<String>(
              value: branch,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentTeal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.location_on,
                          color: AppColors.accentTeal, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(branch),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedBranch = newValue;
              _errorMessage = null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildCodeInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _codeController,
        textAlign: TextAlign.center,
        obscureText: true,
        obscuringCharacter: '✦',
        maxLength: 4,
        style: GoogleFonts.poppins(
          fontSize: 20,
          letterSpacing: 4,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: "✦  ✦  ✦  ✦",
          hintStyle: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.35),
            fontSize: 20,
            letterSpacing: 4,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          counterText: "",
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        keyboardType: TextInputType.number,
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isChecking ? null : _onSubmit,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: _isChecking ? null : AppColors.accentGradient,
            color: _isChecking ? AppColors.surfaceCard : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isChecking
                ? null
                : [
                    BoxShadow(
                      color: AppColors.accentBlue.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isChecking
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLoadingDot(0),
                      _buildLoadingDot(1),
                      _buildLoadingDot(2),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login_rounded, color: AppColors.primaryDark),
                      const SizedBox(width: 10),
                      Text(
                        "LOGIN",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// Custom Particle Painter for Liquid Effect
class _ParticlePainter extends CustomPainter {
  final double progress;
  final double glowIntensity;
  final Random _rnd = Random(42);

  _ParticlePainter(this.progress, this.glowIntensity);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw floating particles
    for (int i = 0; i < 80; i++) {
      final x = _rnd.nextDouble() * size.width;
      final baseY = _rnd.nextDouble() * size.height;
      final y = (baseY + progress * size.height * 0.5) % size.height;
      final radius = _rnd.nextDouble() * 2 + 0.5;

      final paint = Paint()
        ..color = (i % 3 == 0 ? AppColors.accentTeal : AppColors.accentBlue)
            .withOpacity(0.15 + _rnd.nextDouble() * 0.2);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // Draw glowing orbs
    final orbPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.accentBlue.withOpacity(glowIntensity * 0.15),
          AppColors.accentBlue.withOpacity(0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.2, size.height * 0.3),
        radius: 150,
      ));
    canvas.drawCircle(
        Offset(size.width * 0.2, size.height * 0.3), 150, orbPaint);

    final orbPaint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.accentTeal.withOpacity(glowIntensity * 0.12),
          AppColors.accentTeal.withOpacity(0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.8, size.height * 0.7),
        radius: 180,
      ));
    canvas.drawCircle(
        Offset(size.width * 0.8, size.height * 0.7), 180, orbPaint2);
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.glowIntensity != glowIntensity;
}

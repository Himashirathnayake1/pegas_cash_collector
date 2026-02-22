import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/branch_context.dart';
import '../utils/app_theme.dart';

class TermsAndConditionsPage extends StatelessWidget {
  final VoidCallback? onAgree;

  const TermsAndConditionsPage({super.key, this.onAgree});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildTermsList(),
                  ],
                ),
              ),
            ),
            _buildAgreeButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: AppColors.lightTextPrimary),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.lightSurface,
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Terms & Conditions',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentBlueDark.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentBlueDark.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accentBlueDark.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.description_rounded,
                color: AppColors.accentBlueDark, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please Read Carefully',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Agree to the following terms before continuing',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsList() {
    final terms = [
      _TermData(
        number: "1",
        title: "💰 Incentive Eligibility",
        icon: Icons.star_rounded,
        color: AppColors.warningDark,
        en: "If you collect more than Rs.10,000 above the weekly target, you will receive an incentive.",
        si: "ඔබ සතිපතා ඉලක්කයට වඩා රු.10,000කට වඩා මුදලක් එකතු කළහ ාත්, ඔබට වට්ටමක් ලැහේ.",
        ta: "நீ ங்கள் வார இலக்கக விட ரூ.10,000 க்கும் மமற்பட்ட த ாகககை வசூலி ் ால், ஊக்க ்த ாகக தபறுவீர்கள்.",
      ),
      _TermData(
        number: "2",
        title: "🏪 Daily Shop Visit Required",
        icon: Icons.store_rounded,
        color: AppColors.accentBlueDark,
        en: "You must visit all shops daily. No response from a shop in 2 days will be your responsibility.",
        si: "ඔබ සෑම දිනයකම සියලු වෙළඳසැල් බැලිය යුතුය. දින 2ක් ඇතුළත පිළිතුරක් නොමැතිවීම ඔබේ වගකීම වේ.",
        ta: "தினமும் கடைகளுக்கு செல்ல வேண்டும். 2 நாட்களில் பதில் இல்லை என்றால், அது உங்கள் பொறுப்பு.",
      ),
      _TermData(
        number: "3",
        title: "💸 Daily Payment & Receipt",
        icon: Icons.receipt_long_rounded,
        color: AppColors.successDark,
        en: "Do not keep money in hand. You must pay daily and send the receipt. Otherwise, it affects your salary.",
        si: "මුදල් අතින් තබා නොගන්න. ඔබ සෑම දිනකම ගෙවිය යුතු අතර රිසිට්පත යවන්න. නැතහොත් ඔබේ වැටුපට බලපායි.",
        ta: "பணம் கையில் வைத்திருக்க வேண்டாம். தினமும் செலுத்தி ரசீதை அனுப்ப வேண்டும். இல்லையெனில் சம்பளத்தில் பாதிப்பு ஏற்படும்.",
      ),
      _TermData(
        number: "4",
        title: "⚠️ Lost Money Responsibility",
        icon: Icons.warning_amber_rounded,
        color: AppColors.errorDark,
        en: "If the collected money is lost, it is your full responsibility.",
        si: "එකතු කළ මුදල් අහිමි වුවහොත් එය ඔබේ සම්පූර්ණ වගකීම වේ.",
        ta: "வசூலித்த பணம் இழந்தால், அது உங்கள் முழு பொறுப்பு.",
      ),
      _TermData(
        number: "5",
        title: "🎯 Weekly Target Performance",
        icon: Icons.track_changes_rounded,
        color: AppColors.accentPurpleDark,
        en: "Missing weekly target 3 weeks in a row can affect or terminate your position.",
        si: "සතියේ ඉලක්කය සති 3ක් තිස්සේ නොමැති වීම ඔබේ තනතුරට බලපානු ඇත හෝ එය අවසන් කළ හැකිය.",
        ta: "மூன்று வாரங்களுக்கு இலக்கு தவறினால், உங்கள் பதவி பாதிக்கப்படலாம் அல்லது நீக்கப்படும்.",
      ),
      _TermData(
        number: "6",
        title: "📧 Support & Contact",
        icon: Icons.email_rounded,
        color: AppColors.accentTealDark,
        en: "For any questions, contact: pegasfles2025@gmail.com",
        si: "ඕනෑම ගැටළුවකට: pegasfles2025@gmail.com අමතන්න.",
        ta: "எந்த சந்தேகத்திற்கும்: pegasfles2025@gmail.com என தொடர்பு கொள்ளவும்.",
      ),
    ];

    return Column(
      children: terms.asMap().entries.map((entry) {
        final index = entry.key;
        final term = entry.value;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (index * 80)),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _buildTermCard(term),
        );
      }).toList(),
    );
  }

  Widget _buildTermCard(_TermData term) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: term.color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: term.color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: term.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(term.icon, color: term.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  term.title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightTextPrimary,
                  ),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: term.color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    term.number,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: term.color,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '• ${term.en}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.lightTextPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '  ${term.si}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.lightTextSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '  ${term.ta}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.lightTextSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreeButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onAgree ?? () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentBlueDark,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            shadowColor: AppColors.accentBlueDark.withOpacity(0.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                'I AGREE',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermData {
  final String number;
  final String title;
  final IconData icon;
  final Color color;
  final String en;
  final String si;
  final String ta;

  _TermData({
    required this.number,
    required this.title,
    required this.icon,
    required this.color,
    required this.en,
    required this.si,
    required this.ta,
  });
}

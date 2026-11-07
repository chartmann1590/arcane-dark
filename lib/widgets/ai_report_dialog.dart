import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme.dart';
import '../services/ai_safety_service.dart';

/// Shows the AI Content Safety & Violation Reporting Sheet.
Future<void> showAiReportDialog(
  BuildContext context, {
  String? aiMessage,
  String? campaignId,
  String? characterName,
  String? sessionId,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: ArcaneTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _AiReportSheet(
      aiMessage: aiMessage,
      campaignId: campaignId,
      characterName: characterName,
      sessionId: sessionId,
    ),
  );
}

class _AiReportSheet extends StatefulWidget {
  final String? aiMessage;
  final String? campaignId;
  final String? characterName;
  final String? sessionId;

  const _AiReportSheet({
    this.aiMessage,
    this.campaignId,
    this.characterName,
    this.sessionId,
  });

  @override
  State<_AiReportSheet> createState() => _AiReportSheetState();
}

class _AiReportSheetState extends State<_AiReportSheet> {
  AiReportCategory _selectedCategory = AiReportCategory.offensive;
  final TextEditingController _detailsController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final success = await AiSafetyService.instance.submitReport(
      category: _selectedCategory,
      aiMessage: widget.aiMessage ?? 'General AI Feedback / Safety Report',
      details: _detailsController.text.trim(),
      campaignId: widget.campaignId,
      characterName: widget.characterName,
      sessionId: widget.sessionId,
    );

    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? ArcaneTheme.surfaceCard : Colors.red[900],
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
              color: success ? const Color(0xFF3DD68C) : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                success
                    ? 'Report submitted. Our safety team will review it.'
                    : 'Failed to submit report. Please try again.',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final snippet = widget.aiMessage?.trim();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: ArcaneTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ArcaneTheme.tertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined, color: ArcaneTheme.tertiary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report AI Content',
                        style: GoogleFonts.cinzel(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Google Play AI Safety & Compliance',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 11,
                          color: ArcaneTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Arcane Dark is committed to player safety. If the AI generated inappropriate, offensive, harmful, or rule-violating narrative, please report it below.',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12.5,
                color: ArcaneTheme.textSecondary,
                height: 1.45,
              ),
            ),
            if (snippet != null && snippet.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'REPORTED CONTENT',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: ArcaneTheme.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ArcaneTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ArcaneTheme.border),
                ),
                child: Text(
                  snippet.length > 260 ? '${snippet.substring(0, 260)}...' : snippet,
                  style: GoogleFonts.spectral(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: ArcaneTheme.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'REASON FOR REPORT',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: ArcaneTheme.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AiReportCategory.values.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(
                    cat.displayName,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : ArcaneTheme.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: ArcaneTheme.tertiary.withValues(alpha: 0.35),
                  backgroundColor: ArcaneTheme.surfaceElevated,
                  side: BorderSide(
                    color: isSelected ? ArcaneTheme.tertiary : ArcaneTheme.border,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'ADDITIONAL DETAILS (OPTIONAL)',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: ArcaneTheme.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Describe what went wrong or why this violates safety standards...',
                hintStyle: GoogleFonts.ibmPlexSans(fontSize: 12.5, color: ArcaneTheme.textMuted),
                filled: true,
                fillColor: ArcaneTheme.surfaceCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: ArcaneTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: ArcaneTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: ArcaneTheme.secondary),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: ArcaneTheme.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.w700,
                        color: ArcaneTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ArcaneTheme.tertiary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Submit Report',
                            style: GoogleFonts.ibmPlexSans(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

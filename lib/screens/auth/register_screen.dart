
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../utils/lowercase_email_formatter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_chrome.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/auth_required_sheet.dart';
import 'otp_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback? onLoginTap;
  const RegisterScreen({super.key, this.onLoginTap});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _agreedTerms = false;
  static const _policySite = 'https://eflora-system-production.up.railway.app';

  String? _validatePassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Must be at least 8 characters';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Must include lowercase letter';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Must include uppercase letter';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Must include special character';
    }
    return null;
  }

  String? _normalizePhMobile(String? raw) {
    var compact = (raw ?? '').trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (compact.isEmpty) return null;
    if (compact.startsWith('+63')) {
      compact = '0${compact.substring(3)}';
    } else if (compact.startsWith('63') && compact.length == 12) {
      compact = '0${compact.substring(2)}';
    }
    if (!RegExp(r'^09\d{9}$').hasMatch(compact)) return null;
    return compact;
  }

  String? _validateIdentifier(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return 'Email or phone is required';
    if (raw.contains('@')) {
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(raw.toLowerCase())) {
        return 'Enter a valid email';
      }
      return null;
    }
    if (_normalizePhMobile(raw) == null) {
      return 'Enter a valid email or PH mobile (09XXXXXXXXX)';
    }
    return null;
  }

  void _goToLogin({String? loginId}) {
    if (!mounted) return;
    pushLoginScreen(
      context,
      replace: true,
      initialEmail: loginId ?? _identifierCtrl.text.trim(),
    );
  }

  Future<void> _openPolicy(String path) async {
    final uri = Uri.parse('$_policySite$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<bool> _promptCustomerTerms() async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _CustomerTermsDialog(onOpenPolicy: _openPolicy),
    );
    return accepted == true;
  }

  Future<void> _onTermsCheckboxChanged(bool? value) async {
    if (value != true) {
      setState(() => _agreedTerms = false);
      return;
    }
    if (_agreedTerms) return;
    final ok = await _promptCustomerTerms();
    if (!mounted) return;
    if (ok) setState(() => _agreedTerms = true);
  }

  Future<void> _sendOtpAndContinue() async {
    if (!_agreedTerms) {
      final ok = await _promptCustomerTerms();
      if (!mounted) return;
      if (!ok) {
        showToast(
          context,
          'Please read and accept the Customer Terms first.',
          isError: true,
        );
        return;
      }
      setState(() => _agreedTerms = true);
    }
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    var identifier = _identifierCtrl.text.trim();
    if (identifier.contains('@')) {
      identifier = identifier.toLowerCase();
    }

    final error = await auth.sendOtp(
      fullName: _nameCtrl.text.trim(),
      identifier: identifier,
      password: _passwordCtrl.text,
      agreeTerms: true,
    );

    if (!mounted) return;

    if (error != null) {
      if (isEmailServiceUnavailableError(error, errorCode: auth.lastErrorCode)) {
        await showEmailServiceUnavailableDialog(context);
      } else {
        showToast(context, error, isError: true);
      }
      return;
    }

    final meta = auth.lastSendOtpMeta;
    final accountEmail = (meta?['email'] as String?)?.trim().toLowerCase() ?? '';
    final channel = (meta?['otp_channel'] as String?) ??
        (identifier.contains('@') ? 'email' : 'sms');
    final dest = (meta?['destination_masked'] as String?) ?? identifier;
    final loginId =
        (meta?['login_id'] as String?)?.trim() ?? identifier;

    if (accountEmail.isEmpty) {
      showToast(context, 'Could not start verification. Try again.', isError: true);
      return;
    }

    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          email: accountEmail,
          otpChannel: channel,
          destinationMasked: dest,
        ),
      ),
    );

    if (!mounted) return;
    if (verified == true) _goToLogin(loginId: loginId);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final fieldStyle = GoogleFonts.dmSans(fontSize: 14, color: AppColors.charcoal);

    final sheet = MediaQuery.sizeOf(context).width < 960;
    return AuthScaffold(
      onLeadingTap: () => Navigator.pop(context),
      hero: AuthHeroBanner(
        eyebrow: 'Join the community',
        headline: TextSpan(
          children: [
            const TextSpan(text: 'Start your\n'),
            TextSpan(
              text: 'blooming',
              style: GoogleFonts.cormorantGaramond(
                fontStyle: FontStyle.italic,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
            const TextSpan(text: '\njourney today'),
          ],
        ),
        description:
            'Create a free account and discover fresh flowers, potted plants, and arrangements delivered right to your door.',
      ),
      children: [
        if (!sheet) ...[
          SizedBox(height: MediaQuery.sizeOf(context).height < 720 ? 0 : 4),
          const AuthBrandMark(),
          SizedBox(height: MediaQuery.sizeOf(context).height < 720 ? 10 : 24),
          const AuthHeading(
            title: 'Create your account',
            subtitle: 'Join E-FLORA and start sending blooms',
          ),
          SizedBox(height: MediaQuery.sizeOf(context).height < 720 ? 12 : 22),
        ] else ...[
          const AuthHeading(
            title: 'Create your account',
            subtitle: 'Join thousands of flower lovers today.',
          ),
          const SizedBox(height: 16),
        ],
        AuthGlassCard(
          flat: sheet,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthFieldLabel('Full name'),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: fieldStyle,
                  decoration: authInputDecoration(
                    hint: 'Juana Dela Cruz',
                    prefixIcon: Icons.person_outline,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                ),
                const SizedBox(height: 18),
                const AuthFieldLabel('Email or mobile number'),
                TextFormField(
                  controller: _identifierCtrl,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  inputFormatters: const [LowercaseEmailInputFormatter()],
                  style: fieldStyle,
                  decoration: authInputDecoration(
                    hint: 'you@example.com or 09171234567',
                    prefixIcon: Icons.person_outline,
                  ),
                  validator: _validateIdentifier,
                ),
                const SizedBox(height: 18),
                const AuthFieldLabel('Password'),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  style: fieldStyle,
                  decoration: authInputDecoration(
                    hint: '••••••••',
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                        color: AppColors.muted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 18),
                const AuthFieldLabel('Confirm password'),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _sendOtpAndContinue(),
                  style: fieldStyle,
                  decoration: authInputDecoration(
                    hint: '••••••••',
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                        color: AppColors.muted,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please confirm your password';
                    if (v != _passwordCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Container(
                  padding: _agreedTerms
                      ? const EdgeInsets.fromLTRB(8, 8, 10, 8)
                      : EdgeInsets.zero,
                  decoration: _agreedTerms
                      ? BoxDecoration(
                          color: AppColors.sage.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.sage.withValues(alpha: 0.22),
                          ),
                        )
                      : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _agreedTerms,
                          activeColor: AppColors.deepRose,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          onChanged: _onTermsCheckboxChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'I agree to the ',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                height: 1.45,
                                color: AppColors.charcoal,
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                final ok = await _promptCustomerTerms();
                                if (!mounted) return;
                                if (ok) setState(() => _agreedTerms = true);
                              },
                              child: Text(
                                'Customer Terms & Conditions',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  height: 1.45,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.deepRose,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.deepRose,
                                ),
                              ),
                            ),
                            Text(
                              ' (Shipping and Returns policies).',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                height: 1.45,
                                color: AppColors.charcoal,
                              ),
                            ),
                            if (_agreedTerms)
                              Text(
                                ' · Accepted',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.deepSage,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Continue',
                  onPressed: _sendOtpAndContinue,
                  loading: auth.loading,
                  icon: Icons.arrow_forward,
                ),
                const SizedBox(height: 12),
                Text(
                  'Use one contact — email gets a Gmail code, mobile gets an SMS code. That same value is your login.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.muted.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 20),
                const AuthDivider(label: 'already have an account?'),
                const SizedBox(height: 8),
                Center(
                  child: AuthTextLink(
                    label: 'Sign in instead',
                    onTap: () => _goToLogin(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomerTermsDialog extends StatefulWidget {
  const _CustomerTermsDialog({required this.onOpenPolicy});

  final Future<void> Function(String path) onOpenPolicy;

  @override
  State<_CustomerTermsDialog> createState() => _CustomerTermsDialogState();
}

class _CustomerTermsDialogState extends State<_CustomerTermsDialog> {
  final _scroll = ScrollController();
  bool _reachedEnd = false;
  bool _modalAgree = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final pct = max <= 8 ? 1.0 : (_scroll.offset / max).clamp(0.0, 1.0);
    final atEnd = max <= 8 || pct >= 0.92;
    if (pct != _progress || (atEnd && !_reachedEnd)) {
      setState(() {
        _progress = pct;
        if (atEnd) _reachedEnd = true;
      });
    }
  }

  Widget _h(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.charcoal,
        ),
      ),
    );
  }

  Widget _p(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          height: 1.55,
          color: AppColors.muted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAccept = _reachedEnd && _modalAgree;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: const Color(0xFFFFFCF8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFC24E68), Color(0xFFB5445A)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Customer Terms & Conditions',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    children: [
                      _h('1. Customer Agreement'),
                      _p('By creating an E-FLORA customer account, you agree to comply with and be bound by these terms. They follow our public customer policies for shipping and returns. Please read them carefully.'),
                      _h('2. Account Registration'),
                      _p('You must provide accurate information when registering. You are responsible for keeping your login details confidential and for activity on your account.'),
                      _h('3. Shipping & Delivery'),
                      _p('When you order, a nearby partner shop prepares your arrangement and delivers it (or hands it to a rider) within their service area. Delivery fees and windows depend on the shop and your address.'),
                      _p('• Coverage is based on each store’s delivery zone — usually cities and barangays across Laguna.\n• You’ll see whether a shop can deliver to your saved address before checkout.\n• Many shops offer same-day or next-day slots when they’re open and capacity allows.'),
                      _h('4. Delivery Windows & Timing'),
                      _p('Pick an available time slot at checkout when the shop offers them. Same-day availability depends on cut-off times, shop hours, and rider capacity. If a slot isn’t open, choose the next available window.'),
                      _p('Share a clear address, landmark, and working phone number. If nobody can receive the order, the shop or rider may call to arrange a safe handoff or reschedule per the shop’s policy.'),
                      _h('5. Fees & Tracking'),
                      _p('Delivery fees are set by each partner shop and shown before you pay. After checkout, track progress from My Orders. For a late or missing delivery, use order chat or contact support with your order number.'),
                      _h('6. Returns & Refunds'),
                      _p('Because arrangements are made to order and spoil quickly, we generally don’t accept returns of flowers that were delivered as described and in good condition. We do help when there’s a clear delivery or quality problem.'),
                      _h('7. Eligible Issues'),
                      _p('Contact us promptly — ideally within 24 hours of delivery — if the order never arrived, blooms arrived damaged, items are wrong or missing, or the arrangement is substantially different from the listing.'),
                      _h('8. What Usually Isn’t Covered'),
                      _p('Change of mind after preparation or delivery; normal variation in bloom size or shade; incorrect recipient details you provided; flowers left unattended after a successful handoff.'),
                      _h('9. How to Request Help'),
                      _p('Open the order in My Orders and message the shop, or contact E-FLORA support. Share your order number, what went wrong, and clear photos when relevant.'),
                      _h('10. Cancellations'),
                      _p('You can cancel from My Orders while the shop hasn’t started preparing. Once an order is accepted and in preparation, cancellation may no longer be available.'),
                      _h('11. Modifications to Terms'),
                      _p('We may update these terms to match our public Shipping and Returns pages. Continued use of your account after changes constitutes acceptance of the updated terms.'),
                      _h('12. Contact Information'),
                      _p('For questions, contact support at efloralaguna@gmail.com. Full policy pages:'),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => widget.onOpenPolicy('/shipping'),
                            child: const Text('Shipping'),
                          ),
                          TextButton(
                            onPressed: () => widget.onOpenPolicy('/returns'),
                            child: const Text('Returns'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 3,
                      backgroundColor: const Color(0x1A6B4C3B),
                      color: AppColors.deepRose,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xB3FAF6F0),
                border: Border(top: BorderSide(color: Color(0x1FC24E68))),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _modalAgree,
                          onChanged: _reachedEnd
                              ? (v) => setState(() => _modalAgree = v ?? false)
                              : null,
                          activeColor: AppColors.deepRose,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _reachedEnd
                              ? 'I have read and agree to the Customer Terms & Conditions'
                              : 'I have read and agree to the Customer Terms & Conditions (please scroll to the bottom)',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            height: 1.45,
                            color: _reachedEnd
                                ? AppColors.charcoal
                                : AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GradientButton(
                        label: 'Accept Terms',
                        expand: false,
                        height: 42,
                        icon: Icons.check,
                        onPressed: canAccept
                            ? () => Navigator.pop(context, true)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

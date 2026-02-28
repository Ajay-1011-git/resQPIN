import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_theme.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../models/family_link_model.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _codeController = TextEditingController();
  bool _isSending = false;
  bool _isLoading = true;
  String? _error;
  String? _uid;
  UserModel? _currentUser;
  FamilyLinkModel? _familyLink;
  StreamSubscription? _linkSub;

  // Cache resolved user names to avoid repeated Firestore reads
  final Map<String, UserModel?> _resolvedUsers = {};

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _initPage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Not logged in';
        });
      }
      return;
    }
    _uid = user.uid;

    try {
      // Load current user info (for unique code display)
      _currentUser = await _firestoreService.getUser(_uid!);

      // Ensure family_links document exists and load it
      final link = await _firestoreService.getFamilyLink(_uid!);
      if (mounted) {
        setState(() {
          _familyLink = link;
          _isLoading = false;
        });
      }

      // Resolve names for pending + linked users
      await _resolveAllUsers(link);

      // Start background stream for real-time updates
      _startStream();
    } catch (e) {
      debugPrint('Family init error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load family data: $e';
        });
      }
    }
  }

  void _startStream() {
    _linkSub?.cancel();
    _linkSub = _firestoreService
        .streamFamilyLink(_uid!)
        .listen(
          (link) async {
            if (!mounted) return;
            setState(() => _familyLink = link);
            await _resolveAllUsers(link);
          },
          onError: (e) {
            debugPrint('Family stream error: $e');
            // Don't overwrite existing data on stream error
          },
        );
  }

  Future<void> _resolveAllUsers(FamilyLinkModel link) async {
    final allUids = <String>{...link.linkedUsers, ...link.pendingRequests};
    for (final uid in allUids) {
      if (!_resolvedUsers.containsKey(uid)) {
        try {
          _resolvedUsers[uid] = await _firestoreService.getUser(uid);
        } catch (_) {}
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _refreshData() async {
    if (_uid == null) return;
    try {
      final link = await _firestoreService.getFamilyLink(_uid!);
      if (mounted) {
        setState(() {
          _familyLink = link;
          _error = null;
        });
      }
      await _resolveAllUsers(link);
    } catch (e) {
      debugPrint('Refresh error: $e');
    }
  }

  Future<void> _sendRequest() async {
    if (_uid == null) return;
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty || code.length != 6) {
      _showSnackBar('Enter a valid 6-character code', isError: true);
      return;
    }

    setState(() => _isSending = true);
    try {
      final targetUser = await _firestoreService.getUserByCode(code);
      if (targetUser == null) {
        _showSnackBar('No user found with code: $code', isError: true);
        return;
      }
      if (targetUser.uid == _uid) {
        _showSnackBar('You cannot link to yourself', isError: true);
        return;
      }

      // Check if already linked
      if (_familyLink?.linkedUsers.contains(targetUser.uid) == true) {
        _showSnackBar('${targetUser.name} is already linked', isError: true);
        return;
      }

      await _firestoreService.sendFamilyRequest(
        fromUid: _uid!,
        toUid: targetUser.uid,
      );
      _codeController.clear();
      _showSnackBar('Request sent to ${targetUser.name}');
      await _refreshData();
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _acceptRequest(String requesterUid) async {
    if (_uid == null) return;
    try {
      await _firestoreService.acceptFamilyRequest(
        myUid: _uid!,
        requesterUid: requesterUid,
      );
      _showSnackBar('Request accepted!');
      await _refreshData();
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _removeMember(String memberUid, String memberName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.surfaceBorder),
        ),
        title: Text(
          'Remove Family Member',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Remove $memberName from your family list? They will also lose access to your alerts.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Remove',
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || _uid == null) return;

    try {
      await _firestoreService.removeFamilyMember(
        myUid: _uid!,
        memberUid: memberUid,
      );
      _resolvedUsers.remove(memberUid);
      if (mounted) _showSnackBar('$memberName removed');
      await _refreshData();
    } catch (e) {
      if (mounted) _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  String _userName(String uid) {
    return _resolvedUsers[uid]?.name ?? uid.substring(0, 6);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.bgPrimary,
        title: Text(
          'Family Circle',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: Container(
        color: AppTheme.bgPrimary,
        child: SafeArea(
          top: false,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _familyLink == null
              ? _buildErrorView()
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.redAccent.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textDisabled,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _initPage();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.familyColor,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final familyLink =
        _familyLink ??
        FamilyLinkModel(uid: _uid ?? '', linkedUsers: [], pendingRequests: []);

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppTheme.familyColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ─── Your Unique Code ───────────────────────────────
            _buildCodeCard(),
            const SizedBox(height: 20),

            // ─── Link Input ─────────────────────────────────────
            Text(
              'LINK FAMILY MEMBER',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white54,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter their 6-character unique code',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _buildCodeInputRow(),
            const SizedBox(height: 24),

            // ─── Pending Requests ───────────────────────────────
            if (familyLink.pendingRequests.isNotEmpty) ...[
              Text(
                'PENDING REQUESTS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.orangeAccent.withValues(alpha: 0.8),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              ...familyLink.pendingRequests.map(_buildPendingCard),
              const SizedBox(height: 16),
            ],

            // ─── Linked Members ─────────────────────────────────
            Text(
              'LINKED MEMBERS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white54,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            if (familyLink.linkedUsers.isEmpty)
              _buildEmptyState()
            else
              ...familyLink.linkedUsers.map(_buildLinkedMemberCard),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.familyColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.familyColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.share, color: AppTheme.familyColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'YOUR CODE — share with family',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.familyColor.withValues(alpha: 0.8),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentUser?.uniqueCode ?? '------',
                  style: GoogleFonts.robotoMono(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 6,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white54, size: 20),
            tooltip: 'Copy code',
            onPressed: () {
              final code = _currentUser?.uniqueCode;
              if (code != null) {
                Clipboard.setData(ClipboardData(text: code));
                _showSnackBar('Code copied!');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCodeInputRow() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: GoogleFonts.robotoMono(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
            textAlign: TextAlign.center,
            decoration: AppTheme.glassInput(
              label: 'CODE',
              hint: 'RQX291',
              icon: Icons.link,
            ).copyWith(counterText: ''),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isSending ? null : _sendRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.familyColor,
              minimumSize: const Size(0, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'SEND',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingCard(String reqUid) {
    final name = _userName(reqUid);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orangeAccent.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.person_add,
              color: Colors.orangeAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _acceptRequest(reqUid),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.ambulanceColor,
              minimumSize: const Size(0, 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'Accept',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedMemberCard(String linkedUid) {
    final user = _resolvedUsers[linkedUid];
    final name = user?.name ?? linkedUid.substring(0, 6);
    final initial = (user != null && user.name.isNotEmpty)
        ? user.name[0].toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.familyColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.familyColor.withValues(alpha: 0.15),
            ),
            child: Center(
              child: Text(
                initial,
                style: GoogleFonts.inter(
                  color: AppTheme.familyColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (user != null && user.phone.isNotEmpty)
                    Text(
                      user.phone,
                      style: GoogleFonts.inter(
                        color: AppTheme.textDisabled,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.person_remove,
              color: Colors.redAccent,
              size: 20,
            ),
            tooltip: 'Remove member',
            onPressed: () => _removeMember(linkedUid, name),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.family_restroom,
              size: 48,
              color: Colors.white.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 12),
            Text(
              'No linked family members yet.\nAsk family to share their code.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textDisabled,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

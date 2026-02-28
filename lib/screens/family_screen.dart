import 'package:flutter/material.dart';
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
  final uid = FirebaseAuth.instance.currentUser!.uid;
  bool _isSending = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
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
      if (targetUser.uid == uid) {
        _showSnackBar('You cannot link to yourself', isError: true);
        return;
      }

      await _firestoreService.sendFamilyRequest(
        fromUid: uid,
        toUid: targetUser.uid,
      );
      _codeController.clear();
      _showSnackBar('Request sent to ${targetUser.name}');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _acceptRequest(String requesterUid) async {
    try {
      await _firestoreService.acceptFamilyRequest(
        myUid: uid,
        requesterUid: requesterUid,
      );
      _showSnackBar('Request accepted!');
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

    if (confirmed != true) return;

    try {
      await _firestoreService.removeFamilyMember(
        myUid: uid,
        memberUid: memberUid,
      );
      if (mounted) _showSnackBar('$memberName removed');
    } catch (e) {
      if (mounted) _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Family Circle',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: LiquidBackground(
        accentColor: AppTheme.familyColor,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ─── Link Input ──────────────────────────────────
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
                Row(
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
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Pending Requests & Linked Users ──────────────
                Expanded(
                  child: StreamBuilder<FamilyLinkModel?>(
                    stream: _firestoreService.streamFamilyLink(uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final familyLink = snapshot.data;
                      if (familyLink == null) {
                        return Center(
                          child: Text(
                            'No family data',
                            style: GoogleFonts.inter(
                              color: AppTheme.textDisabled,
                            ),
                          ),
                        );
                      }

                      return ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          // Pending requests
                          if (familyLink.pendingRequests.isNotEmpty) ...[
                            Text(
                              'PENDING REQUESTS',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white54,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...familyLink.pendingRequests.map((reqUid) {
                              return FutureBuilder<UserModel?>(
                                future: _firestoreService.getUser(reqUid),
                                builder: (context, snap) {
                                  final name = snap.data?.name ?? reqUid;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceCard.withValues(
                                        alpha: 0.4,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.orangeAccent.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.orangeAccent
                                                .withValues(alpha: 0.15),
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
                                          onPressed: () =>
                                              _acceptRequest(reqUid),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.ambulanceColor,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
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
                                },
                              );
                            }),
                            const SizedBox(height: 16),
                          ],

                          // Linked users
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
                            Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.family_restroom,
                                      size: 48,
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No linked family members yet',
                                      style: GoogleFonts.inter(
                                        color: AppTheme.textDisabled,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ...familyLink.linkedUsers.map((linkedUid) {
                              return FutureBuilder<UserModel?>(
                                future: _firestoreService.getUser(linkedUid),
                                builder: (context, snap) {
                                  final user = snap.data;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceCard.withValues(
                                        alpha: 0.4,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppTheme.surfaceBorder,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Left accent
                                        Container(
                                          width: 4,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            color: AppTheme.familyColor,
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(14),
                                                  bottomLeft: Radius.circular(
                                                    14,
                                                  ),
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppTheme.familyColor
                                                .withValues(alpha: 0.15),
                                          ),
                                          child: Center(
                                            child: Text(
                                              (user?.name.isNotEmpty == true)
                                                  ? user!.name[0].toUpperCase()
                                                  : '?',
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
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  user?.name ?? linkedUid,
                                                  style: GoogleFonts.inter(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                if (user?.phone != null)
                                                  Text(
                                                    user!.phone,
                                                    style: GoogleFonts.inter(
                                                      color:
                                                          AppTheme.textDisabled,
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
                                          onPressed: () => _removeMember(
                                            linkedUid,
                                            user?.name ?? linkedUid,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }),
                        ],
                      );
                    },
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

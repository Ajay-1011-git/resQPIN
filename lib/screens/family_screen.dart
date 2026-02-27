import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Family Member',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Remove $memberName from your family list? They will also lose access to your alerts.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
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
      appBar: AppBar(title: const Text('Family')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Link Input ─────────────────────────────────────────
            Text(
              'Link Family Member',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter their 6-character unique code',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      hintText: 'e.g. RQX291',
                      counterText: '',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _sendRequest,
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('SEND'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ─── Pending Requests & Linked Users ────────────────────
            Expanded(
              child: StreamBuilder<FamilyLinkModel?>(
                stream: _firestoreService.streamFamilyLink(uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final familyLink = snapshot.data;
                  if (familyLink == null) {
                    return const Center(
                      child: Text(
                        'No family data',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView(
                    children: [
                      // Pending requests
                      if (familyLink.pendingRequests.isNotEmpty) ...[
                        Text(
                          'Pending Requests',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        ...familyLink.pendingRequests.map((reqUid) {
                          return FutureBuilder<UserModel?>(
                            future: _firestoreService.getUser(reqUid),
                            builder: (context, snap) {
                              final name = snap.data?.name ?? reqUid;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFF2A2A3C),
                                    child: Icon(
                                      Icons.person_add,
                                      color: Colors.orangeAccent,
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () => _acceptRequest(reqUid),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                    ),
                                    child: const Text('Accept'),
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                        const SizedBox(height: 20),
                      ],

                      // Linked users
                      Text(
                        'Linked Family Members',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      if (familyLink.linkedUsers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Center(
                            child: Text(
                              'No linked family members yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ...familyLink.linkedUsers.map((linkedUid) {
                          return FutureBuilder<UserModel?>(
                            future: _firestoreService.getUser(linkedUid),
                            builder: (context, snap) {
                              final user = snap.data;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFF2A2A3C),
                                    child: Icon(
                                      Icons.family_restroom,
                                      color: Color(0xFF8E24AA),
                                    ),
                                  ),
                                  title: Text(
                                    user?.name ?? linkedUid,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    user?.phone ?? '',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.person_remove,
                                      color: Colors.redAccent,
                                      size: 22,
                                    ),
                                    tooltip: 'Remove member',
                                    onPressed: () => _removeMember(
                                      linkedUid,
                                      user?.name ?? linkedUid,
                                    ),
                                  ),
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
    );
  }
}

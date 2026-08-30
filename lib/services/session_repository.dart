import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/campaign_state.dart';
import '../services/auth_service.dart';

class SessionPlayer {
  final String uid;
  final String displayName;
  final String? characterId;
  final bool ready;
  final DateTime? lastSeen;
  SessionPlayer({required this.uid, required this.displayName, this.characterId, this.ready = false, this.lastSeen});

  factory SessionPlayer.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final j = d.data() ?? {};
    return SessionPlayer(
      uid: d.id,
      displayName: j['displayName'] as String? ?? 'Adventurer',
      characterId: j['characterId'] as String?,
      ready: j['ready'] as bool? ?? false,
      lastSeen: (j['lastSeen'] as Timestamp?)?.toDate(),
    );
  }
}

class SessionInfo {
  final String id;
  final String hostUid;
  final String joinCode;
  final String status; // lobby | active | paused | ended
  SessionInfo({required this.id, required this.hostUid, required this.joinCode, required this.status});

  factory SessionInfo.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final j = d.data() ?? {};
    return SessionInfo(id: d.id, hostUid: j['hostUid'] as String? ?? '', joinCode: j['joinCode'] as String? ?? '', status: j['status'] as String? ?? 'lobby');
  }
}

class SessionNotFoundException implements Exception {
  final String message;
  SessionNotFoundException(this.message);
}

/// Real Firestore-backed multiplayer sessions — see plan/06-multiplayer-firebase-backend.md.
/// Host-authoritative, no Cloud Functions (fits the Spark free plan): the host
/// device runs the actual on-device DM and writes state back for everyone else
/// to read.
class SessionRepository {
  SessionRepository._();
  static final SessionRepository instance = SessionRepository._();

  final _db = FirebaseFirestore.instance;
  Timer? _heartbeat;

  CollectionReference<Map<String, dynamic>> get _sessions => _db.collection('sessions');

  String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I ambiguity
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<SessionInfo> createSession({required Map<String, dynamic> campaignSeedJson, required String displayName, String? characterId}) async {
    final user = await AuthService.instance.ensureSignedIn();
    final code = _genCode();
    final doc = _sessions.doc();
    await doc.set({
      'hostUid': user.uid,
      'joinCode': code,
      'status': 'lobby',
      'createdAt': FieldValue.serverTimestamp(),
      'campaignSeed': campaignSeedJson,
    });
    await doc.collection('players').doc(user.uid).set({
      'displayName': displayName,
      'characterId': characterId,
      'ready': true,
      'lastSeen': FieldValue.serverTimestamp(),
    });
    _startHeartbeat(doc.id, user.uid);
    return SessionInfo(id: doc.id, hostUid: user.uid, joinCode: code, status: 'lobby');
  }

  Future<SessionInfo> joinSessionByCode(String code, {required String displayName, String? characterId}) async {
    final user = await AuthService.instance.ensureSignedIn();
    final query = await _sessions.where('joinCode', isEqualTo: code.toUpperCase()).where('status', isEqualTo: 'lobby').limit(1).get();
    if (query.docs.isEmpty) {
      throw SessionNotFoundException('No open lobby found for code $code. Double-check the code or ask your host for a new one.');
    }
    final doc = query.docs.first;
    await doc.reference.collection('players').doc(user.uid).set({
      'displayName': displayName,
      'characterId': characterId,
      'ready': true,
      'lastSeen': FieldValue.serverTimestamp(),
    });
    _startHeartbeat(doc.id, user.uid);
    return SessionInfo.fromDoc(doc);
  }

  void _startHeartbeat(String sessionId, String uid) {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
      _sessions.doc(sessionId).collection('players').doc(uid).update({'lastSeen': FieldValue.serverTimestamp()}).catchError((_) {});
    });
  }

  void stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  Stream<SessionInfo> watchSession(String sessionId) => _sessions.doc(sessionId).snapshots().map(SessionInfo.fromDoc);

  Stream<List<SessionPlayer>> watchPlayers(String sessionId) =>
      _sessions.doc(sessionId).collection('players').snapshots().map((s) => s.docs.map(SessionPlayer.fromDoc).toList());

  Future<void> startSession(String sessionId) => _sessions.doc(sessionId).update({'status': 'active'});

  Future<void> leaveSession(String sessionId) async {
    stopHeartbeat();
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    await _sessions.doc(sessionId).collection('players').doc(user.uid).delete();
  }

  Future<void> endSession(String sessionId) => _sessions.doc(sessionId).update({'status': 'ended'});

  /// Non-host players call this to propose an action; the host's device
  /// listens via [watchPendingActions], feeds it through the real DM engine,
  /// and writes the result back via [pushState].
  Future<void> submitAction(String sessionId, String actionText) async {
    final user = await AuthService.instance.ensureSignedIn();
    await _sessions.doc(sessionId).collection('actions').add({
      'fromUid': user.uid,
      'actionText': actionText,
      'submittedAt': FieldValue.serverTimestamp(),
      'processed': false,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPendingActions(String sessionId) =>
      _sessions.doc(sessionId).collection('actions').where('processed', isEqualTo: false).orderBy('submittedAt').snapshots();

  Future<void> markActionProcessed(String sessionId, String actionId) =>
      _sessions.doc(sessionId).collection('actions').doc(actionId).update({'processed': true});

  /// Host-only: publish the authoritative campaign state for every client to render.
  Future<void> pushState(String sessionId, CampaignState state) =>
      _sessions.doc(sessionId).collection('state').doc('current').set(state.toJson());

  Stream<Map<String, dynamic>?> watchState(String sessionId) =>
      _sessions.doc(sessionId).collection('state').doc('current').snapshots().map((d) => d.data());
}

class SessionPlayer {
  final String uid;
  final String displayName;
  final String characterId;
  final String connectionStatus;
  final DateTime lastSeen;
  SessionPlayer({required this.uid, required this.displayName, required this.characterId, this.connectionStatus = 'online', DateTime? lastSeen}) : lastSeen = lastSeen ?? DateTime.now();
  Map<String, dynamic> toJson() => {'uid': uid, 'displayName': displayName, 'characterId': characterId, 'connectionStatus': connectionStatus, 'lastSeen': lastSeen.toIso8601String()};
}

class SessionDoc {
  final String sessionId;
  final String hostUid;
  final String joinCode;
  final String status; // lobby, active, paused, ended
  final DateTime createdAt;
  final Map<String, dynamic> campaignSeed;
  final List<SessionPlayer> players;
  SessionDoc({required this.sessionId, required this.hostUid, required this.joinCode, this.status = 'lobby', DateTime? createdAt, this.campaignSeed = const {}, this.players = const []}) : createdAt = createdAt ?? DateTime.now();
}

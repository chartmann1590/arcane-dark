class AbilityScores {
  final int str;
  final int dex;
  final int con;
  final int int_;
  final int wis;
  final int cha;

  const AbilityScores({
    this.str = 10,
    this.dex = 10,
    this.con = 10,
    this.int_ = 10,
    this.wis = 10,
    this.cha = 10,
  });

  static int modifierFor(int score) => (score - 10) ~/ 2;

  int get strMod => modifierFor(str);
  int get dexMod => modifierFor(dex);
  int get conMod => modifierFor(con);
  int get intMod => modifierFor(int_);
  int get wisMod => modifierFor(wis);
  int get chaMod => modifierFor(cha);

  AbilityScores copyWith({int? str, int? dex, int? con, int? int_, int? wis, int? cha}) {
    return AbilityScores(
      str: str ?? this.str,
      dex: dex ?? this.dex,
      con: con ?? this.con,
      int_: int_ ?? this.int_,
      wis: wis ?? this.wis,
      cha: cha ?? this.cha,
    );
  }

  Map<String, dynamic> toJson() => {
        'str': str,
        'dex': dex,
        'con': con,
        'int': int_,
        'wis': wis,
        'cha': cha,
      };

  factory AbilityScores.fromJson(Map<String, dynamic> j) => AbilityScores(
        str: j['str'] as int? ?? 10,
        dex: j['dex'] as int? ?? 10,
        con: j['con'] as int? ?? 10,
        int_: j['int'] as int? ?? 10,
        wis: j['wis'] as int? ?? 10,
        cha: j['cha'] as int? ?? 10,
      );

  int totalCost() {
    const cost = {8: 0, 9: 1, 10: 2, 11: 3, 12: 4, 13: 5, 14: 7, 15: 9};
    int scoreCost(int score) {
      if (score < 8) return 0;
      if (score <= 15) return cost[score] ?? 0;
      return 9 + (score - 15) * 2;
    }
    return scoreCost(str) + scoreCost(dex) + scoreCost(con) + scoreCost(int_) + scoreCost(wis) + scoreCost(cha);
  }
}

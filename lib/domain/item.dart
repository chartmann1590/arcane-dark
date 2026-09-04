/// Items collected during play are just free-text names from the DM
/// ("tarnished silver coin", "healing potion") — there's no structured loot
/// table. This classifies an item by keyword so the inventory UI can decide
/// whether it's equippable, usable, and what a sensible heal amount is,
/// without needing the DM to emit any extra structured data.
enum ItemType { weapon, armor, consumable, misc }

class ItemCatalog {
  static const _weaponWords = ['sword', 'axe', 'bow', 'dagger', 'mace', 'staff', 'hammer', 'blade', 'spear', 'wand', 'crossbow', 'club'];
  static const _armorWords = ['armor', 'armour', 'shield', 'helm', 'cloak', 'ring', 'amulet', 'boots', 'gauntlet', 'plate', 'mail'];
  static const _consumableWords = ['potion', 'elixir', 'draught', 'tonic', 'brew', 'salve'];

  static ItemType classify(String name) {
    final l = name.toLowerCase();
    for (final w in _consumableWords) {
      if (l.contains(w)) return ItemType.consumable;
    }
    for (final w in _weaponWords) {
      if (l.contains(w)) return ItemType.weapon;
    }
    for (final w in _armorWords) {
      if (l.contains(w)) return ItemType.armor;
    }
    return ItemType.misc;
  }

  static bool isEquippable(String name) {
    final t = classify(name);
    return t == ItemType.weapon || t == ItemType.armor;
  }

  static bool isUsable(String name) => classify(name) == ItemType.consumable;

  /// Rough flavor-driven heal amount for a consumable — "greater" potions
  /// heal more, everything else heals a modest fixed amount. Not meant to
  /// be a precise itemization system, just enough to make "Use" mean
  /// something real for HP tracking.
  static int healAmount(String name) {
    final l = name.toLowerCase();
    if (!isUsable(name)) return 0;
    if (l.contains('greater') || l.contains('superior')) return 14;
    if (l.contains('minor') || l.contains('lesser')) return 4;
    return 8;
  }
}

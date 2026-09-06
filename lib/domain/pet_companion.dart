import 'package:flutter/material.dart';

class PetCompanion {
  final String id;
  final String name;
  final String emoji;
  final IconData icon;
  final Color color;
  final String perkTitle;
  final String perkDescription;
  final String flavor;

  const PetCompanion({
    required this.id,
    required this.name,
    required this.emoji,
    required this.icon,
    required this.color,
    required this.perkTitle,
    required this.perkDescription,
    required this.flavor,
  });

  static const all = <PetCompanion>[
    PetCompanion(
      id: 'none',
      name: 'No Companion',
      emoji: '👤',
      icon: Icons.person_outline_rounded,
      color: Colors.grey,
      perkTitle: 'Solo Wanderer',
      perkDescription: 'You travel light without an animal companion.',
      flavor: 'A lone traveler with only their steel to rely on.',
    ),
    PetCompanion(
      id: 'tavern_hound',
      name: 'Tavern Hound',
      emoji: '🐕',
      icon: Icons.pets_rounded,
      color: Color(0xFFFFA726),
      perkTitle: 'Loyal Scent & Guard',
      perkDescription: 'Alerts party before entering dangerous rooms (+2 Perception). Distracts foes in battle.',
      flavor: 'A faithful golden hound who refuses to leave your side and wags at every victory.',
    ),
    PetCompanion(
      id: 'hearth_cat',
      name: 'Hearth Cat',
      emoji: '🐈',
      icon: Icons.cruelty_free_rounded,
      color: Color(0xFFFF7043),
      perkTitle: 'Nine Lives & Nimble Luck',
      perkDescription: 'Grants fortune on saving throws and +1 AC while resting near torchlight.',
      flavor: 'A calico cat that slips through shadows and curls around your boots at campfires.',
    ),
    PetCompanion(
      id: 'shadow_wolf',
      name: 'Shadow Wolf Pup',
      emoji: '🐺',
      icon: Icons.shield_moon_rounded,
      color: Color(0xFF7E57C2),
      perkTitle: 'Pack Hunter Instinct',
      perkDescription: 'Grants flanking advantage and +1 bonus damage on party melee critical strikes.',
      flavor: 'A rescued midnight wolf pup with piercing silver eyes and fearless battle instincts.',
    ),
    PetCompanion(
      id: 'spectral_owl',
      name: 'Spectral Owl',
      emoji: '🦉',
      icon: Icons.visibility_rounded,
      color: Color(0xFF26C6DA),
      perkTitle: 'All-Seeing Night Watch',
      perkDescription: 'Expands fog of war vision radius by +1 tile and reveals hidden secrets on dungeon maps.',
      flavor: 'A mysterious horned owl whose feathers shimmer like starlight in the deepest gloom.',
    ),
    PetCompanion(
      id: 'astral_falcon',
      name: 'Astral Falcon',
      emoji: '🦅',
      icon: Icons.air_rounded,
      color: Color(0xFF42A5F5),
      perkTitle: 'Keen Aerial Strike',
      perkDescription: 'Harasses hostile archers and spellcasters, granting +5% critical hit strike chance.',
      flavor: 'A majestic raptor perched on your leather bracer, scanning the horizon for ambush.',
    ),
    PetCompanion(
      id: 'pygmy_drake',
      name: 'Pygmy Drake',
      emoji: '🐉',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFEF5350),
      perkTitle: 'Ember Spark & Warmth',
      perkDescription: 'Spits embers at hostile foes dealing 2 fire damage and keeps the party warm.',
      flavor: 'A tiny winged dragon that roosts on your shoulder, puffing harmless smoke rings.',
    ),
  ];

  static PetCompanion fromId(String? id) {
    if (id == null || id.isEmpty || id == 'none') {
      return all.first;
    }
    return all.firstWhere(
      (p) => p.id == id,
      orElse: () => all.first,
    );
  }
}

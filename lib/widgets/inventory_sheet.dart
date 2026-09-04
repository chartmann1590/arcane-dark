import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme.dart';
import '../domain/campaign_state.dart';
import '../domain/item.dart';
import '../providers/campaign_provider.dart';
import '../services/audio_service.dart';

IconData _iconFor(ItemType t) => switch (t) {
      ItemType.weapon => Icons.gavel_rounded,
      ItemType.armor => Icons.shield_rounded,
      ItemType.consumable => Icons.local_drink_rounded,
      ItemType.misc => Icons.inventory_2_rounded,
    };

/// HP/AC status plus every collected item for one party member, with real
/// Equip/Unequip/Use actions wired to CampaignNotifier — so "what has this
/// character picked up, and can I actually do something with it" has a real
/// answer instead of items just piling up invisibly in a data model.
void showInventorySheet(BuildContext context, WidgetRef ref, PartyMemberStatus member) {
  showModalBottomSheet(
    context: context,
    backgroundColor: ArcaneTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Consumer(builder: (context, ref, _) {
        // Re-read live so Equip/Use taps reflect immediately without closing the sheet.
        final campaign = ref.watch(campaignProvider);
        final live = campaign?.party.firstWhere(
          (m) => m.characterId == member.characterId,
          orElse: () => member,
        ) ?? member;
        final hpFrac = live.maxHp <= 0 ? 0.0 : (live.hp / live.maxHp).clamp(0.0, 1.0);
        final hpColor = hpFrac > 0.5 ? ArcaneTheme.secondary : (hpFrac > 0.2 ? Colors.orange : Colors.redAccent);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(live.name, style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('${live.raceLabel} • ${live.classLabel}', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('HP', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, color: ArcaneTheme.textSecondary)),
                    const Spacer(),
                    Text('${live.hp} / ${live.maxHp}', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: hpFrac, minHeight: 8, backgroundColor: Colors.white.withOpacity(0.08), valueColor: AlwaysStoppedAnimation(hpColor)),
                  ),
                ]),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('AC', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, color: ArcaneTheme.textSecondary)),
                Text('${live.armorClass}', style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ]),
            if (live.conditions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final c in live.conditions)
                  Chip(label: Text(c, style: GoogleFonts.ibmPlexSans(fontSize: 10, color: Colors.white)), backgroundColor: Colors.redAccent.withOpacity(0.25), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ]),
            ],
            const SizedBox(height: 16),
            Text('INVENTORY', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: ArcaneTheme.textSecondary)),
            const SizedBox(height: 8),
            Expanded(
              child: live.inventory.isEmpty
                  ? Center(child: Text('No items collected yet.', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: ArcaneTheme.textSecondary)))
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: live.inventory.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (c, i) {
                        final item = live.inventory[i];
                        final type = ItemCatalog.classify(item);
                        final equipped = live.equippedItems.contains(item);
                        final equippable = ItemCatalog.isEquippable(item);
                        final usable = ItemCatalog.isUsable(item);
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: ArcaneTheme.cardDecoration().copyWith(
                            border: Border.all(color: equipped ? ArcaneTheme.primary : ArcaneTheme.border),
                          ),
                          child: Row(children: [
                            Icon(_iconFor(type), size: 18, color: equipped ? ArcaneTheme.primary : ArcaneTheme.textSecondary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(item, style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                                if (equipped) Text('Equipped', style: GoogleFonts.ibmPlexSans(fontSize: 10, color: ArcaneTheme.primary, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                            if (equippable)
                              OutlinedButton(
                                onPressed: () {
                                  AudioService.instance.playTap();
                                  if (equipped) {
                                    ref.read(campaignProvider.notifier).unequipItem(live.characterId, item);
                                  } else {
                                    ref.read(campaignProvider.notifier).equipItem(live.characterId, item);
                                  }
                                },
                                child: Text(equipped ? 'Unequip' : 'Equip', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                            if (usable) ...[
                              const SizedBox(width: 6),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: ArcaneTheme.secondary, padding: const EdgeInsets.symmetric(horizontal: 12)),
                                onPressed: () {
                                  AudioService.instance.playSuccess();
                                  ref.read(campaignProvider.notifier).useItem(live.characterId, item);
                                },
                                child: Text('Use', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black)),
                              ),
                            ],
                          ]),
                        );
                      },
                    ),
            ),
          ]),
        );
      }),
    ),
  );
}

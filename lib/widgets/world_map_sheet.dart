import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/campaign_state.dart';
import '../domain/world_location.dart';
import '../services/audio_service.dart';
import '../app/theme.dart';

/// Interactive fantasy World Atlas sheet featuring continent cartography,
/// trade routes, location discovery, fog of war, and instant fast travel.
class WorldMapSheet extends StatefulWidget {
  final CampaignState? campaign;
  final String currentEnvironment;
  final void Function(String realmId, String realmName) onFastTravel;

  const WorldMapSheet({
    super.key,
    required this.campaign,
    required this.currentEnvironment,
    required this.onFastTravel,
  });

  static Future<void> show({
    required BuildContext context,
    required CampaignState? campaign,
    required String currentEnvironment,
    required void Function(String realmId, String realmName) onFastTravel,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0F17),
      isScrollControlled: true,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => WorldMapSheet(
        campaign: campaign,
        currentEnvironment: currentEnvironment,
        onFastTravel: onFastTravel,
      ),
    );
  }

  @override
  State<WorldMapSheet> createState() => _WorldMapSheetState();
}

class _WorldMapSheetState extends State<WorldMapSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _selectedLocationId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedLocationId = widget.currentEnvironment;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Set<String> get _visitedIds {
    final visited = widget.campaign?.visitedRealms ?? <String>{};
    return {
      widget.currentEnvironment,
      ...visited,
    };
  }

  @override
  Widget build(BuildContext context) {
    final visitedIds = _visitedIds;
    final totalRealms = WorldLocationCatalog.locations.length;
    final visitedCount = WorldLocationCatalog.locations.where((l) => visitedIds.contains(l.id)).length;
    final selectedLoc = WorldLocationCatalog.getById(_selectedLocationId) ?? WorldLocationCatalog.locations.first;
    final isSelectedVisited = visitedIds.contains(selectedLoc.id);
    final isSelectedCurrent = selectedLoc.id == widget.currentEnvironment;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF0C0E17),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD54F).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.45)),
                  ),
                  child: const Icon(Icons.public_rounded, color: Color(0xFFFFD54F), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REALM WORLD ATLAS',
                        style: GoogleFonts.cinzel(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'Charted Kingdoms, Wilds & Fast Travel Network',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                // Charted progress badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2338),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ArcaneTheme.secondary.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.travel_explore_rounded, size: 14, color: ArcaneTheme.secondary),
                      const SizedBox(width: 5),
                      Text(
                        '$visitedCount/$totalRealms CHARTED',
                        style: GoogleFonts.cinzel(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: ArcaneTheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Mode Tabs (Atlas Canvas vs Location List)
          Container(
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF141724),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: ArcaneTheme.secondary.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ArcaneTheme.secondary.withValues(alpha: 0.7)),
              ),
              labelColor: ArcaneTheme.secondary,
              unselectedLabelColor: Colors.white54,
              labelStyle: GoogleFonts.cinzel(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
              tabs: const [
                Tab(icon: Icon(Icons.map_rounded, size: 15), text: ' WORLD ATLAS MAP'),
                Tab(icon: Icon(Icons.list_alt_rounded, size: 15), text: ' ALL REALMS & LORE'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Visual World Atlas Canvas with interactive nodes
                _buildAtlasCanvasView(visitedIds, selectedLoc, isSelectedVisited, isSelectedCurrent),

                // TAB 2: Discovered Realms List with Fast Travel buttons
                _buildRealmsListView(visitedIds),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtlasCanvasView(
    Set<String> visitedIds,
    WorldLocation selectedLoc,
    bool isSelectedVisited,
    bool isSelectedCurrent,
  ) {
    return Column(
      children: [
        // World Map Canvas
        Expanded(
          flex: 5,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F121C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5A93C).withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;

                return Stack(
                  children: [
                    // Custom Painter for Cartography Background & Trade Routes
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _WorldMapCartographyPainter(
                          locations: WorldLocationCatalog.locations,
                          routes: WorldLocationCatalog.tradeRoutes,
                          visitedIds: visitedIds,
                          currentEnvironment: widget.currentEnvironment,
                          selectedLocationId: _selectedLocationId,
                        ),
                      ),
                    ),

                    // Interactive Location Node Pins
                    for (final loc in WorldLocationCatalog.locations)
                      _buildLocationPin(loc, w, h, visitedIds),

                    // Top Banner Guide
                    Positioned(
                      top: 8,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0D15).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.touch_app_rounded, size: 12, color: Color(0xFFFFD54F)),
                            const SizedBox(width: 4),
                            Text(
                              'Tap any realm node to inspect or fast travel',
                              style: GoogleFonts.ibmPlexSans(fontSize: 10, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // Selected Realm Details & Fast Travel Drawer Card
        Expanded(
          flex: 4,
          child: _buildLocationInspectorCard(selectedLoc, isSelectedVisited, isSelectedCurrent),
        ),
      ],
    );
  }

  Widget _buildLocationPin(
    WorldLocation loc,
    double canvasWidth,
    double canvasHeight,
    Set<String> visitedIds,
  ) {
    final isVisited = visitedIds.contains(loc.id);
    final isCurrent = loc.id == widget.currentEnvironment;
    final isSelected = loc.id == _selectedLocationId;

    final x = loc.normX * canvasWidth;
    final y = loc.normY * canvasHeight;

    return Positioned(
      left: x - 40,
      top: y - 22,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AudioService.instance.playTap();
          setState(() {
            _selectedLocationId = loc.id;
          });
        },
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pin Container
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Current location pulsating aura ring
                  if (isCurrent)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFD54F), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD54F).withValues(alpha: 0.45),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),

                  // Selected indicator halo
                  if (isSelected && !isCurrent)
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ArcaneTheme.secondary, width: 2),
                      ),
                    ),

                  // Main Pin Circle
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isVisited
                          ? loc.primaryColor.withValues(alpha: 0.90)
                          : const Color(0xFF1E212D),
                      border: Border.all(
                        color: isVisited ? loc.accentColor : Colors.white24,
                        width: isSelected || isCurrent ? 2.0 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isVisited ? loc.icon : Icons.lock_outline_rounded,
                      size: isVisited ? 18 : 16,
                      color: isVisited ? Colors.white : Colors.white38,
                    ),
                  ),

                  // Party Flag badge for current location
                  if (isCurrent)
                    Positioned(
                      top: -2,
                      right: 18,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFD54F),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star_rounded, size: 9, color: Colors.black),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),

              // Pin Label Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0F18).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected
                        ? ArcaneTheme.secondary
                        : (isVisited ? loc.accentColor.withValues(alpha: 0.4) : Colors.white12),
                    width: isSelected ? 1.2 : 0.8,
                  ),
                ),
                child: Text(
                  loc.shortName.toUpperCase(),
                  style: GoogleFonts.cinzel(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: isVisited ? Colors.white : Colors.white38,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationInspectorCard(
    WorldLocation loc,
    bool isVisited,
    bool isCurrent,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVisited ? loc.primaryColor.withValues(alpha: 0.6) : Colors.white12,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon, Titles, Threat Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: loc.primaryColor.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: loc.primaryColor.withValues(alpha: 0.6)),
                ),
                child: Icon(loc.icon, color: loc.accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.name.toUpperCase(),
                      style: GoogleFonts.cinzel(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      loc.regionTitle,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 10,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              // Threat Level Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _threatColor(loc.threatLevel).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _threatColor(loc.threatLevel).withValues(alpha: 0.5)),
                ),
                child: Text(
                  loc.threatLevel.toUpperCase(),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: _threatColor(loc.threatLevel),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Description or Rumor Clue
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVisited ? loc.description : loc.rumorClue,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      color: isVisited ? Colors.white70 : const Color(0xFFFFD54F).withValues(alpha: 0.85),
                      height: 1.35,
                      fontStyle: isVisited ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Landmarks chips
                  if (isVisited) ...[
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: loc.landmarks.map((lm) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2435),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Text(
                            lm,
                            style: GoogleFonts.ibmPlexSans(fontSize: 9.5, color: Colors.white60),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Notable Figures: ${loc.notableNpcs.join(", ")}',
                      style: GoogleFonts.ibmPlexSans(fontSize: 10, color: Colors.white54),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFFFFD54F)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Uncharted realm. Travel to connecting roads or advance campaign beats to discover.',
                            style: GoogleFonts.ibmPlexSans(fontSize: 9.5, color: Colors.white54),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: isCurrent
                ? ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E2333),
                      foregroundColor: Colors.white54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Colors.white24),
                      ),
                    ),
                    onPressed: null,
                    icon: const Icon(Icons.location_on_rounded, color: Color(0xFFFFD54F), size: 16),
                    label: Text(
                      'CURRENT REALM • YOU ARE HERE',
                      style: GoogleFonts.cinzel(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  )
                : isVisited
                    ? ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: loc.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: loc.accentColor.withValues(alpha: 0.8)),
                          ),
                          elevation: 4,
                        ),
                        onPressed: () {
                          AudioService.instance.playTap();
                          Navigator.pop(context);
                          widget.onFastTravel(loc.id, loc.name);
                        },
                        icon: const Icon(Icons.bolt_rounded, color: Color(0xFFFFD54F), size: 18),
                        label: Text(
                          'FAST TRAVEL TO ${loc.name.toUpperCase()}',
                          style: GoogleFonts.cinzel(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        ),
                      )
                    : OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white38,
                          side: const BorderSide(color: Colors.white12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: null,
                        icon: const Icon(Icons.lock_outline_rounded, size: 15),
                        label: Text(
                          'UNCHARTED TERRITORY (FAST TRAVEL LOCKED)',
                          style: GoogleFonts.cinzel(fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealmsListView(Set<String> visitedIds) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: WorldLocationCatalog.locations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final loc = WorldLocationCatalog.locations[index];
        final isVisited = visitedIds.contains(loc.id);
        final isCurrent = loc.id == widget.currentEnvironment;

        return Material(
          color: isCurrent
              ? loc.primaryColor.withValues(alpha: 0.16)
              : const Color(0xFF131722),
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCurrent
                    ? loc.primaryColor
                    : (isVisited ? loc.primaryColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08)),
                width: isCurrent ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isVisited
                            ? loc.primaryColor.withValues(alpha: 0.22)
                            : const Color(0xFF1E212D),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isVisited ? loc.accentColor.withValues(alpha: 0.6) : Colors.white24,
                        ),
                      ),
                      child: Icon(
                        isVisited ? loc.icon : Icons.lock_outline_rounded,
                        color: isVisited ? loc.accentColor : Colors.white38,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                loc.name,
                                style: GoogleFonts.cinzel(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isVisited ? Colors.white : Colors.white54,
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD54F).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFFD54F)),
                                  ),
                                  child: Text(
                                    'HERE',
                                    style: GoogleFonts.cinzel(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFFFFD54F),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            loc.subtitle,
                            style: GoogleFonts.ibmPlexSans(fontSize: 11, color: isVisited ? loc.accentColor : Colors.white38),
                          ),
                        ],
                      ),
                    ),
                    // Fast Travel Action Button
                    if (isVisited && !isCurrent)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: loc.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          AudioService.instance.playTap();
                          Navigator.pop(context);
                          widget.onFastTravel(loc.id, loc.name);
                        },
                        icon: const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFFFD54F)),
                        label: Text(
                          'Fast Travel',
                          style: GoogleFonts.cinzel(fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      )
                    else if (!isVisited)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Uncharted',
                          style: GoogleFonts.cinzel(fontSize: 9.5, color: Colors.white38),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isVisited ? loc.description : loc.rumorClue,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    color: isVisited ? Colors.white70 : const Color(0xFFFFD54F).withValues(alpha: 0.75),
                    fontStyle: isVisited ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
                if (isVisited) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: loc.landmarks.map((lm) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2435),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(lm, style: GoogleFonts.ibmPlexSans(fontSize: 9, color: Colors.white60)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _threatColor(String threat) {
    switch (threat.toLowerCase()) {
      case 'safe haven':
        return const Color(0xFF4DD0E1);
      case 'low':
        return const Color(0xFF81C784);
      case 'moderate':
        return const Color(0xFFFFB74D);
      case 'moderate-high':
      case 'high':
        return const Color(0xFFFF7043);
      case 'extreme':
      case 'deadly':
        return const Color(0xFFE57373);
      default:
        return Colors.white70;
    }
  }
}

/// Custom painter that draws fantasy cartography, coastlines, mountain ridges,
/// forest crowns, and ancient trade routes between world locations.
class _WorldMapCartographyPainter extends CustomPainter {
  final List<WorldLocation> locations;
  final List<WorldTradeRoute> routes;
  final Set<String> visitedIds;
  final String currentEnvironment;
  final String selectedLocationId;

  _WorldMapCartographyPainter({
    required this.locations,
    required this.routes,
    required this.visitedIds,
    required this.currentEnvironment,
    required this.selectedLocationId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Ancient Parchment Sea & Landmass
    final seaPaint = Paint()..color = const Color(0xFF0A0D16);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), seaPaint);

    final landPaint = Paint()
      ..color = const Color(0xFF141926)
      ..style = PaintingStyle.fill;

    // Continent Landmass Polygon
    final continentPath = Path()
      ..moveTo(w * 0.08, h * 0.10)
      ..lineTo(w * 0.90, h * 0.08)
      ..cubicTo(w * 0.95, h * 0.22, w * 0.88, h * 0.45, w * 0.92, h * 0.65)
      ..cubicTo(w * 0.88, h * 0.85, w * 0.70, h * 0.94, w * 0.45, h * 0.92)
      ..cubicTo(w * 0.20, h * 0.90, w * 0.06, h * 0.75, w * 0.05, h * 0.50)
      ..cubicTo(w * 0.04, h * 0.28, w * 0.06, h * 0.18, w * 0.08, h * 0.10)
      ..close();
    canvas.drawPath(continentPath, landPaint);

    // Coastline border stroke
    final coastBorderPaint = Paint()
      ..color = const Color(0xFFE5A93C).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(continentPath, coastBorderPaint);

    // Coastline outer water contour
    final ripplePaint = Paint()
      ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(continentPath, ripplePaint);

    // 2. High Mountain Ridge Hatching (Northern Crags - Valoria)
    final mountainPaint = Paint()
      ..color = const Color(0xFFAB47BC).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    for (double i = -30; i <= 30; i += 12) {
      final peakX = w * 0.50 + i;
      final peakY = h * 0.11;
      final mountainPath = Path()
        ..moveTo(peakX - 18, peakY + 16)
        ..lineTo(peakX, peakY)
        ..lineTo(peakX + 18, peakY + 16);
      canvas.drawPath(mountainPath, mountainPaint);
    }

    // 3. Forest Tree Clusters (Western Wilds - Whispering Woods)
    final forestPaint = Paint()
      ..color = const Color(0xFF4E9A51).withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.20, h * 0.38), 34, forestPaint);
    canvas.drawCircle(Offset(w * 0.16, h * 0.44), 28, forestPaint);

    // 4. Eastern Bay Water Inset (Highgate Harbor)
    final bayPaint = Paint()
      ..color = const Color(0xFF0A0D16)
      ..style = PaintingStyle.fill;
    final bayPath = Path()
      ..moveTo(w * 0.92, h * 0.30)
      ..cubicTo(w * 0.80, h * 0.34, w * 0.82, h * 0.42, w * 0.91, h * 0.45)
      ..close();
    canvas.drawPath(bayPath, bayPaint);

    // 5. Connecting Trade Routes (Highways between realm nodes)
    final locationMap = {for (final l in locations) l.id: l};

    for (final route in routes) {
      final from = locationMap[route.fromId];
      final to = locationMap[route.toId];
      if (from == null || to == null) continue;

      final p1 = Offset(from.normX * w, from.normY * h);
      final p2 = Offset(to.normX * w, to.normY * h);

      final bothVisited = visitedIds.contains(route.fromId) && visitedIds.contains(route.toId);
      final eitherVisited = visitedIds.contains(route.fromId) || visitedIds.contains(route.toId);

      final routePaint = Paint()
        ..color = bothVisited
            ? const Color(0xFFFFD54F).withValues(alpha: 0.65)
            : (eitherVisited ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08))
        ..strokeWidth = bothVisited ? 2.0 : 1.2
        ..style = PaintingStyle.stroke;

      // Draw dashed path
      _drawDashedLine(canvas, p1, p2, routePaint, bothVisited ? 6.0 : 4.0, 4.0);
    }

    // 6. Cartographic Compass Rose in top right
    _drawCompassRose(canvas, Offset(w * 0.86, h * 0.14));

    // 7. Cartographic Region Text Watermarks
    _drawRegionText(canvas, 'VALORIA REALM', Offset(w * 0.50, h * 0.08));
    _drawRegionText(canvas, 'EMERALD WILDS', Offset(w * 0.12, h * 0.30));
    _drawRegionText(canvas, 'HIGHGATE STRAITS', Offset(w * 0.74, h * 0.28));
    _drawRegionText(canvas, 'THE OBSIDIAN RIFT', Offset(w * 0.22, h * 0.72));
    _drawRegionText(canvas, 'ASHEN WASTES', Offset(w * 0.68, h * 0.72));
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, double dashWidth, double dashSpace) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = sqrt(dx * dx + dy * dy);
    final unitVector = Offset(dx / distance, dy / distance);

    double currentDistance = 0.0;
    while (currentDistance < distance) {
      final start = p1 + unitVector * currentDistance;
      final end = p1 + unitVector * min(currentDistance + dashWidth, distance);
      canvas.drawLine(start, end, paint);
      currentDistance += dashWidth + dashSpace;
    }
  }

  void _drawCompassRose(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, 16, paint);

    final needlePaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.55)
      ..strokeWidth = 1.4;

    canvas.drawLine(Offset(center.dx, center.dy - 18), Offset(center.dx, center.dy + 18), needlePaint);
    canvas.drawLine(Offset(center.dx - 18, center.dy), Offset(center.dx + 18, center.dy), needlePaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'N',
        style: GoogleFonts.cinzel(fontSize: 8, color: const Color(0xFFFFD54F).withValues(alpha: 0.7), fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy - 28));
  }

  void _drawRegionText(Canvas canvas, String text, Offset center) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.cinzel(
          fontSize: 8,
          color: Colors.white.withValues(alpha: 0.15),
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _WorldMapCartographyPainter oldDelegate) {
    return oldDelegate.visitedIds.length != visitedIds.length ||
        oldDelegate.currentEnvironment != currentEnvironment ||
        oldDelegate.selectedLocationId != selectedLocationId;
  }
}

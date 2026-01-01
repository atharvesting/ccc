import 'package:flutter/material.dart';
import 'dart:ui'; // For ImageFilter
import '../models.dart';
import '../services/database_service.dart';
import '../widgets.dart'; // For kAppCornerRadius

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  int _selectedIndex = 0;

  bool _isSameDay(DateTime a, DateTime b) => 
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Reusing the shadow style from FeedPage
  List<Shadow> get _titleShadows => [
    const Shadow(
      blurRadius: 30.0,
      color: Colors.redAccent,
      offset: Offset(0, 0),
    ),
    Shadow(
      blurRadius: 30.0,
      color: Colors.red.withValues(alpha: 0.6),
      offset: const Offset(0, 0),
    ),
  ];

  Widget _buildFilterButton(int index, String text) {
    final bool isActive = _selectedIndex == index;
    return TextButton(
      onPressed: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      style: TextButton.styleFrom(
        foregroundColor: isActive ? Colors.redAccent : Colors.white54,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          '< < <',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            shadows: _titleShadows,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Color(0xFF121212), Color(0xFF2C0000)],
                stops: [0.0, 1.0],
              ),
            ),
          ),
          // Content
          Column(
            children: [
              const SizedBox(height: kToolbarHeight + 20),
              const Text(
                "Notice Board",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<List<Event>>(
                  stream: DatabaseService().getEventsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                    }
                    
                    final events = snapshot.data ?? [];
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);

                    // Filter
                    final ongoing = events.where((e) {
                      final eEndLocal = e.endDate.toLocal();
                      final eEnd = DateTime(eEndLocal.year, eEndLocal.month, eEndLocal.day);
                      
                      if (e.startDate != null) {
                        final eStartLocal = e.startDate!.toLocal();
                        final eStart = DateTime(eStartLocal.year, eStartLocal.month, eStartLocal.day);
                        // Start <= Today <= End
                        return !eStart.isAfter(today) && !eEnd.isBefore(today);
                      }
                      // No start date -> One day event. Is it today?
                      return _isSameDay(eEndLocal, today);
                    }).toList();
                    
                    final upcoming = events.where((e) {
                      final start = e.startDate ?? e.endDate;
                      final startLocal = start.toLocal();
                      final checkDate = DateTime(startLocal.year, startLocal.month, startLocal.day);
                      return checkDate.isAfter(today);
                    }).toList();

                    final recent = events.where((e) {
                      final eEndLocal = e.endDate.toLocal();
                      final eEnd = DateTime(eEndLocal.year, eEndLocal.month, eEndLocal.day);
                      return eEnd.isBefore(today);
                    }).toList();

                    // Sort
                    ongoing.sort((a, b) => (b.startDate ?? b.endDate).compareTo(a.startDate ?? a.endDate));
                    upcoming.sort((a, b) => (a.startDate ?? a.endDate).compareTo(b.startDate ?? b.endDate));
                    recent.sort((a, b) => b.endDate.compareTo(a.endDate));

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 900) {
                          // Desktop: 3 columns
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 60.0),
                            child: Row(
                              children: [
                                Expanded(child: _buildColumn("Ongoing", ongoing, Colors.white)),
                                const SizedBox(width: 20),
                                Expanded(child: _buildColumn("Upcoming", upcoming, Colors.white)),
                                const SizedBox(width: 20),
                                Expanded(child: _buildColumn("Recent", recent, Colors.white)),
                              ],
                            ),
                          );
                        } else {
                          // Mobile: Switcher + Single Column
                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildFilterButton(0, "Ongoing"),
                                  _buildFilterButton(1, "Upcoming"),
                                  _buildFilterButton(2, "Recent"),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: KeyedSubtree(
                                    key: ValueKey<int>(_selectedIndex),
                                    child: _selectedIndex == 0 
                                      ? _buildColumn("Ongoing", ongoing, Colors.white, showTitle: false)
                                      : _selectedIndex == 1
                                        ? _buildColumn("Upcoming", upcoming, Colors.white, showTitle: false)
                                        : _buildColumn("Recent", recent, Colors.white, showTitle: false),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColumn(String title, List<Event> events, Color color, {bool showTitle = true}) {
    return Column(
      children: [
        if (showTitle)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ),
        Expanded(
          child: events.isEmpty 
            ? Center(child: Text("No $title events", style: const TextStyle(color: Colors.white30)))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: events.length,
                separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) => _EventListItem(event: events[index], accentColor: color),
              ),
        ),
      ],
    );
  }
}

class _EventListItem extends StatelessWidget {
  final Event event;
  final Color accentColor;

  const _EventListItem({required this.event, required this.accentColor});

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${months[localDate.month - 1]} ${localDate.day}";
  }

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _EventDetailsDialog(event: event, accentColor: accentColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    String dateString;
    if (event.startDate != null) {
      dateString = "${_formatDate(event.startDate!)}\n↓\n${_formatDate(event.endDate)}";
    } else {
      dateString = _formatDate(event.endDate);
    }

    // Truncate description to ~9 words
    final words = event.description.split(' ');
    final truncatedDesc = words.length > 10 
        ? "${words.take(10).join(' ')}..." 
        : event.description;

    return InkWell(
      onTap: () => _showDetails(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Column
            SizedBox(
              width: 60,
              child: Text(
                dateString,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white54, fontSize: 12, height: 1.4),
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(truncatedDesc, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 12, color: accentColor),
                      const SizedBox(width: 4),
                      Expanded(child: Text(event.venue, style: TextStyle(fontSize: 12, color: accentColor), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventDetailsDialog extends StatelessWidget {
  final Event event;
  final Color accentColor;

  const _EventDetailsDialog({required this.event, required this.accentColor});

  String _formatFullDate(DateTime date) {
    final localDate = date.toLocal();
    // e.g. Mon, Jan 12
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${weekdays[localDate.weekday - 1]}, ${months[localDate.month - 1]} ${localDate.day}";
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: GlassyContainer(
            padding: 24.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Date and Venue Row (No Box, Small Font)
                Row(
                  children: [
                    // Date
                    Icon(Icons.calendar_today, size: 14, color: accentColor),
                    const SizedBox(width: 6),
                    Text(
                      event.startDate != null 
                        ? "${_formatFullDate(event.startDate!)} - ${_formatFullDate(event.endDate)}"
                        : _formatFullDate(event.endDate),
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Venue
                    Icon(Icons.location_on, size: 14, color: accentColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        event.venue, 
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Scrollable Content
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Description
                        Text(
                          event.description,
                          style: const TextStyle(color: Colors.white, height: 1.5, fontSize: 15),
                        ),
                        
                        // Links
                        if (event.links.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text("Links", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: event.links.map((link) => ActionChip(
                              label: Text(link.label),
                              avatar: const Icon(Icons.link, size: 14),
                              backgroundColor: accentColor.withValues(alpha: 0.15),
                              side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
                              labelStyle: TextStyle(color: accentColor, fontSize: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Opening ${link.url}")));
                              },
                            )).toList(),
                          ),
                        ],

                        // Contacts
                        if (event.contacts.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text("Contacts", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          ...event.contacts.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              children: [
                                Text("${c.label}: ", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                                Expanded(child: Text(c.info, style: const TextStyle(color: Colors.white, fontSize: 14))),
                              ],
                            ),
                          )),
                        ],
                      ],
                    ),
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

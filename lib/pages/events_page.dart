import 'package:flutter/material.dart';
import 'dart:ui'; // For ImageFilter
import '../models.dart';
import '../services/database_service.dart';
import '../widgets.dart'; // For kAppCornerRadius
import '../data.dart'; // For currentUser

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  int _selectedIndex = 0;

  bool _isSameDay(DateTime a, DateTime b) => 
      a.year == b.year && a.month == b.month && a.day == b.day;

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
    return GlobalScaffold(
      selectedIndex: 2,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const CreateEventDialog(),
          );
        },
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add, color: Colors.white),
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
                "Event Board",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
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
            ? Center(child: Text("No $title events", style: const TextStyle(color: Colors.white38)))
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
                      const Icon(Icons.location_on, size: 12, color: Colors.blue),
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

class _EventDetailsDialog extends StatefulWidget {
  final Event event;
  final Color accentColor;

  const _EventDetailsDialog({required this.event, required this.accentColor});

  @override
  State<_EventDetailsDialog> createState() => _EventDetailsDialogState();
}

class _EventDetailsDialogState extends State<_EventDetailsDialog> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final isAdmin = await DatabaseService().isAdmin(currentUser.id);
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
        title: const Text("Delete Event?", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to delete this event?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService().deleteEvent(widget.event.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event Deleted")));
      }
    }
  }

  void _editEvent() {
    Navigator.pop(context); // Close details dialog
    showDialog(
      context: context,
      builder: (context) => CreateEventDialog(eventToEdit: widget.event),
    );
  }

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
                        widget.event.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_isAdmin) ...[
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: _editEvent,
                        tooltip: "Edit Event",
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: _deleteEvent,
                        tooltip: "Delete Event",
                      ),
                    ],
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
                    Icon(Icons.calendar_today, size: 14, color: widget.accentColor),
                    const SizedBox(width: 6),
                    Text(
                      widget.event.startDate != null 
                        ? "${_formatFullDate(widget.event.startDate!)} - ${_formatFullDate(widget.event.endDate)}"
                        : _formatFullDate(widget.event.endDate),
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Venue
                    Icon(Icons.location_on, size: 14, color: widget.accentColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.event.venue, 
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
                          widget.event.description,
                          style: const TextStyle(color: Colors.white, height: 1.5, fontSize: 15),
                        ),
                        
                        // Links
                        if (widget.event.links.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text("Links", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.event.links.map((link) => ActionChip(
                              label: Text(link.label),
                              avatar: const Icon(Icons.link, size: 14),
                              backgroundColor: widget.accentColor.withValues(alpha: 0.15),
                              side: BorderSide(color: widget.accentColor.withValues(alpha: 0.4)),
                              labelStyle: TextStyle(color: widget.accentColor, fontSize: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Opening ${link.url}")));
                              },
                            )).toList(),
                          ),
                        ],

                        // Contacts
                        if (widget.event.contacts.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text("Contacts", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          ...widget.event.contacts.map((c) => Padding(
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

class CreateEventDialog extends StatefulWidget {
  final Event? eventToEdit; // Added parameter for editing
  const CreateEventDialog({super.key, this.eventToEdit});

  @override
  State<CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<CreateEventDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _venueController;
  
  // Contacts
  final _contactLabelController = TextEditingController();
  final _contactInfoController = TextEditingController();
  late List<EventContact> _contacts;

  // Links
  final _linkLabelController = TextEditingController();
  final _linkUrlController = TextEditingController();
  late List<EventLink> _links;

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.eventToEdit;
    _titleController = TextEditingController(text: e?.title ?? '');
    _descController = TextEditingController(text: e?.description ?? '');
    _venueController = TextEditingController(text: e?.venue ?? '');
    _contacts = e != null ? List.from(e.contacts) : [];
    _links = e != null ? List.from(e.links) : [];
    _startDate = e?.startDate;
    _endDate = e?.endDate;
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.redAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _addContact() {
    if (_contactLabelController.text.trim().isNotEmpty && _contactInfoController.text.trim().isNotEmpty) {
      setState(() {
        _contacts.add(EventContact(
          label: _contactLabelController.text.trim(),
          info: _contactInfoController.text.trim()
        ));
        _contactLabelController.clear();
        _contactInfoController.clear();
      });
    }
  }

  void _addLink() {
    if (_linkLabelController.text.trim().isNotEmpty && _linkUrlController.text.trim().isNotEmpty) {
      setState(() {
        _links.add(EventLink(label: _linkLabelController.text.trim(), url: _linkUrlController.text.trim()));
        _linkLabelController.clear();
        _linkUrlController.clear();
      });
    }
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty || _descController.text.isEmpty || _venueController.text.isEmpty || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all mandatory fields (Title, Desc, Venue, End Date)")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Check if user is admin
      final isAdmin = await DatabaseService().isAdmin(currentUser.id);
      final isEditing = widget.eventToEdit != null;

      // Determine creator info
      String userId;
      String userFullName;
      String username;

      if (isEditing) {
        // Preserve existing creator info
        userId = widget.eventToEdit!.userId;
        userFullName = widget.eventToEdit!.userFullName;
        username = widget.eventToEdit!.username;
      } else {
        // New event: Use current user info
        userId = currentUser.id;
        userFullName = currentUser.fullName;
        username = currentUser.username;
      }

      final event = Event(
        id: widget.eventToEdit?.id ?? '', 
        userId: userId,
        userFullName: userFullName,
        username: username,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        venue: _venueController.text.trim(),
        contacts: _contacts,
        links: _links,
        startDate: _startDate,
        endDate: _endDate!,
        isApproved: isEditing ? widget.eventToEdit!.isApproved : isAdmin, // Keep approval status if editing, else auto-approve if admin
      );

      if (isEditing) {
        await DatabaseService().updateEvent(event);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event Updated Successfully")));
        }
      } else {
        await DatabaseService().createEvent(event);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isAdmin ? "Event Created Successfully" : "Event Request Sent to Admin"))
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
      title: Text(widget.eventToEdit != null ? "Edit Event" : "Create New Event", style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(_titleController, "Title *"),
              const SizedBox(height: 12),
              _buildTextField(_descController, "Description *", maxLines: 3),
              const SizedBox(height: 12),
              _buildTextField(_venueController, "Venue *"),
              const SizedBox(height: 16),
              
              // Dates
              Row(
                children: [
                  Expanded(
                    child: _buildDateSelector("Start Date (Opt)", _startDate, () => _selectDate(true)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateSelector("End Date *", _endDate, () => _selectDate(false)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Contacts
              const Text("Contacts", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(flex: 1, child: _buildTextField(_contactLabelController, "Label (e.g. Role)")),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _buildTextField(_contactInfoController, "Info (e.g. Name - Phone)")),
                  IconButton(icon: const Icon(Icons.add_circle, color: Colors.greenAccent), onPressed: _addContact),
                ],
              ),
              Wrap(
                spacing: 8,
                children: _contacts.map((c) => Chip(
                  label: Text("${c.label}: ${c.info}"),
                  backgroundColor: Colors.white10,
                  deleteIcon: const Icon(Icons.close, size: 12),
                  onDeleted: () => setState(() => _contacts.remove(c)),
                )).toList(),
              ),
              const SizedBox(height: 16),

              // Links
              const Text("Links", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(flex: 1, child: _buildTextField(_linkLabelController, "Label")),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _buildTextField(_linkUrlController, "URL")),
                  IconButton(icon: const Icon(Icons.add_circle, color: Colors.greenAccent), onPressed: _addLink),
                ],
              ),
              Wrap(
                spacing: 8,
                children: _links.map((l) => Chip(
                  label: Text(l.label),
                  backgroundColor: Colors.white10,
                  deleteIcon: const Icon(Icons.close, size: 12),
                  onDeleted: () => setState(() => _links.remove(l)),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
          child: _isSubmitting 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
            : Text(widget.eventToEdit != null ? "Save Changes" : "Submit"),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        isDense: true,
      ),
    );
  }

  Widget _buildDateSelector(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kAppCornerRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white30),
          borderRadius: BorderRadius.circular(kAppCornerRadius),
          color: Colors.black.withValues(alpha: 0.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              date == null ? label : "${date.day}/${date.month}/${date.year}",
              style: TextStyle(color: date == null ? Colors.grey : Colors.white),
            ),
            const Icon(Icons.calendar_today, size: 16, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

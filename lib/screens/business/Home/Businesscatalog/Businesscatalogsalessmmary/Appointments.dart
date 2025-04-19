import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for potential fallback
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' hide Border; // Added Excel export

// --- Added Firebase Auth instance ---
final FirebaseAuth _auth = FirebaseAuth.instance;
// ---

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

enum DateRangeType { day, week, month, year }

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late Box appBox; // Use the main app box
  List<Map<String, dynamic>> _allAppointments = []; // Holds all fetched appointments
  List<Map<String, dynamic>> _appointmentsList = []; // Holds currently displayed/filtered list
  String _dateRangeText = ''; // Text displayed in the date picker button
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now(); // Used for date picker initial value
  final GlobalKey _exportButtonKey = GlobalKey();
  final GlobalKey _dateButtonKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<QuerySnapshot>? _appointmentsSubscription;
  DateRangeType _currentRangeType = DateRangeType.month; //
  String? _businessId; // Added to store business ID

  @override
  void initState() {
    super.initState();
    _initializeAppointmentsPage();
  }

  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeAppointmentsPage() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (!Hive.isBoxOpen('appBox')) {
        appBox = await Hive.openBox('appBox');
      } else {
        appBox = Hive.box('appBox');
      }

      // --- Get Business ID ---
      final businessDataMap = appBox.get('businessData');
      if (businessDataMap != null && businessDataMap is Map) {
        final businessData = Map<String, dynamic>.from(businessDataMap);
        _businessId = businessData['userId']?.toString() ??
                        businessData['documentId']?.toString() ??
                        businessData['id']?.toString();
      }
      if (_businessId == null || _businessId!.isEmpty) {
        User? currentUser = _auth.currentUser;
        _businessId = currentUser?.uid;
      }

      if (_businessId == null || _businessId!.isEmpty) {
        throw Exception("Business ID not found. Cannot load appointments.");
      }
      print("AppointmentsScreen: Initializing for Business ID: $_businessId");
      // --- End Get Business ID ---

      // Load cached data (full list)
      final cacheKey = 'businessAppointments_$_businessId';
      final hiveCachedData = appBox.get(cacheKey);
      if (hiveCachedData != null && hiveCachedData is List && mounted) {
         _allAppointments = List<Map<String, dynamic>>.from(hiveCachedData.map((item) => Map<String, dynamic>.from(item)));
         _filterAndDisplayAppointments(); // Apply initial filter (e.g., today's date)
         print("AppointmentsScreen: Loaded ${_allAppointments.length} appointments from Hive cache for $cacheKey.");
         setState(() {
            _isLoading = false; // Show cached data immediately
         });
      }

      if (mounted) {
        _dateRangeText = DateFormat('d MMM yy').format(DateTime.now()); // Default display to today
      }
      _startFirestoreListener(); // Start listening for real-time updates (will fetch all initially)

    } catch (e) {
      print('Error initializing appointments page: $e');
       _handleInitializationError(e.toString());
    }
    // isLoading state managed by listener or error handler
  }

  void _handleInitializationError(String errorMsg) {
     if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing: $errorMsg')),
        );
       setState(() {
         _isLoading = false;
         _appointmentsList = [];
         _allAppointments = [];
       });
     }
   }

 // --- MODIFIED Firestore Listener to Fetch ALL initially ---
void _startFirestoreListener() {
  _appointmentsSubscription?.cancel();

  if (_businessId == null) {
    _handleInitializationError("Business ID missing for listener");
    return;
  }

  print("AppointmentsScreen: Setting up Firestore listener for ALL appointments at businesses/$_businessId/appointments");

  // Simplified query that doesn't require composite index
  Query query = FirebaseFirestore.instance
    .collection('businesses')
    .doc(_businessId)
    .collection('appointments')
     .orderBy('updatedAt', descending: true); // Only use one field for ordering

  _appointmentsSubscription = query.snapshots().listen(
    (snapshot) async {
      print("AppointmentsScreen: Firestore listener received ${snapshot.docs.length} total docs.");
      if (!mounted) return;

      final List<Map<String, dynamic>> fetchedAppointments = [];
      for (var doc in snapshot.docs) {
         Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
         data['id'] = doc.id;
         fetchedAppointments.add(data);
      }

      // Update the master list
      _allAppointments = fetchedAppointments;

      // Update Hive cache with the full list
      final cacheKey = 'businessAppointments_$_businessId';
      // final serializableAppointments = _allAppointments.map(_convertTimestamps).toList();
      // await appBox.put(cacheKey, serializableAppointments);
      await appBox.put(cacheKey, _allAppointments); // Assuming TimestampAdapter works
      print("AppointmentsScreen: Updated Hive cache $cacheKey with ${_allAppointments.length} total appointments.");

      // Apply current filters (date range and search) to the full list
      _filterAndDisplayAppointments();

      // Ensure loading indicator is off
      if (_isLoading) {
        setState(() => _isLoading = false);
      }
    },
    onError: (error) {
      print('Error in Firestore listener: $error');
      
      // Try to fallback to a simpler query if we get an index error
      if (error.toString().contains("requires an index")) {
        print("Index error detected, retrying with simpler query...");
        _retryWithSimpleQuery();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing data: $error')),
        );
        setState(() => _isLoading = false);
      }
    },
  );
}

// Helper method to retry with a simpler query if index error occurs
void _retryWithSimpleQuery() {
  _appointmentsSubscription?.cancel();
  
  // Extremely simple query with no ordering
  Query query = FirebaseFirestore.instance
    .collection('businesses')
    .doc(_businessId)
    .collection('appointments');
  
  _appointmentsSubscription = query.snapshots().listen(
    (snapshot) async {
      print("AppointmentsScreen: Fallback query received ${snapshot.docs.length} total docs.");
      if (!mounted) return;

      final List<Map<String, dynamic>> fetchedAppointments = [];
      for (var doc in snapshot.docs) {
         Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
         data['id'] = doc.id;
         fetchedAppointments.add(data);
      }

      // Update the master list
      _allAppointments = fetchedAppointments;
      
      // Sort manually by updatedAt instead of appointmentDate
      _allAppointments.sort((a, b) {
        dynamic updatedAtA = a['updatedAt'];
        dynamic updatedAtB = b['updatedAt'];
        
        // Handle timestamps appropriately
        if (updatedAtA is Timestamp && updatedAtB is Timestamp) {
          return updatedAtB.compareTo(updatedAtA); // Descending order
        }
        
        // Handle serverTimestamp fields that might be different types
        try {
          // Try to convert to DateTime if possible
          DateTime? dateA = _getDateTimeFromField(updatedAtA);
          DateTime? dateB = _getDateTimeFromField(updatedAtB);
          
          if (dateA != null && dateB != null) {
            return dateB.compareTo(dateA); // Descending
          }
        } catch (e) {
          print("Error comparing dates: $e");
        }
        
        // Fallback to string comparison for non-timestamp values
        String dateStrA = updatedAtA?.toString() ?? '';
        String dateStrB = updatedAtB?.toString() ?? '';
        return dateStrB.compareTo(dateStrA); // Descending order
      });

      // Update cache and UI
      final cacheKey = 'businessAppointments_$_businessId';
      await appBox.put(cacheKey, _allAppointments);
      _filterAndDisplayAppointments();
      
      if (_isLoading && mounted) {
        setState(() => _isLoading = false);
      }
    },
    onError: (error) {
      print('Error in fallback query: $error');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    },
  );
}

// Helper method to convert various date field types to DateTime
DateTime? _getDateTimeFromField(dynamic field) {
  if (field == null) return null;
  
  if (field is Timestamp) {
    return field.toDate();
  } else if (field is DateTime) {
    return field;
  } else if (field is String) {
    try {
      return DateTime.parse(field);
    } catch (e) {
      // Not a valid date string
      return null;
    }
  } else if (field is Map && field.containsKey('_seconds')) {
    // Handle Firestore serialized timestamps
    try {
      int seconds = field['_seconds'];
      int nanoseconds = field['_nanoseconds'] ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000 + (nanoseconds / 1000000).round()
      );
    } catch (e) {
      return null;
    }
  }
  
  return null;
}
  // --- End MODIFIED Firestore Listener ---

  // --- NEW: Filter and Display Logic ---
void _filterAndDisplayAppointments() {
  if (!mounted) return;

  final String currentSearchQuery = _searchController.text.toLowerCase();
  
  // Use the tracked range type instead of inferring it from text
  DateTime filterStartDate;
  DateTime filterEndDate;
  
  // For debugging - set to true to see all appointments regardless of date
  bool showAllDates = false;

  // Determine date range for filtering
  switch (_currentRangeType) {
    case DateRangeType.day:
      filterStartDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      filterEndDate = DateTime(filterStartDate.year, filterStartDate.month, filterStartDate.day, 23, 59, 59, 999);
      break;
    case DateRangeType.week:
      int daysToSubtract = _selectedDate.weekday - 1;
      filterStartDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day - daysToSubtract);
      filterEndDate = DateTime(filterStartDate.year, filterStartDate.month, filterStartDate.day + 6, 23, 59, 59, 999);
      break;
    case DateRangeType.month:
      filterStartDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
      filterEndDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59, 999);
      break;
    case DateRangeType.year:
      filterStartDate = DateTime(_selectedDate.year, 1, 1);
      filterEndDate = DateTime(_selectedDate.year, 12, 31, 23, 59, 59, 999);
      break;
  }
  
  print("AppointmentsScreen: Filtering displayed list for range: $filterStartDate to $filterEndDate and search: '$currentSearchQuery' (View: ${_currentRangeType.toString()})");

  // Filter the master list (_allAppointments)
  final filteredList = _allAppointments.where((appointment) {
    // Debug the appointment data
    print("Filtering appointment: ${appointment['id']} - Date fields: appointmentDate=${appointment['appointmentDate']}, timestamp=${appointment['appointmentTimestamp']}");
    
    // Skip date filtering if showAllDates is true
    if (showAllDates) {
      print("DEBUG: Date filtering disabled, showing all appointments");
      // Skip to search filtering
    } else {
      // Date Filter
      bool dateMatch = false;
      
      // Try multiple date fields in order of preference
      dynamic dateField = appointment['appointmentTimestamp'];  // Try timestamp first
      if (dateField == null) {
        // If no timestamp, try date string with time string
        String? dateStr = appointment['appointmentDate'];
        String? timeStr = appointment['appointmentTime'];
        
        if (dateStr != null && timeStr != null) {
          try {
            // Attempt to construct a DateTime from separate date and time fields
            String normalizedTimeStr = timeStr;
            // Handle AM/PM format
            if (timeStr.toLowerCase().contains('am') || timeStr.toLowerCase().contains('pm')) {
              List<String> parts = timeStr.toLowerCase().split(' ');
              if (parts.length > 1) {
                String timePart = parts[0];
                bool isPM = parts[1].contains('pm');
                
                List<String> hourMin = timePart.split(':');
                if (hourMin.length > 1) {
                  int hour = int.tryParse(hourMin[0]) ?? 0;
                  if (isPM && hour < 12) hour += 12;
                  if (!isPM && hour == 12) hour = 0;
                  
                  normalizedTimeStr = "${hour.toString().padLeft(2, '0')}:${hourMin[1]}";
                }
              }
            }
            
            // Try to parse with different formats
            DateTime dt;
            try {
              // Try standard ISO format first
              dt = DateTime.parse("$dateStr $normalizedTimeStr");
            } catch (e) {
              // Try with DateFormat
              dt = DateFormat('yyyy-MM-dd HH:mm').parse("$dateStr $normalizedTimeStr");
            }
            
            dateMatch = !dt.isBefore(filterStartDate) && 
                      dt.isBefore(filterEndDate.add(const Duration(microseconds: 1)));
            
            print("Date match using combined date+time: $dateMatch for $dt");
            if (dateMatch) return true;  // Match found with combined fields
          } catch (e) {
            print("Error parsing combined date+time: $e");
            // Continue to try other methods
          }
        }
        
        // If combined approach failed, fall back to just using appointmentDate
        dateField = dateStr;
      }
      
      if (dateField != null) {
        try {
          DateTime apptDate;
          if (dateField is Timestamp) {
            apptDate = dateField.toDate();
          } else if (dateField is DateTime) {
            apptDate = dateField;
          } else if (dateField is String) {
            // Try multiple formats
            try {
              // Try standard ISO format first
              apptDate = DateTime.parse(dateField);
            } catch (e1) {
              try {
                // Try yyyy-MM-dd format
                apptDate = DateFormat('yyyy-MM-dd').parse(dateField);
              } catch (e2) {
                try {
                  // Try dd/MM/yyyy format
                  apptDate = DateFormat('dd/MM/yyyy').parse(dateField);
                } catch (e3) {
                  print("All date parsing attempts failed for: $dateField");
                  return false;  // No valid date found
                }
              }
            }
          } else {
            print("Unknown date field type: ${dateField.runtimeType}");
            return false;
          }
          
          // Compare dates ignoring time for start, include whole day for end
          dateMatch = !apptDate.isBefore(filterStartDate) && 
                    apptDate.isBefore(filterEndDate.add(const Duration(microseconds: 1)));
          
          print("Date match: $dateMatch for ${apptDate.toString()}");
        } catch (e) {
          print("Error parsing date during filter: $e for value $dateField");
          dateMatch = false;  // Treat parse errors as non-match
        }
      }

      if (!dateMatch) return false;  // Exit early if date doesn't match
    }

    // Search Filter
    if (currentSearchQuery.isNotEmpty) {
      // Check id/reference number
      final ref = (appointment['id'] ?? '').toLowerCase();
      
      // Check customer name
      final clientName = (appointment['customerName'] ?? '').toLowerCase();
      
      // Check services - handle different possible data structures
      List<String> serviceNames = [];
      final services = appointment['services'];
      if (services is List) {
        for (var service in services) {
          if (service is Map) {
            String? name = service['name']?.toString();
            if (name != null && name.isNotEmpty) {
              serviceNames.add(name);
            }
          } else if (service is String) {
            serviceNames.add(service);
          }
        }
      }
      final servicesString = serviceNames.join(', ').toLowerCase();

      bool searchMatch = ref.contains(currentSearchQuery) ||
                        clientName.contains(currentSearchQuery) ||
                        servicesString.contains(currentSearchQuery);
      
      return searchMatch;  // Return result of search match
    }

    return true;  // Return true if date matched and no search query
  }).toList();

  print("AppointmentsScreen: Displaying ${filteredList.length} appointments after filtering.");

  // Auto-adjust to month view if day view shows no results but appointments exist
  if (filteredList.isEmpty && _allAppointments.isNotEmpty && _currentRangeType == DateRangeType.day && !showAllDates) {
    print("No appointments for current day. Automatically switching to month view...");
    
    // Change to month view mode
    setState(() {
      _currentRangeType = DateRangeType.month;
      _dateRangeText = _getMonthDates(_selectedDate);
    });
    
    // Wait for setState to complete, then re-run the filter
    Future.delayed(Duration.zero, () {
      if (mounted) _filterAndDisplayAppointments();
    });
    return;  // Exit early
  }

  setState(() {
    _appointmentsList = filteredList;  // Update the list used by the UI
  });
}

  // --- End NEW Filter Logic ---


  // --- REMOVED _loadAppointmentsData ---
  // The filtering logic is now handled by _filterAndDisplayAppointments based on
  // the _allAppointments list updated by the listener.
  // Date picker actions will now just update _selectedDate and _dateRangeText,
  // then call _filterAndDisplayAppointments.

  // --- Date Formatting and Picker Logic ---
  DateRangeType _getDateRangeTypeFromText(String text) {
     if (text.contains(" - ")) {
         // Check if it's a full year range
         if (RegExp(r'^\d{1,2}\s\w{3}\s\d{2}\s-\s\d{1,2}\s\w{3}\s\d{2}$').hasMatch(text)) {
            try {
               final dates = text.split(' - ');
               final start = DateFormat('d MMM yy').parseStrict(dates[0]);
               final end = DateFormat('d MMM yy').parseStrict(dates[1]);
               final durationDays = end.difference(start).inDays;
               if (durationDays > 360) return DateRangeType.year;
               if (durationDays > 25 && durationDays < 35) return DateRangeType.month;
               if (durationDays == 6) return DateRangeType.week;
            } catch (_) { /* Fallback */ }
            return DateRangeType.month; // Default range guess
         }
     }
     // Check for single day format
     if (RegExp(r'^\d{1,2}\s\w{3}\s\d{2}$').hasMatch(text)) {
         return DateRangeType.day;
     }
     return DateRangeType.day; // Default fallback
  }

  String _getYearDates(DateTime date) {
    DateTime firstDayOfYear = DateTime(date.year, 1, 1);
    DateTime lastDayOfYear = DateTime(date.year, 12, 31);
    return '${DateFormat('d MMM yy').format(firstDayOfYear)} - ${DateFormat('d MMM yy').format(lastDayOfYear)}';
  }

  String _getMonthDates(DateTime date) {
    DateTime firstDayOfMonth = DateTime(date.year, date.month, 1);
    DateTime lastDayOfMonth = DateTime(date.year, date.month + 1, 0);
    return '${DateFormat('d MMM yy').format(firstDayOfMonth)} - ${DateFormat('d MMM yy').format(lastDayOfMonth)}';
  }

  String _getWeekDates(DateTime date) {
    int daysToSubtract = date.weekday - 1;
    DateTime firstDayOfWeek = DateTime(date.year, date.month, date.day - daysToSubtract);
    DateTime lastDayOfWeek = DateTime(firstDayOfWeek.year, firstDayOfWeek.month, firstDayOfWeek.day + 6);
     return '${DateFormat('d MMM yy').format(firstDayOfWeek)} - ${DateFormat('d MMM yy').format(lastDayOfWeek)}';
  }

 Future<void> _showDatePickerByType(DateRangeType type) async {
  DateTime? pickedDate;
  String newDateRangeText = _dateRangeText;
  DateTime initialPickerDate = _selectedDate;

  if(type == DateRangeType.week) initialPickerDate = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
  if(type == DateRangeType.month) initialPickerDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
  if(type == DateRangeType.year) initialPickerDate = DateTime(_selectedDate.year, 1, 1);

  DateTime firstAllowedDate = DateTime(2020);
  DateTime lastAllowedDate = DateTime.now().add(const Duration(days: 365 * 3));

  switch (type) {
    case DateRangeType.day:
    case DateRangeType.week:
    case DateRangeType.month:
      pickedDate = await showDatePicker( context: context, initialDate: initialPickerDate, firstDate: firstAllowedDate, lastDate: lastAllowedDate, builder: (context, child) { return Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: Colors.grey[800]!, onPrimary: Colors.white, onSurface: Colors.black)), child: child!); }, );
      if (pickedDate != null) {
         if(type == DateRangeType.day) newDateRangeText = DateFormat('d MMM yy').format(pickedDate);
         if(type == DateRangeType.week) { int daysToSubtract = pickedDate.weekday - 1; pickedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day - daysToSubtract); newDateRangeText = _getWeekDates(pickedDate); }
         if(type == DateRangeType.month) { pickedDate = DateTime(pickedDate.year, pickedDate.month, 1); newDateRangeText = _getMonthDates(pickedDate); }
      }
      break;
    case DateRangeType.year:
      await _showYearPicker(); return; // Handles its own update
  }

  if (pickedDate != null) {
    bool rangeChanged = true; // Assume changed unless proven otherwise
     if (type == DateRangeType.day) {
       rangeChanged = !(pickedDate.year == _selectedDate.year && pickedDate.month == _selectedDate.month && pickedDate.day == _selectedDate.day);
     } else {
       rangeChanged = pickedDate != _selectedDate; // Check if start date changed for ranges
     }

    if (rangeChanged) {
       setState(() {
          _selectedDate = pickedDate!;
          _dateRangeText = newDateRangeText;
          _currentRangeType = type; // Set the range type directly
       });
       _filterAndDisplayAppointments(); // Apply filters to the existing _allAppointments list
    }
  }
}
  Future<void> _showYearPicker() async {
     final int initialYear = _selectedDate.year; final int currentYear = DateTime.now().year; final List<int> years = List.generate(10, (index) => currentYear - 5 + index); int? selectedYear = await showDialog<int>( context: context, builder: (BuildContext context) { return SimpleDialog( title: const Text('Select Year'), children: years.map((year) => SimpleDialogOption( onPressed: () { Navigator.pop(context, year); }, child: Text(year.toString(), style: TextStyle(fontWeight: year == initialYear ? FontWeight.bold : FontWeight.normal)), )).toList(), ); }, ); if (selectedYear != null && selectedYear != _selectedDate.year) { final selectedDate = DateTime(selectedYear, 1, 1); setState(() { _selectedDate = selectedDate; _dateRangeText = _getYearDates(selectedDate); }); _filterAndDisplayAppointments(); } // Filter existing data
   }

  Future<void> _showMonthPicker() async {
      final List<String> months = DateFormat.MMMM().dateSymbols.MONTHS; int initialMonthIndex = _selectedDate.month - 1; int? selectedIndex = await showDialog<int>( context: context, builder: (BuildContext context) { return SimpleDialog( title: Text('Select Month (${_selectedDate.year})'), children: months.asMap().entries.map((entry) { int index = entry.key; String monthName = entry.value; return SimpleDialogOption( onPressed: () { Navigator.pop(context, index); }, child: Text(monthName, style: TextStyle(fontWeight: index == initialMonthIndex ? FontWeight.bold : FontWeight.normal)), ); }).toList(), ); }, ); if (selectedIndex != null && selectedIndex != (_selectedDate.month - 1)) { final selectedDate = DateTime(_selectedDate.year, selectedIndex + 1, 1); setState(() { _selectedDate = selectedDate; _dateRangeText = _getMonthDates(selectedDate); }); _filterAndDisplayAppointments(); } // Filter existing data
   }

  Future<void> _showWeekPicker() async { _showDatePickerByType(DateRangeType.week); }
  Future<void> _showDayPicker() async { _showDatePickerByType(DateRangeType.day); }

  void _showDateRangeMenu(BuildContext context) {
     final RenderBox? button = _dateButtonKey.currentContext?.findRenderObject() as RenderBox?; if (button == null) return; final Offset offset = button.localToGlobal(Offset.zero); final Size buttonSize = button.size; showMenu( context: context, position: RelativeRect.fromLTRB( offset.dx, offset.dy + buttonSize.height, offset.dx + buttonSize.width, offset.dy + buttonSize.height + 2, ), constraints: BoxConstraints(minWidth: buttonSize.width, maxWidth: buttonSize.width), items: [ PopupMenuItem(height: 40, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('Day', style: TextStyle(color: Colors.grey[800], fontSize: 14)), onTap: () => _showDatePickerByType(DateRangeType.day)), _buildDivider(), PopupMenuItem(height: 40, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('Week', style: TextStyle(color: Colors.grey[800], fontSize: 14)), onTap: () => _showDatePickerByType(DateRangeType.week)), _buildDivider(), PopupMenuItem(height: 40, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('Month', style: TextStyle(color: Colors.grey[800], fontSize: 14)), onTap: () => _showDatePickerByType(DateRangeType.month)), _buildDivider(), PopupMenuItem(height: 40, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('Year', style: TextStyle(color: Colors.grey[800], fontSize: 14)), onTap: () => _showDatePickerByType(DateRangeType.year)), ], elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), color: Colors.white, );
  }

   PopupMenuItem _buildDivider() { return PopupMenuItem(height: 1, enabled: false, padding: EdgeInsets.zero, child: Divider(height: 1, thickness: 1, color: Colors.grey[200])); }

  void _showExportOptions() {
     final RenderBox? button = _exportButtonKey.currentContext?.findRenderObject() as RenderBox?; if (button == null) return; final Offset offset = button.localToGlobal(Offset.zero); final Size buttonSize = button.size; showMenu( context: context, position: RelativeRect.fromLTRB(offset.dx, offset.dy + buttonSize.height, offset.dx + buttonSize.width, offset.dy + buttonSize.height + 2), items: [ PopupMenuItem(height: 40, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('PDF', style: TextStyle(color: Colors.grey[800], fontSize: 14)), onTap: () => _exportAs('pdf')), _buildDivider(), PopupMenuItem(height: 40, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('Excel', style: TextStyle(color: Colors.grey[800], fontSize: 14)), onTap: () => _exportAs('excel')), ], elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), color: Colors.white, );
  }

  Future<void> _exportAs(String format) async {
     final filteredList = _getFilteredAppointments(); if (filteredList.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No appointments matching filter to export'))); return; } setState(() => _isLoading = true); String filePath = ''; String message = ''; try { if (format == 'pdf') { filePath = await _exportAsPDF(filteredList); message = 'Exported successfully as PDF'; } else if (format == 'excel') { filePath = await _exportAsExcel(filteredList); message = 'Exported successfully as Excel'; } else { throw Exception('Invalid export format'); } if (mounted) { final file = File(filePath); final snackBar = SnackBar(content: Text('$message: ${file.path.split('/').last}'), action: SnackBarAction(label: 'Open', onPressed: () async { if (await file.exists()) { OpenFile.open(file.path); } })); ScaffoldMessenger.of(context).showSnackBar(snackBar); } } catch (e) { print('Export error: $e'); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'))); } finally { if(mounted) setState(() => _isLoading = false); }
  }
  // --- End Date/Picker/Export Logic ---

  // --- Export Functions (Using correct fields) ---
  Future<String> _exportAsPDF(List<Map<String, dynamic>> appointmentsToExport) async {
    final pdf = pw.Document();
     pdf.addPage( pw.Page( pageFormat: PdfPageFormat.a4.landscape, build: (context) { return pw.Column( crossAxisAlignment: pw.CrossAxisAlignment.start, children: [ pw.Text('Appointments - $_dateRangeText', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 20), pw.Table( border: pw.TableBorder.all(), columnWidths: { 0: const pw.FixedColumnWidth(50), 1: const pw.FixedColumnWidth(100), 2: const pw.FixedColumnWidth(150), 3: const pw.FixedColumnWidth(90), 4: const pw.FixedColumnWidth(70), 5: const pw.FixedColumnWidth(100), 6: const pw.FixedColumnWidth(70), 7: const pw.FixedColumnWidth(70), }, children: [ pw.TableRow( children: [ 'Ref #', 'Client', 'Services', 'Appt Date', 'Time', 'Staff', 'Price', 'Status' ].map((text) => pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))).toList()), ...appointmentsToExport.map((appointment) { final ref = appointment['id'] ?? 'N/A'; final client = appointment['customerName'] ?? 'N/A'; final servicesList = (appointment['services'] as List?)?.map((s) => (s is Map ? s['name'] : s)?.toString() ?? '').where((s) => s.isNotEmpty).toList() ?? []; final services = servicesList.isNotEmpty ? servicesList.join(', ') : 'N/A'; String apptDateStr = 'N/A'; String apptTimeStr = appointment['appointmentTime'] ?? 'N/A'; dynamic dateField = appointment['appointmentDate'] ?? appointment['appointmentTimestamp']; if (dateField != null) { try { DateTime apptDate = dateField is Timestamp ? dateField.toDate() : DateTime.parse(dateField.toString()); apptDateStr = DateFormat('dd MMM yy').format(apptDate); apptTimeStr = DateFormat('HH:mm').format(apptDate); } catch (e) { apptDateStr = dateField.toString(); }} final staff = appointment['professionalName'] ?? 'N/A'; final price = 'KES ${appointment['totalAmount']?.toStringAsFixed(0) ?? 0}'; final status = appointment['status'] ?? 'N/A'; return pw.TableRow( children: [ ref, client, services, apptDateStr, apptTimeStr, staff, price, status ].map((text) => pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(text.toString()))).toList()); }), ], ), ], ); }, ), );
    final dir = await getTemporaryDirectory(); final String filePath = '${dir.path}/appointments_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf'; final file = File(filePath); await file.writeAsBytes(await pdf.save()); return filePath;
  }

  Future<String> _exportAsExcel(List<Map<String, dynamic>> appointmentsToExport) async {
    final excelFile = Excel.createExcel(); final Sheet sheet = excelFile[excelFile.getDefaultSheet()!];
     sheet.appendRow([ TextCellValue('Ref #'), TextCellValue('Client'), TextCellValue('Services'), TextCellValue('Appt Date'), TextCellValue('Time'), TextCellValue('Staff'), TextCellValue('Price (KES)'), TextCellValue('Status') ]); for (var appointment in appointmentsToExport) { final ref = appointment['id'] ?? 'N/A'; final client = appointment['customerName'] ?? 'N/A'; final servicesList = (appointment['services'] as List?)?.map((s) => (s is Map ? s['name'] : s)?.toString() ?? '').where((s) => s.isNotEmpty).toList() ?? []; final services = servicesList.isNotEmpty ? servicesList.join(', ') : 'N/A'; String apptDateStr = 'N/A'; String apptTimeStr = appointment['appointmentTime'] ?? 'N/A'; dynamic dateField = appointment['appointmentDate'] ?? appointment['appointmentTimestamp']; if (dateField != null) { try { DateTime apptDate = dateField is Timestamp ? dateField.toDate() : DateTime.parse(dateField.toString()); apptDateStr = DateFormat('yyyy-MM-dd').format(apptDate); apptTimeStr = DateFormat('HH:mm').format(apptDate); } catch (e) { apptDateStr = dateField.toString(); }} final staff = appointment['professionalName'] ?? 'N/A'; final price = appointment['totalAmount'] as num? ?? 0.0; final status = appointment['status'] ?? 'N/A'; sheet.appendRow([ TextCellValue(ref.toString()), TextCellValue(client.toString()), TextCellValue(services), TextCellValue(apptDateStr), TextCellValue(apptTimeStr), TextCellValue(staff.toString()), DoubleCellValue(price.toDouble()), TextCellValue(status.toString()) ]); } final dir = await getTemporaryDirectory(); final String filePath = '${dir.path}/appointments_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx'; final fileBytes = excelFile.save(); if (fileBytes != null) { final file = File(filePath); await file.writeAsBytes(fileBytes); return filePath; } else { throw Exception('Failed to save Excel file.'); }
  }
  // --- End Export Functions ---

  // --- Build Methods (Header, SearchBar, List, Cells) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar( backgroundColor: Colors.white, elevation: 0, centerTitle: false, title: const Text('Appointments', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w500)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)), bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: Colors.grey[300], height: 1)), ),
      body: Column( // Removed initial loading check here, handled by list builder
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildAppointmentsList(),
              ],
            ),
    );
  }

  Widget _buildHeader() {
     return Container( padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ InkWell( key: _dateButtonKey, onTap: () => _showDateRangeMenu(context), child: Container( padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Row( children: [ Icon(Icons.tune, size: 20, color: Colors.grey[800]), const SizedBox(width: 8), Text( _dateRangeText, style: TextStyle(color: Colors.grey[800], fontSize: 14, fontWeight: FontWeight.w500), ), ], ), ), ), InkWell( key: _exportButtonKey, onTap: () => _showExportOptions(), child: Container( padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration( border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(16), ), child: Row( children: [ Text('Export as', style: TextStyle(color: Colors.grey[800], fontSize: 14)), const SizedBox(width: 4), Icon(Icons.arrow_drop_down, color: Colors.grey[800], size: 20), ], ), ), ), ], ), );
  }

  Widget _buildSearchBar() {
     return Container( padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField( controller: _searchController, decoration: InputDecoration( hintText: 'Search by Reference or Client', prefixIcon: Icon(Icons.search, color: Colors.grey[400]), border: OutlineInputBorder( borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: Colors.grey[300]!), ), enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: Colors.grey[300]!), ), focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: Colors.grey[400]!), ), filled: true, fillColor: Colors.grey[100], contentPadding: const EdgeInsets.symmetric(horizontal: 20), ), onChanged: (value) { setState(() { _filterAndDisplayAppointments(); }); }, ), ); // Call filter on change
  }

   // --- Helper to get filtered list for UI and Export ---
  List<Map<String, dynamic>> _getFilteredAppointments() {
      final searchQuery = _searchController.text.toLowerCase();
      // Filter based on the currently displayed list (_appointmentsList) which holds the date-filtered data
      return _appointmentsList.where((appointment) {
         final ref = (appointment['id'] ?? '').toLowerCase();
         final clientName = (appointment['customerName'] ?? '').toLowerCase();
         final servicesList = (appointment['services'] as List?)?.map((s) => (s is Map ? s['name'] : s)?.toString() ?? '').where((s) => s.isNotEmpty).toList() ?? [];
         final servicesString = servicesList.join(', ').toLowerCase();

         return ref.contains(searchQuery) || clientName.contains(searchQuery) || servicesString.contains(searchQuery);
      }).toList();
   }
  // --- End Helper ---

  // --- UPDATED Appointments List with Services Fix ---
  Widget _buildAppointmentsList() {
    final filteredAppointments = _getFilteredAppointments(); // Use helper for display list

    // Show loading only if actively loading AND the main list (_allAppointments or _appointmentsList) is empty
    if (_isLoading && _appointmentsList.isEmpty) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    return Expanded(
      child: SingleChildScrollView( // Makes the entire table scrollable vertically if needed
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: SingleChildScrollView( // Makes the table scrollable horizontally
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!), 
              borderRadius: BorderRadius.circular(8),
            ),
            child: IntrinsicWidth( // Make column width fit content
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Row
                  Container( 
                    padding: const EdgeInsets.symmetric(vertical: 12), 
                    decoration: BoxDecoration(
                      color: Colors.grey[50], 
                      border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Row(
                      children: [
                        _buildHeaderCell('Ref #', 100),
                        _buildHeaderCell('Client', 150),
                        _buildHeaderCell('Services', 250), // Increased width from 200 to 250
                        _buildHeaderCell('Appt Date', 100),
                        _buildHeaderCell('Time', 80),
                        _buildHeaderCell('Staff', 150),
                        _buildHeaderCell('Price', 120),
                        _buildHeaderCell('Status', 80),
                      ],
                    ),
                  ),
                  // Data Rows
                  if (filteredAppointments.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: Text(
                        'No appointments found${_searchController.text.isNotEmpty ? ' matching "${_searchController.text}"' : ' for this date range'}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    )
                  else
                    ...filteredAppointments.map((appointment) { // Iterate over filtered list
                      // Extract and format data carefully
                      final ref = appointment['id'] ?? 'N/A';
                      final client = appointment['customerName'] ?? 'N/A';
                      
                      // Improved services extraction with better formatting
                      final servicesList = (appointment['services'] as List?)?.map((s) {
                        if (s is Map) {
                          // Try to get complete service info including duration if available
                          String name = s['name']?.toString() ?? '';
                          String duration = s['duration']?.toString() ?? '';
                          if (name.isNotEmpty && duration.isNotEmpty) {
                            return "$name ($duration)";
                          }
                          return name;
                        } else if (s is String) {
                          return s;
                        }
                        return '';
                      }).where((s) => s.isNotEmpty).toList() ?? [];
                      
                      // Join with line breaks instead of commas for better readability
                      final services = servicesList.isNotEmpty ? servicesList.join('\n') : 'N/A';
                      
                      String apptDateStr = 'N/A';
                      
                      // Use the direct appointmentTime field
                      String timeStr = appointment['appointmentTime'] ?? 'N/A';
                      
                      dynamic dateField = appointment['appointmentDate'] ?? appointment['appointmentTimestamp'];
                      if (dateField != null) {
                        try {
                          DateTime apptDate = dateField is Timestamp ? dateField.toDate() : DateTime.parse(dateField.toString());
                          apptDateStr = DateFormat('dd MMM yy').format(apptDate);
                          // Not modifying timeStr anymore since we're using the direct field
                        } catch (e) {
                          apptDateStr = dateField.toString();
                        }
                      }
                      
                      final staff = appointment['professionalName'] ?? 'N/A';
                      
                      // Format price with KES
                      final price = 'KES ${appointment['totalAmount']?.toStringAsFixed(0) ?? 0}';
                      
                      final status = appointment['status'] ?? 'N/A';
                      
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                        ),
                        child: Row(
                          children: [
                            _buildCell(ref, 100),
                            _buildCell(client, 150),
                            _buildServicesCell(services, 250), // Changed to specialized cell with increased width
                            _buildCell(apptDateStr, 100),
                            _buildCell(timeStr, 80),  // Using direct appointmentTime
                            _buildCell(staff, 150),
                            _buildPriceCell(price, 120),  // Using special price cell
                            _buildCell(status, 80),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Special cell for services display that allows text wrapping
  Widget _buildServicesCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(minHeight: 50), // Ensure minimum height for multi-line text
      alignment: Alignment.centerLeft, // Align text to the left
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
        overflow: TextOverflow.visible, // Allow text to be fully visible
        softWrap: true, // Enable wrapping to multiple lines
        maxLines: null, // Allow unlimited lines
      ),
    );
  }

  // Special cell for price display
  Widget _buildPriceCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14, 
          fontWeight: FontWeight.bold,  // Make price bold
        ),
        overflow: TextOverflow.visible,  // Don't truncate with ellipsis
      ),
    );
  }
  // --- End UPDATED Appointments List ---

  Widget _buildHeaderCell(String text, double width) {
     return Container( width: width, padding: const EdgeInsets.symmetric(horizontal: 16), child: Text( text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis, ), );
  }

  Widget _buildCell(String text, double width) {
     return Container( width: width, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text( text, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis, ), );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'Staffmemberadd.dart';
import 'Staffmemberedit.dart'; // Make sure to import your edit screen

class Businessteammember extends StatefulWidget {
  const Businessteammember({Key? key}) : super(key: key);

  @override
  State<Businessteammember> createState() => _BusinessteammemberState();
}

class _BusinessteammemberState extends State<Businessteammember> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _teamMembers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  Future<void> _loadTeamMembers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final box = Hive.box('appBox');
      // Load from Hive first
      if (box.containsKey('businessData')) {
        final businessData = box.get('businessData') as Map<String, dynamic>;
        if (businessData.containsKey('teamMembers')) {
          _teamMembers = List<Map<String, dynamic>>.from(businessData['teamMembers']);
        }
      }
      setState(() {}); // Update UI with any data from Hive

      // Then load from Firestore (replace 'default' with your actual business doc ID!)
      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc('default')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final teamMembersList = List<Map<String, dynamic>>.from(data['teamMembers'] ?? []);
        _teamMembers = teamMembersList;
        setState(() {});

        // Update Hive with the newly fetched data
        if (box.containsKey('businessData')) {
          final businessData = box.get('businessData') as Map<String, dynamic>;
          businessData['teamMembers'] = teamMembersList;
          await box.put('businessData', businessData);
        } else {
          await box.put('businessData', {'teamMembers': teamMembersList});
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading team members: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Filter the list based on the current _searchQuery
  List<Map<String, dynamic>> get filteredTeamMembers {
    if (_searchQuery.isEmpty) return _teamMembers;
    return _teamMembers.where((member) {
      final fullName = '${member['firstName']} ${member['lastName']}'.toLowerCase();
      final email = (member['email'] ?? '').toLowerCase();
      return fullName.contains(_searchQuery) || email.contains(_searchQuery);
    }).toList();
  }

  Future<void> _navigateToAddMember() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BusinessStaffMemberAdd()),
    );
    if (result == true) {
      // If new member was added, reload
      _loadTeamMembers();
    }
  }

  /// Pass the selected member data to StaffMemberEdit
  Future<void> _navigateToEditProfile(Map<String, dynamic> member) async {
    // Make sure the member is in our list
    final teamMemberIndex = _teamMembers.indexWhere((m) => m['email'] == member['email']);
    if (teamMemberIndex != -1) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StaffMemberEdit(member: member),
        ),
      );
      if (result == true) {
        // If the edit screen returns true, it means the member was updated
        _loadTeamMembers();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find team member data')),
      );
    }
  }

  void _showMemberOptions(Map<String, dynamic> member) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Member'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToEditProfile(member);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Member', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(member);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Staff Member'),
          content: Text('Are you sure you want to delete ${member['firstName']} ${member['lastName']}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteMember(member);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteMember(Map<String, dynamic> member) async {
    try {
      setState(() => _isLoading = true);
      final memberIndex = _teamMembers.indexWhere((m) => m['email'] == member['email']);
      if (memberIndex != -1) {
        _teamMembers.removeAt(memberIndex);
        await FirebaseFirestore.instance
            .collection('businesses')
            .doc('default')
            .update({'teamMembers': _teamMembers});

        final box = Hive.box('appBox');
        if (box.containsKey('businessData')) {
          final businessData = box.get('businessData') as Map<String, dynamic>;
          businessData['teamMembers'] = _teamMembers;
          await box.put('businessData', businessData);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team member deleted successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting member: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamList = filteredTeamMembers;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Staff Member',
          style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar + Add
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 12),
                                child: Icon(Icons.search, color: Colors.black, size: 20),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: const InputDecoration(
                                    hintText: 'Search Staff Member',
                                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.black54, size: 20),
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: TextButton.icon(
                          onPressed: _navigateToAddMember,
                          icon: const Icon(Icons.add, color: Colors.black, size: 18),
                          label: const Text(
                            'Add',
                            style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // List of members
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: teamList.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFEEEEEE),
                    ),
                    itemBuilder: (context, index) {
                      final member = teamList[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: member['profileImageUrl'] != null
                              ? NetworkImage(member['profileImageUrl'])
                              : null,
                          child: member['profileImageUrl'] == null
                              ? const Icon(Icons.person, color: Colors.grey)
                              : null,
                        ),
                        title: Text(
                          '${member['firstName']} ${member['lastName']}',
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                        ),
                        subtitle: member['services'] != null && (member['services'] as Map).isNotEmpty
                            ? Text(
                                'Services: ${(member['services'] as Map).values.expand((list) => list).length}',
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.black54),
                          onPressed: () => _showMemberOptions(member),
                        ),
                        onTap: () => _navigateToEditProfile(member),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

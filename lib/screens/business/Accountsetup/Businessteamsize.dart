import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'Businessteammembers.dart';


class TeamSize extends StatefulWidget {
  @override
  _TeamSizeState createState() => _TeamSizeState();
}

class _TeamSizeState extends State<TeamSize> {
  // Constants
  static const Map<String, int> teamSizeMapping = {
    'Just me': 1,
    '2-5 people': 5,
    '6-10 people': 10,
    '11-15 people': 15,
    '16+ people': 16,
  };

  // State variables
  late Box appBox;
  Map<String, dynamic>? businessData;
  String? selectedTeamSize;
  String? customTeamSize;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      appBox = Hive.box('appBox');
      businessData = appBox.get('businessData') ?? {};
      
      setState(() {
        selectedTeamSize = businessData!['teamSizeDescription'];
        customTeamSize = businessData!['customTeamSize'];
      });
    } catch (e) {
      print('Error loading team size data: $e');
    }
  }

  Future<void> _saveToHive() async {
    try {
      if (businessData == null) return;

      businessData!['teamSizeDescription'] = selectedTeamSize;
      businessData!['teamSizeValue'] = selectedTeamSize != null ? 
          teamSizeMapping[selectedTeamSize] : null;
      
      if (selectedTeamSize == '16+ people' && customTeamSize != null) {
        businessData!['customTeamSize'] = customTeamSize;
        businessData!['teamSizeValue'] = int.tryParse(customTeamSize!) ?? 16;
      }

      // Update setup step
      businessData!['accountSetupStep'] = 5;
      await appBox.put('businessData', businessData);
    } catch (e) {
      print('Error saving team size data: $e');
      throw e;
    }
  }

  void setTeamSize(String size) {
    setState(() {
      selectedTeamSize = size;
      if (size != '16+ people') {
        customTeamSize = null;
      }
    });
  }

  void setCustomTeamSize(String size) {
    setState(() {
      customTeamSize = size;
    });
  }
  Widget _buildTeamSizeOption(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        title: Text(text),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          if (text == "16+ people") {
            _showCustomTeamSizeDialog();
          } else {
            setTeamSize(text);
          }
        },
        selected: selectedTeamSize == text,
        selectedTileColor: const Color(0xFF1E4620).withOpacity(0.1),
      ),
    );
  }

  void _showCustomTeamSizeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Create a TextEditingController and initialize it with current customTeamSize if any
        final textController = TextEditingController(text: customTeamSize);
        
        return AlertDialog(
          title: const Text('Enter Your Team Size'),
          content: TextField(
            controller: textController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: "Enter number of team members",
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF1E4620)),
              ),
            ),
            TextButton(
              onPressed: () {
                if (textController.text.isNotEmpty) {
                  setTeamSize("16+ people");
                  setCustomTeamSize(textController.text);
                }
                Navigator.of(context).pop();
              },
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFF1E4620)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveAndContinue() async {
    try {
      if (selectedTeamSize == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a team size'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await _saveToHive();
      
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (context) => TeamMembers())
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving team size: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Account Setup',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(
                8,
                (index) => Expanded(
                  child: Container(
                    height: 8,
                    margin: EdgeInsets.only(right: index < 7 ? 8 : 0),
                    decoration: BoxDecoration(
                      color: index < 4 ? const Color(0xFF23461a) : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            const Text(
              "What's your team size?",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              'This will help us set up your calendar correctly.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            
            ...teamSizeMapping.keys.map(
              (option) => _buildTeamSizeOption(option),
            ),
            
            const Spacer(),
            
            ElevatedButton(
              onPressed: _saveAndContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E4620),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
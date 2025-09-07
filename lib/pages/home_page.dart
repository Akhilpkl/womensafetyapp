import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:telephony/telephony.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;
  List<String> sosHistory = [];
  List<String> trustedContacts = [];
  String sosMessage = "I am in danger! Please help. My location: ";
  final Telephony telephony = Telephony.instance;

  @override
  void initState() {
    super.initState();
    loadContacts();
  }

  void loadContacts() {
    setState(() {
      trustedContacts = []; // start empty
      sosHistory = [];
    });
  }

  Future<void> sendSOS() async {
    try {
      // 1️⃣ Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      print("DEBUG: Initial location permission: $permission");
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        print("DEBUG: After request permission: $permission");
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Location permission denied! Cannot send SOS.")),
          );
          return;
        }
      }

      // 2️⃣ Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location services are disabled. Please enable GPS.")),
        );
        return;
      }

      // 2️⃣ Get current position with improved settings
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
          forceAndroidLocationManager: true);
      print("DEBUG: Current position - Lat: ${position.latitude}, Lng: ${position.longitude}, Accuracy: ${position.accuracy}");

      // If accuracy is too low, try last known position
      if (position.accuracy > 100) { // 100 meters threshold
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null && lastPosition.accuracy < position.accuracy) {
          position = lastPosition;
          print("DEBUG: Using last known position - Lat: ${position.latitude}, Lng: ${position.longitude}, Accuracy: ${position.accuracy}");
        }
      }

      // 3️⃣ Build correct Google Maps URL
      String locationUrl =
          "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      print("DEBUG: Location URL: $locationUrl");

      String finalMessage = "$sosMessage $locationUrl";

      // 4️⃣ Request SMS permission and send
      bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
      print("DEBUG: SMS permissions granted: $permissionsGranted");
      if (permissionsGranted != null && permissionsGranted) {
        for (String contact in trustedContacts) {
          telephony.sendSms(to: contact, message: finalMessage);
        }

        String timestamp = DateTime.now().toString();
        setState(() {
          sosHistory.add("🚨 SOS sent at $timestamp");
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("SOS Sent with Location!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("SMS permission denied!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sending SOS: $e")),
      );
    }
  }

  void addContact() {
    TextEditingController contactController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Contact"),
        content: TextField(
          controller: contactController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: "Enter phone number"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (contactController.text.isNotEmpty) {
                setState(() {
                  trustedContacts.add(contactController.text);
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      // Home
      Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: sendSOS,
          child: const Text("🚨 SEND SOS", style: TextStyle(fontSize: 22)),
        ),
      ),

      // Contacts
      ListView(
        children: [
          ListTile(
            title: const Text("Trusted Contacts"),
            trailing: IconButton(
              icon: const Icon(Icons.add, color: Colors.pink),
              onPressed: addContact,
            ),
          ),
          ...trustedContacts.map((c) => ListTile(
            title: Text(c),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                setState(() {
                  trustedContacts.remove(c);
                });
              },
            ),
          )),
        ],
      ),

      // History
      ListView(
        children: sosHistory.map((msg) => ListTile(title: Text(msg))).toList(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Women Safety App"),
        backgroundColor: Colors.pink,
        actions: [
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: tabs[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: Colors.pink,
        onTap: (index) => setState(() => currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.contacts), label: "Contacts"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        ],
      ),
    );
  }
}

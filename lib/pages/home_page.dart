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
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Location permission denied! Cannot send SOS.")),
          );
          return;
        }
      }

      // 2️⃣ Get current position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // 3️⃣ Build correct Google Maps URL
      String locationUrl =
          "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";

      String finalMessage = "$sosMessage $locationUrl";

      // 4️⃣ Request SMS permission and send
      bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
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

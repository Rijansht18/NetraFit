import 'package:flutter/material.dart';
import 'try_on_screen.dart';
import 'upload_screen.dart';

class MainTryOnScreen extends StatefulWidget {
  const MainTryOnScreen({super.key});

  @override
  State<MainTryOnScreen> createState() => _MainTryOnScreenState();
}

class _MainTryOnScreenState extends State<MainTryOnScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Try On'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.camera),
              text: 'AR Try On',
            ),
            Tab(
              icon: Icon(Icons.photo),
              text: 'Upload Photo',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          TryOnScreen(),
          UploadScreen(),
        ],
      ),
    );
  }
}
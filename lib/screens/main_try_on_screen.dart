import 'package:flutter/material.dart';
import 'try_on_screen.dart';
import 'upload_screen.dart';

class MainTryOnScreen extends StatefulWidget {
  final List<String>? recommendedFrameFilenames;
  final String? recommendedFrameId;

  const MainTryOnScreen({
    super.key,
    this.recommendedFrameFilenames,
    this.recommendedFrameId
  });

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
        title: const Text(
          'Try On',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF275BCD),
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          indicatorColor: const Color(0xFF275BCD),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'AR Try On'),
            Tab(text: 'Upload Photo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          TryOnScreen(
            recommendedFrameId: widget.recommendedFrameId,
            recommendedFrameFilenames: widget.recommendedFrameFilenames,
          ),
          UploadScreen(
            recommendedFrameId: widget.recommendedFrameId,
            recommendedFrameFilenames: widget.recommendedFrameFilenames,
          ),
        ],
      ),
    );
  }
}
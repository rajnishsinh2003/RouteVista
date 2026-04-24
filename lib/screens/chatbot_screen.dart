import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/ai_service.dart';
import '../models/chat_message.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final List<Map<String, String>> _apiHistory = [];
  bool _isLoading = false;
  // History will load in the background without blocking the UI

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  void _initChat() {
    _apiHistory.clear();
    _apiHistory.add({
      'role': 'system',
      'content': 'You are RouteVista AI, a helpful travel assistant for India. '
          'You help users plan trips, find hidden gems, and give advice on weather, budget, and culture. '
          'Keep your responses concise, friendly, and use emojis.'
    });

    _loadLocalHistory();
  }

  Future<void> _loadLocalHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? localData = prefs.getString('chatbot_history');
      
      if (localData != null && localData.isNotEmpty) {
        final List<dynamic> decoded = json.decode(localData);
        final List<Map<String, dynamic>> localMessages = decoded.map((m) {
          return {
            'text': m['text'],
            'isUser': m['isUser'],
            'time': DateTime.parse(m['time']),
          };
        }).toList();

        if (mounted && localMessages.isNotEmpty) {
          setState(() {
            _messages.clear();
            _messages.addAll(localMessages);
          });
          
          // Rebuild API history from local messages (last 15 for context)
          final contextMsgs = localMessages.length > 15 
              ? localMessages.sublist(localMessages.length - 15)
              : localMessages;
              
          for (var msg in contextMsgs) {
            _apiHistory.add({
              'role': msg['isUser'] ? 'user' : 'assistant',
              'content': msg['text'],
            });
          }
          _scrollToBottom();
        }
      } else {
        // Only show greeting if no history exists
        setState(() {
          _messages.clear();
          _messages.add({
            'text': 'Namaste! 👋 I\'m your RouteVista Assistant. Where are we traveling today?',
            'isUser': false,
            'time': DateTime.now(),
          });
        });
      }
    } catch (e) {
      debugPrint('Error loading local history: $e');
    }
    
    // Still trigger Firestore sync in background
    _loadHistory();
  }

  Future<void> _clearAllChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear Chat?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('This will delete your conversation history.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.poppins())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text('Clear', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('chatbot_history');
      setState(() {
        _messages.clear();
        _apiHistory.clear();
        _apiHistory.add({
          'role': 'system',
          'content': 'You are RouteVista AI, a helpful travel assistant for India. '
              'You help users plan trips, find hidden gems, and give advice on weather, budget, and culture. '
              'Keep your responses concise, friendly, and use emojis.'
        });
        _messages.add({
          'text': 'Namaste! 👋 I\'m your RouteVista Assistant. Where are we traveling today?',
          'isUser': false,
          'time': DateTime.now(),
        });
      });
    }
  }

  Future<void> _loadHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || Firebase.apps.isEmpty) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: false)
          .get();

      final List<Map<String, dynamic>> loadedMessages = [];
      for (var doc in snapshot.docs) {
        final chatMsg = ChatMessage.fromFirestore(doc);
        loadedMessages.add({
          'text': chatMsg.text,
          'isUser': chatMsg.isUser,
          'time': chatMsg.timestamp,
        });
      }

      // Add only the latest 15 messages to API history to keep it fast
      final latestMessages = snapshot.docs.length > 15 
          ? snapshot.docs.sublist(snapshot.docs.length - 15)
          : snapshot.docs;

      for (var doc in latestMessages) {
        final chatMsg = ChatMessage.fromFirestore(doc);
        _apiHistory.add({
          'role': chatMsg.isUser ? 'user' : 'assistant',
          'content': chatMsg.text,
        });
      }

      if (mounted && loadedMessages.isNotEmpty) {
        setState(() {
          // If we have Firestore data, we can merge or replace.
          // For now, let's keep local as truth but update if Firestore has more.
          if (loadedMessages.length > _messages.length) {
            _messages.clear();
            _messages.addAll(loadedMessages);
            _apiHistory.clear();
            _apiHistory.add({
              'role': 'system',
              'content': 'You are RouteVista AI. Help users plan trips in India.'
            });
            final last15 = loadedMessages.length > 15 
                ? loadedMessages.sublist(loadedMessages.length - 15) 
                : loadedMessages;
            for (var m in last15) {
              _apiHistory.add({'role': m['isUser'] ? 'user' : 'assistant', 'content': m['text']});
            }
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() {
      _messages.add({
        'text': text,
        'isUser': true,
        'time': DateTime.now(),
      });
      _isLoading = true;
    });

    _apiHistory.add({'role': 'user', 'content': text});
    _scrollToBottom();

    // Save user message to Firestore
    _saveMessage(text, true);

    try {
      final response = await AiService.getChatResponse(_apiHistory);
      
      if (mounted) {
        setState(() {
          _messages.add({
            'text': response,
            'isUser': false,
            'time': DateTime.now(),
          });
          _apiHistory.add({'role': 'assistant', 'content': response});
          _isLoading = false;
        });
        _scrollToBottom();
        // Save assistant message to Firestore
        _saveMessage(response, false);
      }
    } catch (e) {
      debugPrint('Groq Chat Error: $e');
      if (mounted) {
        setState(() {
          _messages.add({
            'text': 'Oops! Error: ${e.toString().split('\n').first}',
            'isUser': false,
            'time': DateTime.now(),
          });
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveMessage(String text, bool isUser) async {
    // 1. Save locally
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> history = _messages.map((m) => {
        'text': m['text'],
        'isUser': m['isUser'],
        'time': (m['time'] as DateTime).toIso8601String(),
      }).toList();
      
      // Keep only last 50 for local storage
      final saveHistory = history.length > 50 ? history.sublist(history.length - 50) : history;
      await prefs.setString('chatbot_history', json.encode(saveHistory));
    } catch (e) {
      debugPrint('Local Cache Error: $e');
    }

    // 2. Save to Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || Firebase.apps.isEmpty) return;

    try {
      final chatMsg = ChatMessage(
        userId: user.uid,
        text: text,
        isUser: isUser,
        timestamp: DateTime.now(),
      );
      await FirebaseFirestore.instance.collection('chats').add(chatMsg.toMap());
    } catch (e) {
      debugPrint('Error saving message: $e');
    }
  }

  void _scrollToBottom() {
    Timer(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF065A60),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RouteVista AI', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            Text('Travel Assistant', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            onSelected: (val) {
              if (val == 'clear') _clearAllChat();
              if (val == 'refresh') _initChat();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'refresh', child: Text('Refresh Sync')),
              const PopupMenuItem(value: 'clear', child: Text('Clear History', style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: Opacity(
                    opacity: 0.05,
                    child: Image.asset(
                      'assets/icon/icon.png',
                      width: 250,
                      height: 250,
                    ),
                  ),
                ),
                ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _chatBubble(msg['text'], msg['isUser']);
                  },
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00BFA6))),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _chatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF065A60) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(fontSize: 13, color: isUser ? Colors.white : const Color(0xFF1A1A2E)),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask me anything...',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(color: Color(0xFF065A60), shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

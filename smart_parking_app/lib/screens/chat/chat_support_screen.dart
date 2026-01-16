// lib/screens/chat/chat_support_screen.dart
import 'package:flutter/material.dart';

class ChatSupportScreen extends StatefulWidget {
  @override
  _ChatSupportScreenState createState() => _ChatSupportScreenState();
}

class _ChatSupportScreenState extends State<ChatSupportScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: 'Hello! How can I help you today? You can ask about booking, payments, or cancellations.',
      isUser: false,
    ));
  }

  void _handleSubmitted(String text) {
    _textController.clear();
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });
    
    _scrollToBottom();

    // Simulate bot response
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: _getBotResponse(text),
            isUser: false,
          ));
        });
        _scrollToBottom();
      }
    });
  }

  String _getBotResponse(String input) {
    final lowerInput = input.toLowerCase();
    
    if (lowerInput.contains('book') || lowerInput.contains('reserve')) {
      return 'To book a spot, go to the "Find Parking" tab, select a location on the map or list, choose your time slot, and click "Book Now".';
    } else if (lowerInput.contains('payment') || lowerInput.contains('wallet') || lowerInput.contains('money')) {
      return 'You can pay using your Wallet. Go to "Wallet" from the home screen to add money. We also verify bookings via QR code.';
    } else if (lowerInput.contains('cancel') || lowerInput.contains('refund')) {
      return 'You can cancel a booking from the "My Bookings" tab. Refunds are processed to your wallet based on our cancellation policy (90% refund if >24h).';
    } else if (lowerInput.contains('qr') || lowerInput.contains('code') || lowerInput.contains('scan')) {
      return 'Your QR code is available in the Booking Details. Show it at the entry gate. You can also use the Scanner if needed.';
    } else if (lowerInput.contains('contact') || lowerInput.contains('support') || lowerInput.contains('call')) {
      return 'You can reach our support team at +91 1234567890 or email support@quickpark.com.';
    } else if (lowerInput.contains('thank')) {
      return "You're welcome! Drive safely.";
    } else {
      return 'I\'m not sure I understand. Could you please rephrase? You can ask about booking, wallet, or cancellations.';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat Support')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _messages[index];
              },
            ),
          ),
          Divider(height: 1.0),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor),
            child: _buildTextComposer(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).primaryColor),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            Flexible(
              child: TextField(
                controller: _textController,
                onSubmitted: _handleSubmitted,
                decoration: InputDecoration.collapsed(hintText: 'Send a message'),
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: Icon(Icons.send),
                onPressed: () => _handleSubmitted(_textController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(child: Text('B')),
            SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue[100] : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(text),
            ),
          ),
          if (isUser) ...[
            SizedBox(width: 10),
            CircleAvatar(child: Text('Me')),
          ],
        ],
      ),
    );
  }
}
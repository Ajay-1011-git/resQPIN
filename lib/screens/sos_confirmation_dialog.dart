import 'package:flutter/material.dart';

/// 5-second countdown confirmation dialog for SOS alerts.
/// Returns true if SOS should be created (countdown completed),
/// false if cancelled.
class SOSConfirmationDialog extends StatefulWidget {
  final String sosType;
  final String subCategory;

  const SOSConfirmationDialog({
    super.key,
    required this.sosType,
    required this.subCategory,
  });

  @override
  State<SOSConfirmationDialog> createState() => _SOSConfirmationDialogState();
}

class _SOSConfirmationDialogState extends State<SOSConfirmationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _secondsLeft = 5;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _controller.forward();
    _controller.addListener(() {
      final newSeconds = 5 - (_controller.value * 5).floor();
      if (newSeconds != _secondsLeft) {
        setState(() => _secondsLeft = newSeconds);
      }
    });
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.of(context).pop(true); // Confirmed
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orangeAccent,
            size: 28,
          ),
          SizedBox(width: 10),
          Text(
            'Confirm SOS',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sending ${widget.sosType} alert',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subCategory,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          // Countdown circle
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CircularProgressIndicator(
                      value: 1.0 - _controller.value,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey.shade800,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.orangeAccent,
                      ),
                    );
                  },
                ),
                Center(
                  child: Text(
                    '$_secondsLeft',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Alert will be sent automatically',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false), // Cancelled
          child: const Text(
            'CANCEL',
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}

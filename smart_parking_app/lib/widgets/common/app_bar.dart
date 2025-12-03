
// lib/widgets/common/app_bar.dart - Custom app bar
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  
  const CustomAppBar({
    required this.title,
    this.actions,
    this.showBackButton = true,
  });
  
  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      automaticallyImplyLeading: showBackButton,
      elevation: 0,
      actions: actions,
    );
  }
  
  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
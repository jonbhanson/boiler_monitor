import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'controller.dart';

class CurrentTemp extends StatelessWidget {
  const CurrentTemp({Key? key, required this.controller}) : super(key: key);
  final Controller controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 15),
          const Text("Current temperature:", style: TextStyle(fontSize: 20)),
          const SizedBox(height: 15),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: controller.engagedIndicatorColor,
                ),
              ),
              const SizedBox(width: 20),
              Text(
                controller.displayText,
                style: TextStyle(fontSize: Platform.isMacOS ? 45 : 65, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(controller.lastTended == null ? "" : "Last tended at ${DateFormat.jm().format(controller.lastTended!)}", style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

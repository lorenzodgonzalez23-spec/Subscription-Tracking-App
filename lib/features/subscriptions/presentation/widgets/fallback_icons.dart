import 'package:flutter/material.dart';

const subscriptionFallbackIcons = <IconData>[
  Icons.play_circle_fill_rounded,
  Icons.smart_toy_rounded,
  Icons.cloud_rounded,
  Icons.music_note_rounded,
  Icons.sports_esports_rounded,
  Icons.fitness_center_rounded,
  Icons.school_rounded,
  Icons.bolt_rounded,
];

IconData fallbackIconFor(int index) =>
    subscriptionFallbackIcons[index
        .clamp(0, subscriptionFallbackIcons.length - 1)
        .toInt()];

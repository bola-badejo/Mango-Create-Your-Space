
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Models/controllers/player_controller.dart';
import 'package:mango/Utils/full_player.dart';

class MiniPlayer extends StatelessWidget {
  MiniPlayer({Key? key}) : super(key: key);
  final PlayerController player = Get.find<PlayerController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final item = player.current.value;
      if (item == null) return const SizedBox.shrink();

      return GestureDetector(
        onTap: () => Get.to(() => PlayerPage()),
        child: Container(
          height: 68,
          color: Colors.grey.shade900,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              
              if (item.artUri != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(item.artUri.toString(), width: 48, height: 48, fit: BoxFit.cover),
                )
              else
                Container(width: 48, height: 48, color: Colors.black),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontSize: 14, color: Colors.white), overflow: TextOverflow.ellipsis),
                    Text(item.artist ?? '', style: const TextStyle(fontSize: 12, color: Colors.white70), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(player.playing.value ? Icons.pause : Icons.play_arrow, color: Colors.white),
                onPressed: () => player.playPause(),
              ),
            ],
          ),
        ),
      );
    });
  }
}

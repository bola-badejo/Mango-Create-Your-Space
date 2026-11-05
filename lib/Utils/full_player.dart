
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mango/Models/controllers/player_controller.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class PlayerPage extends StatelessWidget {
  PlayerPage({Key? key}) : super(key: key);
  final PlayerController pc = Get.find<PlayerController>();

  String _format(Duration d) {
    final twoDigits = (int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    final hours = d.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        backgroundColor: MangoPalette.black,
      ),
      body: Obx(() {
        final item = pc.current.value;
        final posMs = pc.position.value;
        final pos = Duration(milliseconds: posMs.toInt());
        final dur = item?.extras?['duration'] != null
            ? Duration(milliseconds: (item!.extras!['duration'] as int))
            : const Duration(milliseconds: 0);

        if (item == null) return const Center(child: Text('No track'));

        return Column(
          children: [
            const SizedBox(height: 20),
            if (item.artUri != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.network(item.artUri.toString(), height: 280),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Text(item.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(item.artist ?? '', style: const TextStyle(fontSize: 14, color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Slider(
                    min: 0,
                    max: dur.inMilliseconds.toDouble().clamp(1.0, double.infinity),
                    value: pos.inMilliseconds.toDouble().clamp(0.0, dur.inMilliseconds.toDouble().clamp(1.0, double.infinity)),
                    onChanged: (v) => pc.seek(Duration(milliseconds: v.toInt())),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_format(pos), style: const TextStyle(fontSize: 12)),
                      Text(_format(dur), style: const TextStyle(fontSize: 12)),
                    ],
                  )
                ],
              ),
            ),
            const Spacer(),
            
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
        tooltip: 'Shuffle',
                    icon: Icon(pc.shuffle.value ? Icons.shuffle_on : Icons.shuffle),
                    onPressed: () => pc.toggleShuffle(),
                  ),
                  IconButton(
        tooltip: 'Previous track',
                    icon: const Icon(Icons.skip_previous, size: 36),
                    onPressed: () => pc.skipPrevious(),
                  ),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: IconButton(
        tooltip: 'Pause',
                      icon: Icon(pc.playing.value ? Icons.pause : Icons.play_arrow, color: MangoPalette.black, size: 32),
                      onPressed: () => pc.playPause(),
                    ),
                  ),
                  IconButton(
        tooltip: 'Next track',
                    icon: const Icon(Icons.skip_next, size: 36),
                    onPressed: () => pc.skipNext(),
                  ),
                  IconButton(
        tooltip: 'Repeat one',
                    icon: Icon(pc.repeatMode.value == RepeatMode.one
                        ? Icons.repeat_one
                        : pc.repeatMode.value == RepeatMode.all
                            ? Icons.repeat
                            : Icons.repeat_outlined),
                    onPressed: () => pc.cycleRepeat(),
                  ),
                ],
              ),
            )
          ],
        );
      }),
    );
  }
}

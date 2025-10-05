import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import '../player_service.dart';
import '../pages/full_player_page.dart';
import '../utils/snackbar.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, player, child) {
        if (player.currentTrack == null) {
          return const SizedBox.shrink();
        }

        final track = player.currentTrack!;
        final displayTitle = "${track.albumName} - ${track.title}";

        return BottomAppBar(
          color: Colors.grey[900],
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FullPlayerPage(), // pas 'const'
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Je joue en ce moment")),
              );
            },
            child: ListTile(
              leading: const Icon(
                Icons.music_note,
                color: Color.fromARGB(255, 252, 252, 252),
              ),
              title: SizedBox(
                height: 20,
                child: Marquee(
                  text: displayTitle,
                  style: const TextStyle(color: Colors.white),
                  blankSpace: 40.0,
                  velocity: 30.0,
                  pauseAfterRound: Duration(seconds: 1),
                  startPadding: 10.0,
                ),
              ),
              trailing: IconButton(
                icon: Icon(
                  player.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () => player.togglePlayPause(),
              ),
            ),
          ),
        );
      },
    );
  }
}

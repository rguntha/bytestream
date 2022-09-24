import 'package:audio_service/audio_service.dart';
import 'package:bytestream/main.dart';

class LayamritamAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {

  MyHomePageState homePageState;

  LayamritamAudioHandler(this.homePageState);

  Future<void> play() async {
    print('******Calling play from Handler');
    homePageState.play();
  }

  Future<void> pause() async {
    print('******Calling pause from Handler');
    homePageState.pause();
  }
  Future<void> seek(Duration position) async {
    print('******Calling seek from Handler');
    homePageState.seek(position);
  }

}
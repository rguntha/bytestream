import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:bytestream/buffer_audio_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

import 'layamritam-audio-handler.dart';

void main() {
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'JustAudio StreamAudioSource Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {

  final AudioPlayer _audioPlayerJust = AudioPlayer(
      audioLoadConfiguration: AudioLoadConfiguration(androidLoadControl: AndroidLoadControl(),
      darwinLoadControl: DarwinLoadControl(preferredForwardBufferDuration: const Duration(seconds: 50))));

  final progressNotifier = ValueNotifier<ProgressBarState>(
    ProgressBarState(
      current: Duration.zero,
      buffered: Duration.zero,
      total: Duration.zero,
    ),
  );
  final buttonNotifier = ValueNotifier<ButtonState>(ButtonState.paused);
  @override
  void dispose() {
    _audioPlayerJust.dispose();
    super.dispose();
  }

  LayamritamAudioHandler? _audioHandler = null;

  _setupServices() async{

    _audioHandler = await AudioService.init(
      builder: () => LayamritamAudioHandler(this),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.layamritam.app.channel.audio',
        androidNotificationChannelName: 'Music playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    /*
      if(Platform.isIOS){
        AudioSystem.instance.setIosAudioCategory(IosAudioCategory.playback);
      }
      AudioSystem.instance.addMediaEventListener(_mediaEventListener);
       */
    AudioSession.instance.then((audioSession) async {
      // This line configures the app's audio session, indicating to the OS the
      // type of audio we intend to play. Using the "speech" recipe rather than
      // "music" since we are playing a podcast.
      await audioSession.configure(AudioSessionConfiguration.music());
      // Listen to audio interruptions and pause or duck as appropriate.
      _handleInterruptions(audioSession);
      // Use another plugin to load audio to play.
    });
  }

  bool playInterrupted = false;
  void _handleInterruptions(AudioSession audioSession) {
    // just_audio can handle interruptions for us, but we have disabled that in
    // order to demonstrate manual configuration.
    audioSession.becomingNoisyEventStream.listen((_) {
      print('PAUSE');
      pause();
    });
    audioSession.setActive(true);
    audioSession.interruptionEventStream.listen((event) {
      print('interruption begin: ${event.begin}');
      print('interruption type: ${event.type}');
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            if(buttonNotifier.value == ButtonState.playing){
              playInterrupted = true;
              pause();
              break;
            }
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            if(playInterrupted){
              playInterrupted = false;
              play();
            }
            break;
        }
      }
    });
    audioSession.devicesChangedEventStream.listen((event) {
      print('Devices added: ${event.devicesAdded}');
      print('Devices removed: ${event.devicesRemoved}');
    });
  }

  @override
  void initState(){
    super.initState();
    _setupServices();
  }

  int startTime = 0;
  int loadToMemTime = 0;
  int beforeSourceTime = 0;
  int afterSourceTime = 0;
  int playStartTime = 0;

  _printTimes(){
    print('**************TotalTime: ${playStartTime-startTime}, loadToMemTime: ${loadToMemTime-startTime}, beforeSourceTime: ${beforeSourceTime-loadToMemTime}, afterSourceTime: ${afterSourceTime-beforeSourceTime}, playStartTime: ${playStartTime-afterSourceTime} ')  ;
  }

  _setupByteStreamSource() async{
    startTime = DateTime.now().millisecondsSinceEpoch;

    var content = await rootBundle
        .load("assets/music/rang.mp3");

    loadToMemTime = DateTime.now().millisecondsSinceEpoch;

    String? _mime = lookupMimeType('rang.mp3',headerBytes: content.buffer.asUint8List(0,2));
    print('Found mime $_mime');
    _mime ??= 'audio/mpeg';


    BufferAudioSource bufferAudioSource = BufferAudioSource(content.buffer.asUint8List(), _mime);
    beforeSourceTime = DateTime.now().millisecondsSinceEpoch;

    _audioHandler?.mediaItem.add(MediaItem(
      // Specify a unique ID for each media item:
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      // Metadata to display in the notification:
      album:"Amma",
      title: "Rang Rang",
      displaySubtitle:"Rang Rang Ja",
      duration: const Duration(seconds: 458),
    ));

    await _audioPlayerJust.setAudioSource(bufferAudioSource);
    afterSourceTime = DateTime.now().millisecondsSinceEpoch;

    //I/flutter (14016): TotalTime: 4495, loadToMemTime: 72, beforeSourceTime: 24, afterSourceTime: 4376, playStartTime: 23
  }

  AudioProcessingState _getAudioProcessingState(){
    if(_audioPlayerJust == null){
      return AudioProcessingState.idle;
    }
    switch(_audioPlayerJust.processingState){
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      default:
        return AudioProcessingState.idle;
    };
  }

  int playerPositionMS = 0;
  _addPlaybackState(isPlaying,{isLoading=false}){
    print('******Calling addPlaybackState');
    if(kIsWeb){
      return;
    }
    if(_audioHandler == null || _audioHandler?.playbackState == null){
      return;
    }
    _audioHandler?.playbackState.add(
        PlaybackState(
          controls: [
            MediaControl.skipToPrevious,
            if(isPlaying) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: [1, 2],
          playing:isPlaying,
          processingState: _getAudioProcessingState(),
          updatePosition: Duration(milliseconds: playerPositionMS),
        )
    );
  }

  void play() async {
    print('****** play');
    print('******Calling addPlaybackState from play');
    _addPlaybackState(true);
    if(_audioPlayerJust.audioSource == null){
      _setupAudioPlayerJust();
      await _setupByteStreamSource();
    }
    await _audioPlayerJust.play();
  }

  void pause() async{
    print('******pause');
    _addPlaybackState(false);
    await _audioPlayerJust.pause();
  }


  void seek(Duration position) async{
    _addPlaybackState(true);
    await _audioPlayerJust.seek(position);
    print('******Calling addPlaybackState from seek');
  }

  void _replay() async{
    await _audioPlayerJust.seek(Duration.zero);
    play();
  }


  void _setupAudioPlayerJust(){
    // listen for changes in player state
    _audioPlayerJust.playerStateStream.listen((playerState) {
      print('Player Processing State: ${playerState.processingState}');
      final processingState = playerState.processingState;
      if (processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering) {
        buttonNotifier.value = ButtonState.loading;
      }else if (!playerState.playing) {
        buttonNotifier.value = ButtonState.paused;
      } else if (processingState != ProcessingState.completed) {
        playStartTime = DateTime.now().millisecondsSinceEpoch;
        _printTimes();
        buttonNotifier.value = ButtonState.playing;
      }else{
        print('Calling reply');
        _replay();
      }
    });

    // listen for changes in play position
    _audioPlayerJust.positionStream.listen((position) {
      final oldState = progressNotifier.value;
      playerPositionMS = position.inMilliseconds;
      progressNotifier.value = ProgressBarState(
        current: position,
        buffered: oldState.buffered,
        total: oldState.total,
      );
    });

    // listen for changes in the buffered position
    _audioPlayerJust.bufferedPositionStream.listen((bufferedPosition) {
      final oldState = progressNotifier.value;
      progressNotifier.value = ProgressBarState(
        current: oldState.current,
        buffered: bufferedPosition,
        total: oldState.total,
      );
    });

    // listen for changes in the total audio duration
    _audioPlayerJust.durationStream.listen((totalDuration) {
      final oldState = progressNotifier.value;
      progressNotifier.value = ProgressBarState(
        current: oldState.current,
        buffered: oldState.buffered,
        total: totalDuration ?? Duration.zero,
      );
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _getFilePlayer(),
            // _getBufferedStreamPlayer(),
          ],
        ),
      ),
    );
  }

  _getFilePlayer(){
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ValueListenableBuilder<ButtonState>(
            valueListenable: buttonNotifier,
            builder: (_, value, __) {
              switch (value) {
                case ButtonState.loading:
                  return Container(
                    margin: const EdgeInsets.all(8.0),
                    width: 50.0,
                    height: 50.0,
                    child: const CircularProgressIndicator(),
                  );
                case ButtonState.paused:
                  return IconButton(
                    icon: const Icon(
                      Icons.play_circle_fill,
                      size: 50,
                    ),
                    iconSize: 50.0,
                    onPressed: play,
                  );
                case ButtonState.playing:
                  return IconButton(
                    icon: const Icon(
                      Icons.pause,
                      size: 50,
                    ),
                    iconSize: 50.0,
                    onPressed: pause,
                  );
                default:
                  return Container();
              }
            },
          ),
          const SizedBox(width: 10,),
          Expanded(
            child: ValueListenableBuilder<ProgressBarState>(
              valueListenable: progressNotifier,
              builder: (_, value, __) {
                return ProgressBar(
                  progress: value.current,
                  buffered: value.buffered,
                  total: value.total,
                  onSeek: seek,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  _getBufferedStreamPlayer(){

  }
}

class ProgressBarState {
  ProgressBarState({
    required this.current,
    required this.buffered,
    required this.total,
  });
  final Duration current;
  final Duration buffered;
  final Duration total;
}

enum ButtonState { paused, playing, loading }
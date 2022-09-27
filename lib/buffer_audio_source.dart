
import 'dart:async';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

class BufferAudioSource extends StreamAudioSource {
  final Uint8List _buffer;
  final String _mime;
  BufferAudioSource(this._buffer,this._mime) : super(tag: "Amma");

  @override
  Future<StreamAudioResponse> request([int? start, int? end]){
    print('$start:$end:$_mime');
    int startTime = DateTime.now().millisecondsSinceEpoch;
    start = start ?? 0;
    end = end ?? _buffer.length;
    if(end > _buffer.length){
      end = _buffer.length;
    }

    int contentLength = end - start;
    print('$start:$end');

    StreamController<List<int>> controller = StreamController<List<int>>();

    Stream<List<int>> stream = controller.stream;

    Timer.periodic(Duration(milliseconds: 100), (timer) {
      if(start! >= end!){
        timer.cancel();
        controller.close();
        return;
      }
      int endPos = start! + 10000;
      if(endPos > end!){
        endPos = end!;
      }
      controller.add(_buffer.sublist(start!,endPos));
      start = endPos;
    });
    // Stream.value(List<int>.from(_buffer.skip(start).take(end - start)));
    // Stream.value(_buffer.sublist(start,end));
    print('**************$start:$end-done. time taken to convert the Uint8List to List<int> ${DateTime.now().millisecondsSinceEpoch - startTime}');

    return Future.value(
      StreamAudioResponse(
        sourceLength: _buffer.length,
        contentLength: contentLength,
        offset: start,
        contentType: _mime,
        stream:stream,
        // stream:_streamController.stream,
      ),
    );
  }
}
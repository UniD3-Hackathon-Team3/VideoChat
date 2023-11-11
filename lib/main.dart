import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget{
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final IO.Socket socket;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  RTCPeerConnection? pc;

  @override
  void initState() {
    // TODO: implement initState
    init();
    super.initState();
  }

  Future init() async{
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    await connectSocket();
    await joinRoom();
  }



  Future connectSocket() async{
    socket = IO.io('http://13.53.125.151:3000/', IO.OptionBuilder().setTransports(['websocket']).build());
    socket.onConnect((data) => print('연결 완료 !'));
    
    socket.on('joined', (data) {  
      print(': socket--joined / $data');  
      onReceiveJoined();  
    });  
    
    socket.on('offer', (data) async {  
      print(': listener--offer');  
      onReceiveOffer(jsonDecode(data));  
    });  
    
    socket.on('answer', (data) {  
      print(' : socket--answer');  
      onReceiveAnswer(jsonDecode(data));  
    });  
    
    socket.on('ice', (data) {  
      print(': socket--ice');  
      onReceiveIce(jsonDecode(data));  
    }); 
  }

  Future joinRoom() async{
    final config = {
      'iceServers': [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };

    final sdpConstraints = {
      'mandatory':{
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional':[]
    };

    pc = await createPeerConnection(config, sdpConstraints);


    final mediaConstraints = {
      'audio':true,
      'video':{
        'facingMode':'user'
      }
    };

    _localStream = await Helper.openCamera(mediaConstraints);

    _localStream!.getTracks().forEach((track) {
      pc!.addTrack(track, _localStream!);
    });

    _localRenderer.srcObject = _localStream;

    pc!.onIceCandidate = (ice) {
      onIceGenerated(ice);
    };

    pc!.onAddStream = (stream){
      _remoteRenderer.srcObject = stream;
    };

    socket.emit('join');
  }

  void onReceiveJoined() {  
    _sendOffer();  
  }  
    
  Future _sendOffer() async {  
    print('send offer');  
    
    RTCSessionDescription offer = await pc!.createOffer();  
    pc!.setLocalDescription(offer);  
    
    // log.localSdp = offer.toMap().toString();  
    
    socket.emit('offer', jsonEncode(offer.toMap()));  
  }

  Future<void> onReceiveOffer(data) async {  
    final offer = RTCSessionDescription(data['sdp'], data['type']);  
    pc!.setRemoteDescription(offer);  
    
    final answer = await pc!.createAnswer();  
    pc!.setLocalDescription(answer);  
    
    _sendAnswer(answer);  
  }  
    
  Future _sendAnswer(answer) async {  
    print(': send answer');  
    socket.emit('answer', jsonEncode(answer.toMap()));  
    // log.localSdp = answer.toMap().toString();  
  }

  Future onReceiveAnswer(data) async {  
    print('  --got answer');  
    setState(() {});  
    final answer = RTCSessionDescription(data['sdp'], data['type']);  
    pc!.setRemoteDescription(answer);  
  }

  Future onIceGenerated(RTCIceCandidate ice) async {  
    print('send ice ');  
    setState(() {});  
    
    socket.emit('ice', jsonEncode(ice.toMap()));  
    
    // log.sendIceList.add(ice.toMap().toString());  
  }  
    
  Future onReceiveIce(data) async {  
    print('   --got ice');  
    setState(() {});  
    
    final ice = RTCIceCandidate(  
      data['candidate'],  
      data['sdpMid'],  
      data['sdpMLineIndex'],  
    );  
    pc!.addCandidate(ice);  
  }


  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return MaterialApp(
      home: Row(
        children: [
          Expanded(child: RTCVideoView(_localRenderer)),
          Expanded(child: RTCVideoView(_remoteRenderer)),
        ],
      ),
    );
  }
}
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';


final iosTheme = ThemeData(
  primarySwatch: Colors.orange,
  primaryColor: Colors.grey[100],
  primaryColorBrightness: Brightness.light,
);

final defaultTheme = ThemeData(
  primarySwatch: Colors.purple,
  accentColor: Colors.orange[400],
);

void main() async{

  runApp(
    ChatApp()
  );
}


final googleSignIn = GoogleSignIn();
final auth = FirebaseAuth.instance;

Future<Null> _ensureLoggedIn() async{
  var user = googleSignIn.currentUser;

  if(user == null)
    user = await googleSignIn.signInSilently();
  if(user == null)
    user = await googleSignIn.signIn();

  if(await auth.currentUser() == null){
    var credentials = await googleSignIn.currentUser.authentication;
    await auth.signInWithGoogle(
        idToken: credentials.idToken,
        accessToken: credentials.accessToken);
  }
}

_handleTextSubmit(text) async{
  if(text == "" || text == null) return;
  await _ensureLoggedIn();
  _sendMessage(text: text);
}

_handleImageSubmit(image) async{
  if(image == null) return;
  StorageUploadTask task = await FirebaseStorage
      .instance
      .ref()
      .child('photos')
      .child(googleSignIn.currentUser.id.toLowerCase() + DateTime.now().millisecondsSinceEpoch.toString())
      .putFile(image);

  var url = await (await task.onComplete).ref.getDownloadURL();
  var imageUrl = url.toString();

  _sendMessage(imageUrl: imageUrl);
}

_pickImageFrom(from) async{
  return await ImagePicker.pickImage(source: from);
}

_sendMessage({String text, String imageUrl}){
  Firestore.instance.collection("messages").add({
    "text": text,
    "imageUrl": imageUrl,
    "author": googleSignIn.currentUser.displayName,
    "authorAvatarUrl": googleSignIn.currentUser.photoUrl,
    "createdAt": DateTime.now()
  });
}

class ChatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Flutter Chat",
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context).platform == TargetPlatform.iOS ? iosTheme : defaultTheme,
      home: ChatView(),
    );
  }
}



class ChatView extends StatefulWidget {
  @override
  _ChatViewState createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {

  final _inputController = TextEditingController();
  final _focusNode = FocusNode();

  _reset(){
    _inputController.text = "";
    _focusNode.requestFocus();
  }
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text("Flutter Chat"),
          centerTitle: true,
          elevation: Theme.of(context).platform == TargetPlatform.iOS ? 0 : 4,
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: StreamBuilder(
                  stream: Firestore.instance.collection("messages").snapshots(),
                  builder: (context, snapshot){
                    switch(snapshot.connectionState){
                      case ConnectionState.none:
                      case ConnectionState.waiting:
                        return Center(
                          child: CircularProgressIndicator(),
                        );
                      default:
                        return ListView.builder(
                            reverse: true,
                            itemCount: snapshot.data.documents.length,
                            itemBuilder: (context, index){
                              List l = snapshot.data.documents.reversed.toList();
                              return ChatMessage(l[index]);
                            }
                        );
                    }
                  }),
            ),
            Divider(
              height: 1,
            ),
            IconTheme(
              data: IconThemeData(color: Theme.of(context).accentColor),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 8),
                color: Theme.of(context).cardColor ,
                child: Row(
                  children: <Widget>[
                    IconButton(
                      icon: Icon(Icons.photo_camera),
                      onPressed: () async {
                        _ensureLoggedIn();
                        File file = await _showImageSourceOptions(context);
                      },
                    ),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration.collapsed(
                          hintText: "Digite sua Mensagem..."
                        ),
                        controller: _inputController,
                        onSubmitted: (text){
                          _handleTextSubmit(text);
                          _reset();
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send),
                      onPressed: () {
                        _handleTextSubmit(_inputController.text);
                        _reset();
                      },
                    )
                  ],
                )
              ),
            )
          ],
        ),
      ),
    );
  }

  _showImageSourceOptions(context){
    showModalBottomSheet(
        context: context,
        builder: (context){
          return BottomSheet(
            onClosing: (){},
            builder: (context){
              return Container(
                padding: EdgeInsets.all(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.all(15),
                      child: FlatButton(
                        onPressed: () async{
                          Navigator.of(context).pop();
                          File file = await _pickImageFrom(ImageSource.gallery);
                          _handleImageSubmit(file);
                        },
                        child: Text("Imagem da Galeria", style: TextStyle(fontSize:24, color: Colors.blue),),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(15),
                      child: FlatButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          File file = await _pickImageFrom(ImageSource.camera);
                          _handleImageSubmit(file);
                        },
                        child: Text("Tirar Foto", style: TextStyle(fontSize:24, color: Colors.blue),),
                      ),
                    )
                  ],
                ),
              );
            },
          );
        });
  }


}


class ChatMessage extends StatelessWidget {

  dynamic _data;

  ChatMessage(this._data);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: EdgeInsets.only(right: 10),
            child: CircleAvatar(
              backgroundImage: NetworkImage(_data['authorAvatarUrl'] ?? ""),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(_data['author'],
                  style: Theme.of(context).textTheme.subhead),
                Container(
                  margin: EdgeInsets.only(top: 5),
                  child: _data['imageUrl'] != null
                      ? Image.network(_data['imageUrl'], height: 250, width: 250)
                      : Text(_data['text'])
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

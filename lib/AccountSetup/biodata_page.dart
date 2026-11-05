import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mango/Models/cloud/user_services.dart';
import 'package:mango/constants.dart';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:math';

import 'add_description.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class BioDataPage extends StatefulWidget {
  const BioDataPage({super.key});

  @override
  _BioDataPageState createState() => _BioDataPageState();
}

class _BioDataPageState extends State<BioDataPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController displayNameController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  var userCollection = FirebaseFirestore.instance.collection('users');
  String? _selectedValue;
  List<String> listOfValue = ['male', 'female'];
  String name = '';
  String displayName = '';
  String bio = '';
  String gender = '';

  final UserService _userService = UserService();

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              height: size.height,
              width: size.width,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(),
                    ),
                    const Text(
                      "How\nfar\nna?",
                      style: splashText,
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    const Text(
                      "Let's setup your user account.",
                      style: textBoxText,
                    ),
                    const SizedBox(
                      height: 70,
                    ),
                    Container(
                      padding: const EdgeInsets.only(left: 15),
                      alignment: Alignment.center,
                      height: 60,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: MangoPalette.black,
                            width: 2,
                          )),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(right: 10.0),
                            child: Text(
                              "@",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              style: postTextBoxText2,
                              maxLines: 3,
                              controller: usernameController,
                              decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  focusColor: MangoPalette.green500,
                                  hintText: 'username',
                                  hintStyle: postTextBoxHint),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15,),
                    Container(
                      padding: const EdgeInsets.only(left: 15),
                      alignment: Alignment.center,
                      height: 60,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: MangoPalette.black,
                            width: 2,
                          )),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(right: 10.0),
                            child: Icon(
                              Icons.person,
                              size: 20,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              style: postTextBoxText2,
                              controller: displayNameController,
                              decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  focusColor: MangoPalette.green500,
                                  hintText: 'Full name',
                                  hintStyle: postTextBoxHint),
                            ),
                          ),

                        ],
                      ),
                    ),

                    const SizedBox(height: 15,),

                    Container(
                      padding: const EdgeInsets.only(left: 15),
                      alignment: Alignment.center,
                      height: 60,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: MangoPalette.black,
                            width: 2,
                          )),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: Icon(
                              Icons.female,
                              size: 20,
                            ),
                          ),
                          Expanded(
                            child:  Padding(
                              padding: const EdgeInsets.only(right: 30.0),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButtonFormField(
                                  decoration: const InputDecoration(
                                      enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(color: Colors.white),),
                                  ),
                                  value: _selectedValue,
                                  hint: const Text(
                                    'choose one',
                                    style: postTextBoxText2,
                                  ),
                                  isExpanded: true,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedValue = value.toString();
                                    });
                                  },
                                  onSaved: (value) {
                                    setState(() {
                                      _selectedValue = value.toString();
                                    });
                                  },
                                  validator: (String? value) {
                                    if (value!.isEmpty) {
                                      return "can't empty";
                                    } else {
                                      return null;
                                    }
                                  },
                                  items: listOfValue
                                      .map((String val) {
                                    return DropdownMenuItem(
                                      value: val,
                                      child: Text(
                                        val,
                                        style: postTextBoxText2,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 45,),
                    TextButton(
                      autofocus: true,
                      onPressed: () async {
                        await _userService.updateProfile(displayNameController.text.trim(), usernameController.text.trim(), bio, _selectedValue!);
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const AddDetails()));
                      },
                      style: ButtonStyle(
                        shape: MaterialStateProperty.all<
                            RoundedRectangleBorder>(
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(
                                  28.0),
                            )),
                        padding:
                        MaterialStateProperty.all(
                            const EdgeInsets
                                .symmetric(
                                vertical: 10.0,
                                horizontal: 20.0)),
                        backgroundColor:
                        MaterialStateProperty.all<
                            Color>(MangoPalette.black),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          Icons.skip_next,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(
                          width: 5.0,
                        ),
                        Text(
                          "Next",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 24),
                        ),
                        SizedBox(
                          width: 10.0,
                        ),
                      ]),
                    )
                  ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<File> urlToFile(String imageUrl) async {

    var rng = Random();

    Directory tempDir = await getTemporaryDirectory();

    String tempPath = tempDir.path;

    File file = File('$tempPath${rng.nextInt(100)}.png');

    http.Response response = await	http.get(Uri.parse(imageUrl));

    await file.writeAsBytes(response.bodyBytes);


    return file;
  }

}



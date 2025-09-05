import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:app/src/rust/api.dart';  // Updated import path
import 'package:app/src/rust/frb_generated.dart';  // Updated import path
import 'package:dmrtd/dmrtd.dart';
import 'package:dmrtd/extensions.dart';
import 'package:dmrtd/internal.dart';
import 'package:dmrtd/src/proto/can_key.dart';
import 'package:dmrtd/src/proto/ecdh_pace.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

class MrtdData {
  EfCardAccess? cardAccess;
  EfCOM? com;
  EfSOD? sod;
  EfDG1? dg1;
  EfDG15? dg15;
  bool? isPACE;
  bool? isDBA;
}

void main() async {
  // Initialize the bridge
  // final dylib = _loadDylib();

  await RustLib.init();

  runApp(const MyApp());
}

// Helper function to load the proper library based on platform
// DynamicLibrary _loadDylib() {
//   if (Platform.isAndroid) {
//     return DynamicLibrary.open('librust_lib_app.so');
//   } else if (Platform.isIOS) {
//     // On iOS, the library is statically linked, so we use process() instead of open()
//     return DynamicLibrary.process();
//   } else if (Platform.isMacOS) {
//     return DynamicLibrary.process();
//   } else if (Platform.isWindows) {
//     return DynamicLibrary.open('native.dll');
//   } else if (Platform.isLinux) {
//     return DynamicLibrary.open('librust_lib_app.so');
//   }
  
//   throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
// }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POC: age verification',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'POC: age verification'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  var _isGeneratingProof = false;
  var _proofMessage = "";
  var _message = "";
  final _log = Logger("mrtdeg.app");
  var _isNfcAvailable = false;
  var _isReading = false;
  final _mrzData = GlobalKey<FormState>();
  final _canData = GlobalKey<FormState>();

  // mrz data
  final _docNumber = TextEditingController();
  final _dob = TextEditingController(); // date of birth
  final _doe = TextEditingController();
  final _can = TextEditingController();
  bool _checkBoxPACE = false;

  MrtdData? _mrtdData;

  final NfcProvider _nfc = NfcProvider();

  late Timer _timerStateUpdater;
  final _scrollController = ScrollController();
  late final TabController _tabController;

  Future<void> _callRustProve() async {
    setState(() {
      _message = "Generating proof";
      _isGeneratingProof = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final schemePath = await _getAssetPath('assets/noir-proof-scheme.nps');
      final inputPath = await _getAssetPath('assets/Prover.toml');
      final proofPath = '${directory.path}/noir-proof.np';
      final tmpDirPath = await getApplicationCacheDirectory();

      // Call the Rust function
      final result = await prove(
        schemePath: schemePath,
        inputPath: inputPath,
        proofPath: proofPath,
        tmpDirPath: tmpDirPath.path,
        sod: _isNfcAvailable ? _mrtdData!.sod!.toBytes() : [],
        dg1: _isNfcAvailable ? _mrtdData!.dg1!.toBytes() : [],
      );

      setState(() {
        _message = result;
        _isGeneratingProof = false;
      });
    } catch (e) {
      setState(() {
        _message = "Error: $e";
        _isGeneratingProof = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _initPlatformState();

    // Update platform state every 3 sec
    _timerStateUpdater = Timer.periodic(Duration(seconds: 3), (Timer t) {
      _initPlatformState();
    });
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> _initPlatformState() async {
    bool isNfcAvailable;
    try {
      NfcStatus status = await NfcProvider.nfcStatus;
      isNfcAvailable = status == NfcStatus.enabled;
    } on PlatformException {
      isNfcAvailable = false;
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _isNfcAvailable = isNfcAvailable;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Material(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _buildPassportWidget(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper function to get an asset as a file with a real path
  Future<String> _getAssetPath(String assetPath) async {
    // Get temporary directory
    final directory = await getTemporaryDirectory();

    // Extract filename from asset path
    final filename = assetPath.split('/').last;
    final filePath = '${directory.path}/$filename';

    // Load asset
    final byteData = await rootBundle.load(assetPath);

    // Write to file
    final file = File(filePath);
    await file.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        )
    );

    return filePath;
  }

  DateTime? _getDOBDate() {
    if (_dob.text.isEmpty) {
      return null;
    }
    return DateFormat.yMd().parse(_dob.text);
  }

  DateTime? _getDOEDate() {
    if (_doe.text.isEmpty) {
      return null;
    }
    return DateFormat.yMd().parse(_doe.text);
  }

  Future<String?> _pickDate(BuildContext context, DateTime firstDate,
      DateTime initDate, DateTime lastDate) async {
    final locale = Localizations.localeOf(context);
    final DateTime? picked = await showDatePicker(
        context: context,
        firstDate: firstDate,
        initialDate: initDate,
        lastDate: lastDate,
        locale: locale);

    if (picked != null) {
      return DateFormat.yMd().format(picked);
    }
    return null;
  }

  bool _disabledPassportInput() {
    //return true;
    return _isReading || !_isNfcAvailable;
  }

  Widget _buildPassportWidget(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildForm(context),
        SizedBox(height: 20),
        PlatformElevatedButton(
          // btn Read MRTD
          onPressed: _buttonPressed,
          child: PlatformText(
              _isReading ? 'Reading ...' : 'Read Passport'),
        ),
        SizedBox(height: 20),
        Row(children: <Widget>[
          Text('NFC available:',
              style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold)),
          SizedBox(width: 4),
          Text(_isNfcAvailable ? "Yes" : "No",
              style: TextStyle(fontSize: 18.0))
        ]),
        SizedBox(height: 15),
        Text(_message,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15.0,
                fontWeight: FontWeight.bold)),
        SizedBox(height: 15),
        _isGeneratingProof
            ? const CircularProgressIndicator()
            : Text(
              _proofMessage,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
        SizedBox(height: 15),
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                    _mrtdData != null
                        ? "Passport Data:"
                        : "",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.bold)),
                Padding(
                    padding: EdgeInsets.only(
                        left: 16.0, top: 8.0, bottom: 8.0),
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: _mrtdDataWidgets()))
              ]),
        ),
      ]
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(children: <Widget>[
      TabBar(
        controller: _tabController,
        labelColor: Colors.blue,
        tabs: const <Widget>[
          Tab(text: 'DBA'),
          Tab(text: 'PACE'),
        ],
      ),
      Container(
        height: 350,
        child: TabBarView(
          controller: _tabController,
          children: <Widget>[
            Card(
              borderOnForeground: false,
              elevation: 0,
              color: Colors.white,
              //shadowColor: Colors.white,
              margin: const EdgeInsets.all(16.0),
              child: Form(
                key: _mrzData,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                      enabled: !_disabledPassportInput(),
                      controller: _docNumber,
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Passport number',
                          fillColor: Colors.white),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]+')),
                        LengthLimitingTextInputFormatter(14)
                      ],
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.characters,
                      autofocus: true,
                      validator: (value) {
                        if (value?.isEmpty ?? false) {
                          return 'Please enter passport number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      enabled: !_disabledPassportInput(),
                      controller: _dob,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Date of Birth',
                        fillColor: Colors.white),
                      autofocus: false,
                      validator: (value) {
                        if (value?.isEmpty ?? false) {
                          return 'Please select Date of Birth';
                        }
                        return null;
                      },
                      onTap: () async {
                        FocusScope.of(context).requestFocus(FocusNode());
                        // Can pick date which dates 15 years back or more
                        final now = DateTime.now();
                        final firstDate =
                            DateTime(now.year - 90, now.month, now.day);
                        final lastDate =
                            DateTime(now.year - 15, now.month, now.day);
                        final initDate = _getDOBDate();
                        final date = await _pickDate(context, firstDate,
                            initDate ?? lastDate, lastDate);

                        FocusScope.of(context).requestFocus(FocusNode());
                        if (date != null) {
                          _dob.text = date;
                        }
                      }
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      enabled: !_disabledPassportInput(),
                      controller: _doe,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Date of Expiry',
                        fillColor: Colors.white),
                      autofocus: false,
                      validator: (value) {
                        if (value?.isEmpty ?? false) {
                          return 'Please select Date of Expiry';
                        }
                        return null;
                      },
                      onTap: () async {
                        FocusScope.of(context).requestFocus(FocusNode());
                        // Can pick date from tomorrow and up to 10 years
                        final now = DateTime.now();
                        final firstDate =
                            DateTime(now.year, now.month, now.day + 1);
                        final lastDate =
                            DateTime(now.year + 10, now.month + 6, now.day);
                        final initDate = _getDOEDate();
                        final date = await _pickDate(context, firstDate,
                            initDate ?? firstDate, lastDate);

                        FocusScope.of(context).requestFocus(FocusNode());
                        if (date != null) {
                          _doe.text = date;
                        }
                      }
                    ),
                    SizedBox(height: 12),
                    CheckboxListTile(
                      title: Text('DBA with PACE'),
                      value: _checkBoxPACE,
                      onChanged: (newValue) {
                        setState(() {
                          _checkBoxPACE = !_checkBoxPACE;
                        });
                      },
                    )
                  ],
                ),
              ),
            ),
            Card(
              borderOnForeground: false,
              elevation: 0,
              color: Colors.white,
              //shadowColor: Colors.white,
              margin: const EdgeInsets.all(16.0),
              child: Form(
                key: _canData,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                      enabled: !_disabledPassportInput(),
                      controller: _can,
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'CAN number',
                          fillColor: Colors.white),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]+')),
                        LengthLimitingTextInputFormatter(6)
                      ],
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.characters,
                      autofocus: true,
                      validator: (value) {
                        if (value?.isEmpty ?? false) {
                          return 'Please enter CAN number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            )
          ]
        )
      )
    ]);
  }

  Widget _makeMrtdAccessDataWidget(
      {required String header,
        required String collapsedText,
        required bool isPACE,
        required bool isDBA}) {
    return ExpandablePanel(
        theme: const ExpandableThemeData(
          headerAlignment: ExpandablePanelHeaderAlignment.center,
          tapBodyToCollapse: true,
          hasIcon: true,
          iconColor: Colors.red,
        ),
        header: Text(header),
        collapsed: Text(collapsedText,
            softWrap: true, maxLines: 2, overflow: TextOverflow.ellipsis),
        expanded: Container(
            padding: const EdgeInsets.all(18),
            color: Color.fromARGB(255, 239, 239, 239),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Access protocol: ${isPACE ? "PACE" : "BAC"}',
                    //style: TextStyle(fontSize: 16.0),
                  ),
                  SizedBox(height: 8.0),
                  Text(
                    'Access key type: ${isDBA ? "DBA" : "CAN"}',
                    //style: TextStyle(fontSize: 16.0),
                  )
                ])));
  }

  Widget _makeMrtdDataWidget(
      {required String header,
      required String collapsedText,
      required dataText}) {
    return ExpandablePanel(
        theme: const ExpandableThemeData(
          headerAlignment: ExpandablePanelHeaderAlignment.center,
          tapBodyToCollapse: true,
          hasIcon: true,
          iconColor: Colors.red,
        ),
        header: Text(header),
        collapsed: Text(collapsedText,
            softWrap: true, maxLines: 2, overflow: TextOverflow.ellipsis),
        expanded: Container(
            padding: const EdgeInsets.all(18),
            color: Color.fromARGB(255, 239, 239, 239),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PlatformTextButton(
                    child: Text('Copy'),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: dataText)),
                    padding: const EdgeInsets.all(8),
                  ),
                  SelectableText(dataText, textAlign: TextAlign.left)
                ])));
  }

  List<Widget> _mrtdDataWidgets() {
    List<Widget> list = [];
    if (_mrtdData == null) return list;

    if (_mrtdData!.isPACE != null && _mrtdData!.isDBA != null)
      list.add(_makeMrtdAccessDataWidget(
          header: "Access protocol",
          collapsedText: '',
          isDBA: _mrtdData!.isDBA!,
          isPACE: _mrtdData!.isPACE!));

    if (_mrtdData!.sod != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.SOD',
          collapsedText: '',
          dataText: _mrtdData!.sod!.toBytes().hex()));
    }

    if (_mrtdData!.com != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.COM',
          collapsedText: '',
          dataText: formatEfCom(_mrtdData!.com!)));
    }

    if (_mrtdData!.dg1 != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.DG1',
          collapsedText: '',
          dataText: _mrtdData!.dg1!.toBytes().hex()));
    }

    if (_mrtdData!.dg15 != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.DG15',
          collapsedText: '',
          dataText: _mrtdData!.dg15!.toBytes().hex()));
    }

    return list;
  }

  void _buttonPressed() async {
      //Check on what tab we are
      if (_tabController.index == 0) {
        if (!_isNfcAvailable) {
          _callRustProve();
          return;
        }
        //DBA tab
        String errorText = "";
        if (_doe.text.isEmpty) {
          errorText += "Please enter date of expiry!\n";
        }
        if (_dob.text.isEmpty) {
          errorText += "Please enter date of birth!\n";
        }
        if (_docNumber.text.isEmpty) {
          errorText += "Please enter passport number!";
        }

        setState(() {
          _message = errorText;
        });
        //If there is an error, just jump out of the function
        if (errorText.isNotEmpty) return;

        final bacKeySeed = DBAKey(_docNumber.text, _getDOBDate()!, _getDOEDate()!, paceMode: _checkBoxPACE);
        _readMRTD(accessKey: bacKeySeed, isPace: _checkBoxPACE);
      } else {
        //PACE tab
        String errorText = "";
        if (_can.text.isEmpty) {
            errorText = "Please enter CAN number!";
        }
        else if (_can.text.length != 6) {
          errorText = "CAN number must be exactly 6 digits long!";
        }

        setState(() {
          _message = errorText;
        });
        //If there is an error, just jump out of the function
        if (errorText.isNotEmpty) return;

        final canKeySeed = CanKey(_can.text);
        _readMRTD(accessKey: canKeySeed, isPace: true);
      }

  }

  void _readMRTD({required AccessKey accessKey, bool isPace = false}) async {
    try {
      setState(() {
        _mrtdData = null;
        _message = "Waiting for Passport tag ...";
        _isReading = true;
      });
      try {
        await _nfc.connect(iosAlertMessage: "Hold your phone near Biometric Passport");

        final passport = Passport(_nfc);
        final mrtdData = MrtdData();

        setState(() {
          _message = "Reading Passport ...";
        });

        _nfc.setIosAlertMessage("Trying to read EF.CardAccess ...");

        try {
          mrtdData.cardAccess = await passport.readEfCardAccess();
        } on PassportError {
          //if (e.code != StatusWord.fileNotFound) rethrow;
        }

        _nfc.setIosAlertMessage("Initiating session with PACE...");
        //set MrtdData
        mrtdData.isPACE = isPace;
        mrtdData.isDBA = accessKey.PACE_REF_KEY_TAG == 0x01 ? true : false;

        if (isPace) {
          //PACE session
          await passport.startSessionPACE(accessKey, mrtdData.cardAccess!);
        } else {
          //BAC session
          await passport.startSession(accessKey as DBAKey);
        }

        _nfc.setIosAlertMessage(formatProgressMsg("Reading EF.COM ...", 0));
        mrtdData.com = await passport.readEfCOM();

        _nfc.setIosAlertMessage(
            formatProgressMsg("Reading Data Groups ...", 20));

        if (mrtdData.com!.dgTags.contains(EfDG1.TAG)) {
          mrtdData.dg1 = await passport.readEfDG1();
        }

        if (mrtdData.com!.dgTags.contains(EfDG15.TAG)) {
          mrtdData.dg15 = await passport.readEfDG15();
        }

        _nfc.setIosAlertMessage(formatProgressMsg("Reading EF.SOD ...", 80));
        mrtdData.sod = await passport.readEfSOD();

        setState(() {
          _mrtdData = mrtdData;
        });

        setState(() {
          _message = "";
        });

        _scrollController.animateTo(300.0,
            duration: Duration(milliseconds: 500), curve: Curves.ease);

        _callRustProve();
      } on Exception catch (e) {
        final se = e.toString().toLowerCase();
        String alertMsg = "An error has occurred while reading Passport!";
        if (e is PassportError) {
          if (se.contains("security status not satisfied")) {
            alertMsg =
                "Failed to initiate session with passport.\nCheck input data!";
          }
          _log.error("PassportError: ${e.message}");
        } else {
          _log.error(
              "An exception was encountered while trying to read Passport: $e");
        }

        if (se.contains('timeout')) {
          alertMsg = "Timeout while waiting for Passport tag";
        } else if (se.contains("tag was lost")) {
          alertMsg = "Tag was lost. Please try again!";
        } else if (se.contains("invalidated by user")) {
          alertMsg = "";
        }

        setState(() {
          _message = alertMsg;
        });
      } finally {
        if (_message.isNotEmpty) {
          await _nfc.disconnect(iosErrorMessage: _message);
        } else {
          await _nfc.disconnect(
              iosAlertMessage: formatProgressMsg("Finished", 100));
        }
        setState(() {
          _isReading = false;
        });
      }
    } on Exception catch (e) {
      _log.error("Read MRTD error: $e");
    }
  }

  String formatEfCom(final EfCOM efCom) {
    final Map<DgTag, String> dgTagToString = {
      EfDG1.TAG: 'EF.DG1',
      EfDG2.TAG: 'EF.DG2',
      EfDG3.TAG: 'EF.DG3',
      EfDG4.TAG: 'EF.DG4',
      EfDG5.TAG: 'EF.DG5',
      EfDG6.TAG: 'EF.DG6',
      EfDG7.TAG: 'EF.DG7',
      EfDG8.TAG: 'EF.DG8',
      EfDG9.TAG: 'EF.DG9',
      EfDG10.TAG: 'EF.DG10',
      EfDG11.TAG: 'EF.DG11',
      EfDG12.TAG: 'EF.DG12',
      EfDG13.TAG: 'EF.DG13',
      EfDG14.TAG: 'EF.DG14',
      EfDG15.TAG: 'EF.DG15',
      EfDG16.TAG: 'EF.DG16'
    };

    var str = "version: ${efCom.version}\n"
        "unicode version: ${efCom.unicodeVersion}\n"
        "DG tags:";

    for (final t in efCom.dgTags) {
      try {
        str += " ${dgTagToString[t]!}";
      } catch (e) {
        str += " 0x${t.value.toRadixString(16)}";
      }
    }
    return str;
  }

  String formatProgressMsg(String message, int percentProgress) {
    final p = (percentProgress / 20).round();
    final full = "🟢 " * p;
    final empty = "⚪️ " * (5 - p);
    return message + "\n\n" + full + empty;
  }
}
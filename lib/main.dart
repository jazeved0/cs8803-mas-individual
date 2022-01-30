import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

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
        brightness: Brightness.light,
        /* light theme settings */
        primarySwatch: Colors.purple,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        /* dark theme settings */
        primarySwatch: Colors.lightBlue,
        accentColor: Colors.purple,
      ),
      themeMode: ThemeMode.light,
      home: const MyHomePage(
        title: 'Weather App',
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class Weather {
  final String city;
  final double temp;
  final double minTemp;
  final double maxTemp;
  final String weather;
  final Uri weatherIconUrl;
  const Weather(
      {required this.city,
      required this.temp,
      required this.minTemp,
      required this.maxTemp,
      required this.weather,
      required this.weatherIconUrl});
}

enum Temperature {
  fahrenheit,
  celcius,
  kelvin,
}

class _MyHomePageState extends State<MyHomePage> {
  Future<Weather>? _currentWeather;
  Temperature _temperature = Temperature.fahrenheit;

  @override
  void initState() {
    super.initState();
    _currentWeather = _getWeather();
  }

  Future<Weather> _getWeather() async {
    // Handle exceptions and wrap them as Future errors
    try {
      return await _getWeatherInternal();
    } catch (e) {
      return Future.error(e.toString());
    }
  }

  Future<Weather> _getWeatherInternal() async {
    var position = await _determinePosition();

    // Use wrapper around OpenWeatherMap API
    var url = Uri.parse(
        'https://us-central1-jazev-w-app.cloudfunctions.net/getWeather?latitude=${position.latitude}&longitude=${position.longitude}&temp_unit=kelvin');
    var response = await http.get(url, headers: {"Accept": "application/json"});
    var jsonData = json.decode(response.body);

    if (response.statusCode == 200) {
      return Weather(
          city: jsonData["city"],
          temp: jsonData["temp"],
          minTemp: jsonData["min_temp"],
          maxTemp: jsonData["max_temp"],
          weather: jsonData["weather"],
          weatherIconUrl: Uri.parse(jsonData["weather_icon_url"]));
    } else if (response.statusCode >= 400 && response.statusCode < 600) {
      return Future.error(jsonData["message"]);
    } else {
      return Future.error("unknown response received");
    }
  }

  // Copied from geolocator's README:
  //https://pub.dev/packages/geolocator
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }

  double _convertTemperature(double kelvin) {
    if (_temperature == Temperature.kelvin) {
      return kelvin;
    } else if (_temperature == Temperature.celcius) {
      return kelvin - 273.15;
    } else {
      return (kelvin - 273.15) * (9 / 5) + 32;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <
                Widget>[
          Text(widget.title),
          IconButton(
            iconSize: 24,
            icon: const Icon(Icons.settings),
            onPressed: () async {
              var currentMode = _temperature;
              var newMode = await showDialog<Temperature>(
                  context: context,
                  builder: (BuildContext context) {
                    Temperature? selectedRatio = currentMode;
                    return AlertDialog(
                      title: const Text("Change temperature unit"),
                      content: StatefulBuilder(
                        builder: (BuildContext context, StateSetter setState) {
                          return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                ListTile(
                                  title: const Text('Fahrenheit'),
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 0),
                                  visualDensity: VisualDensity.compact,
                                  leading: Radio<Temperature>(
                                    value: Temperature.fahrenheit,
                                    groupValue: selectedRatio,
                                    onChanged: (Temperature? value) {
                                      setState(() => selectedRatio = value);
                                    },
                                  ),
                                ),
                                ListTile(
                                  title: const Text('Celcius'),
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 0),
                                  visualDensity: VisualDensity.compact,
                                  leading: Radio<Temperature>(
                                    value: Temperature.celcius,
                                    groupValue: selectedRatio,
                                    onChanged: (Temperature? value) {
                                      setState(() => selectedRatio = value);
                                    },
                                  ),
                                ),
                                ListTile(
                                  title: const Text('Kelvin'),
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 0),
                                  visualDensity: VisualDensity.compact,
                                  leading: Radio<Temperature>(
                                    value: Temperature.kelvin,
                                    groupValue: selectedRatio,
                                    onChanged: (Temperature? value) {
                                      setState(() => selectedRatio = value);
                                    },
                                  ),
                                ),
                              ]);
                        },
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CANCEL'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, selectedRatio),
                          child: const Text('CONFIRM'),
                        ),
                      ],
                    );
                  });

              setState(() {
                if (newMode != null) {
                  _temperature = newMode;
                }
              });
            },
          )
        ]),
      ),
      body: FutureBuilder<Weather>(
        future: _currentWeather,
        builder: (BuildContext context, AsyncSnapshot<Weather> snapshot) {
          var error = snapshot.error;
          var data = snapshot.data;
          if (error != null) {
            // There was an error
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.error),
                        title: const Text('An error occurred'),
                        subtitle: Text(error.toString()),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else if (data != null) {
            // Data has loaded successfully
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CachedNetworkImage(
                        imageUrl: data.weatherIconUrl.toString(),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.transparent,
                        ),
                        height: 200,
                        width: 200,
                      ),
                      Text(
                        data.city,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 30),
                      ),
                      Text(
                        "${_convertTemperature(data.temp).round()}°",
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w200, fontSize: 80),
                      ),
                      Text(
                        data.weather,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "H:${_convertTemperature(data.maxTemp).round()}° L:${_convertTemperature(data.minTemp).round()}°",
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ],
                  ),
                ],
              ),
            );
          } else {
            // Still loading
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }
}

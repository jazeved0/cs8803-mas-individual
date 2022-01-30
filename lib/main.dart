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
      themeMode: ThemeMode.dark,
      home: const MyHomePage(
        title: 'Weather App',
        openWeatherApiKey: "db0ab04a0e5898f7489adfa40bc08c29",
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage(
      {Key? key, required this.title, required this.openWeatherApiKey})
      : super(key: key);

  final String title;
  final String openWeatherApiKey;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class Weather {
  final String city;
  final double actualTemp;
  final double minTemp;
  final double maxTemp;
  final String weather;
  final Uri weatherIcon;
  const Weather(
      {required this.city,
      required this.actualTemp,
      required this.minTemp,
      required this.maxTemp,
      required this.weather,
      required this.weatherIcon});
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

    // Using geo current weather API:
    // https://openweathermap.org/current#geo
    var url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=${widget.openWeatherApiKey}');
    print(url.toString());
    var response = await http.get(url);
    var jsonData = json.decode(response.body);

    if (response.statusCode == 200) {
      // Shape of JSON data from:
      // https://openweathermap.org/current#current_JSON
      List<dynamic> weatherList = jsonData["weather"];
      if (weatherList.isEmpty) {
        return Future.error("No weather conditions returned from API");
      }

      return Weather(
        city: jsonData["name"],
        actualTemp: jsonData["main"]["temp"],
        minTemp: jsonData["main"]["temp_min"],
        maxTemp: jsonData["main"]["temp_max"],
        weather: weatherList[0]["main"],
        weatherIcon: Uri.parse(
            "http://openweathermap.org/img/wn/${weatherList[0]["icon"]}@4x.png"),
      );
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
                          style: TextButton.styleFrom(primary: Colors.white),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, selectedRatio),
                          child: const Text('CONFIRM'),
                          style: TextButton.styleFrom(primary: Colors.white),
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
                        imageUrl: data.weatherIcon.toString(),
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
                        "${_convertTemperature(data.actualTemp).round()}°",
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

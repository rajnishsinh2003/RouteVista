import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  bool _isLoading = true;
  String _city = '';
  double _temp = 0;
  String _condition = '';
  double _windSpeed = 0;
  int _humidity = 0;
  String _errorMessage = '';
  List<Map<String, dynamic>> _hourlyForecast = [];

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      // Get city name
      try {
        final geoUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${pos.latitude}&lon=${pos.longitude}&format=json',
        );
        final geoRes = await http.get(geoUrl, headers: {'User-Agent': 'RouteVista'});
        if (geoRes.statusCode == 200) {
          final geoData = json.decode(geoRes.body);
          _city = geoData['address']?['city'] ??
              geoData['address']?['town'] ??
              geoData['address']?['village'] ??
              'Your Location';
        }
      } catch (_) {
        _city = 'Your Location';
      }

      // Get weather
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${pos.latitude}&longitude=${pos.longitude}&current_weather=true&hourly=temperature_2m,relativehumidity_2m,windspeed_10m&forecast_days=1',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final current = data['current_weather'];
        final hourly = data['hourly'];

        List<Map<String, dynamic>> forecast = [];
        if (hourly != null) {
          final times = hourly['time'] as List;
          final temps = hourly['temperature_2m'] as List;
          for (int i = 0; i < times.length && i < 24; i++) {
            forecast.add({
              'time': times[i].toString().split('T').last,
              'temp': temps[i],
            });
          }
        }

        setState(() {
          _temp = (current['temperature'] as num).toDouble();
          _condition = _getWeatherString(current['weathercode'] as int);
          _windSpeed = (current['windspeed'] as num).toDouble();
          _humidity = hourly?['relativehumidity_2m']?[0] ?? 0;
          _hourlyForecast = forecast;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to fetch weather. Check location and internet.';
        _isLoading = false;
      });
    }
  }

  String _getWeatherString(int code) {
    if (code == 0) return 'Clear Sky ☀️';
    if (code <= 3) return 'Partly Cloudy ⛅';
    if (code <= 49) return 'Foggy 🌫️';
    if (code <= 59) return 'Drizzle 🌦️';
    if (code <= 69) return 'Rain 🌧️';
    if (code <= 79) return 'Snow ❄️';
    if (code <= 82) return 'Heavy Rain 🌧️';
    return 'Thunderstorm ⛈️';
  }

  IconData _getWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny;
    if (code <= 3) return Icons.cloud;
    if (code <= 49) return Icons.foggy;
    if (code <= 79) return Icons.water_drop;
    return Icons.thunderstorm;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Text('Weather', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(_errorMessage, textAlign: TextAlign.center, style: GoogleFonts.poppins()),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() { _isLoading = true; _errorMessage = ''; });
                          _fetchWeather();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Main weather card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D1B2A), Color(0xFF065A60)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF065A60).withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.white70, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  _city,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '${_temp.toStringAsFixed(1)}°C',
                              style: GoogleFonts.poppins(
                                fontSize: 56,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _condition,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Details row
                      Row(
                        children: [
                          Expanded(child: _detailCard('💨 Wind', '${_windSpeed.toStringAsFixed(1)} km/h')),
                          const SizedBox(width: 12),
                          Expanded(child: _detailCard('💧 Humidity', '$_humidity%')),
                          const SizedBox(width: 12),
                          Expanded(child: _detailCard('🌡️ Feels', '${(_temp - 2).toStringAsFixed(0)}°C')),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Hourly forecast
                      if (_hourlyForecast.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Hourly Forecast',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _hourlyForecast.length,
                            itemBuilder: (c, i) {
                              final h = _hourlyForecast[i];
                              return Container(
                                width: 70,
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Theme.of(context).dividerColor),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      h['time'],
                                      style: GoogleFonts.poppins(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                    ),
                                    const SizedBox(height: 4),
                                    const Icon(Icons.thermostat, color: Color(0xFF065A60), size: 20),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(h['temp'] as num).toStringAsFixed(0)}°',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _detailCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

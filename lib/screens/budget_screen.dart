import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/poi.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  double _distance = 100;
  double _duration = 2;
  int _travelers = 1;
  VehicleType _vehicle = VehicleType.car;
  FuelType _fuelType = FuelType.petrol;
  TripBudget? _budget;

  // New Fuel Sufficiency fields
  double _currentFuel = 5.0; // Litres
  double _vehicleAverage = 15.0; // km/L
  Map<String, dynamic>? _fuelStatus;

  @override
  void initState() {
    super.initState();
    _vehicleAverage = VehicleDefaults.mileage(_vehicle);
    _calculate();
  }

  void _calculate() {
    setState(() {
      _budget = BudgetCalculator.calculate(
        distanceKm: _distance,
        durationHrs: _duration,
        vehicle: _vehicle,
        fuelType: _fuelType,
        travelers: _travelers,
      );
      
      _fuelStatus = BudgetCalculator.checkFuelSufficiency(
        currentFuelLitres: _currentFuel,
        vehicleAverage: _vehicleAverage,
        totalDistanceKm: _distance,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF065A60),
        foregroundColor: Colors.white,
        title: Text('Trip Budget Calculator', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Distance slider
            _sectionTitle('Distance (km)'),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _distance,
                    min: 10,
                    max: 2000,
                    divisions: 199,
                    activeColor: const Color(0xFF065A60),
                    label: '${_distance.toInt()} km',
                    onChanged: (v) {
                      _distance = v;
                      _duration = v / 50; // rough estimate
                      _calculate();
                    },
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    '${_distance.toInt()} km',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Vehicle type
            _sectionTitle('Vehicle'),
            Wrap(
              spacing: 8,
              children: VehicleType.values
                  .where((v) => VehicleDefaults.isAvailable(v, _distance))
                  .map((v) => ChoiceChip(
                        label: Text(VehicleDefaults.label(v)),
                        selected: _vehicle == v,
                        onSelected: (_) {
                          _vehicle = v;
                          _vehicleAverage = VehicleDefaults.mileage(v);
                          _calculate();
                        },
                        selectedColor: const Color(0xFF065A60).withOpacity(0.2),
                        labelStyle: GoogleFonts.poppins(
                          fontWeight: _vehicle == v ? FontWeight.w600 : FontWeight.w400,
                          color: _vehicle == v ? const Color(0xFF065A60) : Colors.grey[700],
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // Fuel type
            _sectionTitle('Fuel Type'),
            Wrap(
              spacing: 8,
              children: FuelType.values
                  .map((f) => ChoiceChip(
                        label: Text('${FuelRates.label(f)} (₹${FuelRates.getRate(f).toInt()}/L)'),
                        selected: _fuelType == f,
                        onSelected: (_) {
                          _fuelType = f;
                          _calculate();
                        },
                        selectedColor: const Color(0xFF065A60).withOpacity(0.2),
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: _fuelType == f ? FontWeight.w600 : FontWeight.w400,
                          color: _fuelType == f ? const Color(0xFF065A60) : Colors.grey[700],
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),

            // Fuel Sufficiency Inputs
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fuel Sufficiency Check', 
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _inputField(
                          'Current Fuel (L)', 
                          _currentFuel.toString(),
                          (v) => setState(() {
                            _currentFuel = double.tryParse(v) ?? 0;
                            _calculate();
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _inputField(
                          'Vehicle Avg (km/L)', 
                          _vehicleAverage.toString(),
                          (v) => setState(() {
                            _vehicleAverage = double.tryParse(v) ?? 0;
                            _calculate();
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Budget & Fuel Results
            if (_budget != null) ...[
              _buildBudgetCard(),
              const SizedBox(height: 16),
              if (_fuelStatus != null) _buildFuelSufficiencyCard(),
              const SizedBox(height: 16),
            ],
            
            // Travelers
            _sectionTitle('Travelers'),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (_travelers > 1) {
                      _travelers--;
                      _calculate();
                    }
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                  color: const Color(0xFF065A60),
                ),
                Text(
                  '$_travelers',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: () {
                    _travelers++;
                    _calculate();
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  color: const Color(0xFF065A60),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF065A60)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF065A60).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Estimated Budget',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_budget!.total.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          _budgetDetailRow('⛽ Fuel', _budget!.fuelCost),
          _budgetDetailRow('🍔 Food', _budget!.foodCost),
          _budgetDetailRow('🏨 Accommodation', _budget!.accommodation),
          _budgetDetailRow('🛣️ Tolls', _budget!.tollCharges),
        ],
      ),
    );
  }

  Widget _buildFuelSufficiencyCard() {
    final bool isEnough = _fuelStatus!['is_enough'];
    final bool needsRefuelSoon = _fuelStatus!['needs_refuel_soon'];
    final double range = _fuelStatus!['range_km'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEnough ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnough ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isEnough ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                color: isEnough ? Colors.green[700] : Colors.red[700],
              ),
              const SizedBox(width: 12),
              Text(
                isEnough ? 'Fuel is sufficient' : 'Insufficient Fuel!',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: isEnough ? Colors.green[800] : Colors.red[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Current Range: ${range.toStringAsFixed(0)} km',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[800]),
          ),
          if (!isEnough) ...[
            const SizedBox(height: 4),
            Text(
              'Refill needed: ~${_fuelStatus!['fuel_needed_litres'].toStringAsFixed(1)} Litres',
              style: GoogleFonts.poppins(
                fontSize: 13, 
                fontWeight: FontWeight.w600,
                color: Colors.red[800],
              ),
            ),
          ],
          if (needsRefuelSoon) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_gas_station, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Critical! Range < 50km. Refill immediately.',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.orange[900]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _inputField(String label, String value, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 4),
        TextField(
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: value,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1A1A2E),
        ),
      ),
    );
  }

  Widget _budgetDetailRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70)),
          Text(
            '₹${value.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

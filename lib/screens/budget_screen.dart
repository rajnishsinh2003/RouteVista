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

  @override
  void initState() {
    super.initState();
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
            const SizedBox(height: 8),

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
            const SizedBox(height: 16),

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
            const SizedBox(height: 24),

            // Budget result
            if (_budget != null) ...[
              Container(
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
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${_budget!.total.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 40,
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
              ),
              const SizedBox(height: 16),

              // Additional info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Mileage: ${VehicleDefaults.mileage(_vehicle)} km/L • Duration: ~${_duration.toStringAsFixed(1)} hrs. Budget is an estimate and may vary.',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
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

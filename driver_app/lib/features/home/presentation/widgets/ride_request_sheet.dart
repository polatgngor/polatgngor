import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';

class RideRequestSheet extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const RideRequestSheet({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final distance = request['distance'] ?? '2.5 km'; // Mock or from payload
    final duration = request['duration'] ?? '5 dk';
    final fare = request['estimated_fare'] ?? '₺85';
    final pickup = request['pickup_address'] ?? 'Bilinmeyen Konum';
    final dropoff = request['dropoff_address'] ?? 'Bilinmeyen Varış';

    return Container(
      padding: EdgeInsets.fromLTRB(
        24, 
        24, 
        24, 
        24 + MediaQuery.of(context).viewPadding.bottom
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'sheet.new_request.title'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoColumn(Icons.timer, duration),
              _buildInfoColumn(Icons.directions, distance),
              _buildInfoColumn(Icons.payments, fare),
            ],
          ),
          const SizedBox(height: 16),
          // Payment Method & Options
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChip(
                  label: request['payment_method'] == 'nakit' ? 'sheet.new_request.payment_cash'.tr() : 'sheet.new_request.payment_card'.tr(),
                  color: Colors.blue.shade100,
                  textColor: Colors.blue.shade900,
                  icon: request['payment_method'] == 'nakit' ? Icons.money : Icons.credit_card,
                ),
                if (request['options'] != null && request['options']['taximeter'] == true) ...[
                  const SizedBox(width: 8),
                  _buildChip(
                    label: 'sheet.new_request.option_taximeter'.tr(),
                    color: Colors.orange.shade100,
                    textColor: Colors.orange.shade900,
                    icon: Icons.calculate,
                  ),
                ],
                if (request['options'] != null && request['options']['pet'] == true) ...[
                  const SizedBox(width: 8),
                  _buildChip(
                    label: 'sheet.new_request.option_pet'.tr(),
                    color: Colors.purple.shade100,
                    textColor: Colors.purple.shade900,
                    icon: Icons.pets,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildLocationRow(Icons.my_location, 'ride.pickup'.tr(), pickup),
          const SizedBox(height: 16),
          _buildLocationRow(Icons.location_on, 'ride.dropoff'.tr(), dropoff),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    onReject();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.red, width: 2),
                    foregroundColor: Colors.red,
                  ),
                  child: Text('sheet.new_request.reject'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    onAccept();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: Text('sheet.new_request.accept'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600], size: 28),
        const SizedBox(height: 4),
        Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.amber, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(address, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip({required String label, required Color color, required Color textColor, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

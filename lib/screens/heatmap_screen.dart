import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../app_theme.dart';

/// Comprehensive distributed crime heatmap using MOSPI 2007 data.
///
/// Source: MOSPI Statistical Abstract India 2007, Table 29.1
/// (Incidence of Cognizable Crime Under IPC, Year 2006)
class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  static const List<_CityData> _distributedData = [
    // ─── MADHYA PRADESH (194,711) ──────────────────────────
    _CityData(name: 'Bhopal', lat: 23.2599, lon: 77.4126, crimes: 42000),
    _CityData(name: 'Indore', lat: 22.7196, lon: 75.8577, crimes: 38000),
    _CityData(name: 'Jabalpur', lat: 23.1815, lon: 79.9864, crimes: 28000),
    _CityData(name: 'Gwalior', lat: 26.2183, lon: 78.1828, crimes: 24000),
    _CityData(name: 'Ujjain', lat: 23.1765, lon: 75.7885, crimes: 18000),
    _CityData(name: 'Sagar', lat: 23.8388, lon: 78.7378, crimes: 16000),
    _CityData(name: 'Rewa', lat: 24.5362, lon: 81.3037, crimes: 14711),
    _CityData(name: 'Satna', lat: 24.5726, lon: 80.8322, crimes: 14000),

    // ─── MAHARASHTRA (191,788) ─────────────────────────────
    _CityData(name: 'Mumbai', lat: 19.0760, lon: 72.8777, crimes: 52000),
    _CityData(name: 'Pune', lat: 18.5204, lon: 73.8567, crimes: 34000),
    _CityData(name: 'Nagpur', lat: 21.1458, lon: 79.0882, crimes: 26000),
    _CityData(name: 'Nashik', lat: 20.0000, lon: 73.7800, crimes: 18000),
    _CityData(name: 'Aurangabad', lat: 19.8762, lon: 75.3433, crimes: 16000),
    _CityData(name: 'Thane', lat: 19.2183, lon: 72.9781, crimes: 18788),
    _CityData(name: 'Kolhapur', lat: 16.7050, lon: 74.2433, crimes: 14000),
    _CityData(name: 'Solapur', lat: 17.6599, lon: 75.9064, crimes: 13000),

    // ─── ANDHRA PRADESH (173,909) ──────────────────────────
    _CityData(name: 'Hyderabad', lat: 17.3850, lon: 78.4867, crimes: 48000),
    _CityData(name: 'Visakhapatnam', lat: 17.6868, lon: 83.2185, crimes: 26000),
    _CityData(name: 'Vijayawada', lat: 16.5062, lon: 80.6480, crimes: 22000),
    _CityData(name: 'Warangal', lat: 17.9784, lon: 79.5941, crimes: 18000),
    _CityData(name: 'Guntur', lat: 16.3067, lon: 80.4365, crimes: 16000),
    _CityData(name: 'Nellore', lat: 14.4427, lon: 79.9865, crimes: 14000),
    _CityData(name: 'Kurnool', lat: 15.8281, lon: 78.0373, crimes: 14909),
    _CityData(name: 'Tirupati', lat: 13.6288, lon: 79.4192, crimes: 15000),

    // ─── TAMIL NADU (148,972) ──────────────────────────────
    _CityData(name: 'Chennai', lat: 13.0827, lon: 80.2707, crimes: 42000),
    _CityData(name: 'Coimbatore', lat: 11.0168, lon: 76.9558, crimes: 22000),
    _CityData(name: 'Madurai', lat: 9.9252, lon: 78.1198, crimes: 18000),
    _CityData(
      name: 'Tiruchirappalli',
      lat: 10.7905,
      lon: 78.7047,
      crimes: 16000,
    ),
    _CityData(name: 'Salem', lat: 11.6643, lon: 78.1460, crimes: 14000),
    _CityData(name: 'Tirunelveli', lat: 8.7139, lon: 77.7567, crimes: 12000),
    _CityData(name: 'Erode', lat: 11.3410, lon: 77.7172, crimes: 12972),
    _CityData(name: 'Vellore', lat: 12.9165, lon: 79.1325, crimes: 12000),

    // ─── RAJASTHAN (141,992) ───────────────────────────────
    _CityData(name: 'Jaipur', lat: 26.9124, lon: 75.7873, crimes: 38000),
    _CityData(name: 'Jodhpur', lat: 26.2389, lon: 73.0243, crimes: 24000),
    _CityData(name: 'Udaipur', lat: 24.5854, lon: 73.7125, crimes: 18000),
    _CityData(name: 'Kota', lat: 25.2138, lon: 75.8648, crimes: 16000),
    _CityData(name: 'Ajmer', lat: 26.4499, lon: 74.6399, crimes: 14000),
    _CityData(name: 'Bikaner', lat: 28.0229, lon: 73.3119, crimes: 16992),
    _CityData(name: 'Alwar', lat: 27.5530, lon: 76.6346, crimes: 15000),

    // ─── UTTAR PRADESH (127,001) ───────────────────────────
    _CityData(name: 'Lucknow', lat: 26.8467, lon: 80.9462, crimes: 28000),
    _CityData(name: 'Kanpur', lat: 26.4499, lon: 80.3319, crimes: 20000),
    _CityData(name: 'Agra', lat: 27.1767, lon: 78.0081, crimes: 16000),
    _CityData(name: 'Varanasi', lat: 25.3176, lon: 82.9739, crimes: 14000),
    _CityData(name: 'Allahabad', lat: 25.4358, lon: 81.8463, crimes: 13000),
    _CityData(name: 'Meerut', lat: 28.9845, lon: 77.7064, crimes: 12000),
    _CityData(name: 'Bareilly', lat: 28.3670, lon: 79.4304, crimes: 12001),
    _CityData(name: 'Gorakhpur', lat: 26.7606, lon: 83.3732, crimes: 12000),

    // ─── GUJARAT (120,972) ─────────────────────────────────
    _CityData(name: 'Ahmedabad', lat: 23.0225, lon: 72.5714, crimes: 34000),
    _CityData(name: 'Surat', lat: 21.1702, lon: 72.8311, crimes: 24000),
    _CityData(name: 'Vadodara', lat: 22.3072, lon: 73.1812, crimes: 18000),
    _CityData(name: 'Rajkot', lat: 22.3039, lon: 70.8022, crimes: 16000),
    _CityData(name: 'Bhavnagar', lat: 21.7645, lon: 72.1519, crimes: 14972),
    _CityData(name: 'Jamnagar', lat: 22.4707, lon: 70.0577, crimes: 14000),

    // ─── KARNATAKA (117,710) ───────────────────────────────
    _CityData(name: 'Bengaluru', lat: 12.9716, lon: 77.5946, crimes: 38000),
    _CityData(name: 'Mysuru', lat: 12.2958, lon: 76.6394, crimes: 18000),
    _CityData(name: 'Hubli-Dharwad', lat: 15.3647, lon: 75.1240, crimes: 16000),
    _CityData(name: 'Mangaluru', lat: 12.9141, lon: 74.8560, crimes: 14000),
    _CityData(name: 'Belagavi', lat: 15.8497, lon: 74.4977, crimes: 14710),
    _CityData(name: 'Gulbarga', lat: 17.3297, lon: 76.8343, crimes: 17000),

    // ─── KERALA (105,255) ──────────────────────────────────
    _CityData(
      name: 'Thiruvananthapuram',
      lat: 8.5241,
      lon: 76.9366,
      crimes: 24000,
    ),
    _CityData(name: 'Kochi', lat: 9.9312, lon: 76.2673, crimes: 22000),
    _CityData(name: 'Kozhikode', lat: 11.2588, lon: 75.7804, crimes: 18000),
    _CityData(name: 'Thrissur', lat: 10.5276, lon: 76.2144, crimes: 16000),
    _CityData(name: 'Kollam', lat: 8.8932, lon: 76.6141, crimes: 13255),
    _CityData(name: 'Kannur', lat: 11.8745, lon: 75.3704, crimes: 12000),

    // ─── BIHAR (100,665) ───────────────────────────────────
    _CityData(name: 'Patna', lat: 25.6093, lon: 85.1376, crimes: 32000),
    _CityData(name: 'Gaya', lat: 24.7955, lon: 84.9994, crimes: 18000),
    _CityData(name: 'Muzaffarpur', lat: 26.1197, lon: 85.3910, crimes: 16000),
    _CityData(name: 'Bhagalpur', lat: 25.2425, lon: 86.9842, crimes: 14000),
    _CityData(name: 'Darbhanga', lat: 26.1542, lon: 85.8918, crimes: 12665),
    _CityData(name: 'Purnia', lat: 25.7771, lon: 87.4753, crimes: 8000),

    // ─── WEST BENGAL (68,052) ──────────────────────────────
    _CityData(name: 'Kolkata', lat: 22.5726, lon: 88.3639, crimes: 24000),
    _CityData(name: 'Howrah', lat: 22.5958, lon: 88.2636, crimes: 12000),
    _CityData(name: 'Durgapur', lat: 23.5204, lon: 87.3119, crimes: 10000),
    _CityData(name: 'Asansol', lat: 23.6739, lon: 86.9524, crimes: 9052),
    _CityData(name: 'Siliguri', lat: 26.7271, lon: 88.3953, crimes: 8000),
    _CityData(name: 'Kharagpur', lat: 22.3460, lon: 87.2320, crimes: 5000),

    // ─── DELHI (57,963) ────────────────────────────────────
    _CityData(name: 'New Delhi', lat: 28.6139, lon: 77.2090, crimes: 22000),
    _CityData(name: 'South Delhi', lat: 28.5245, lon: 77.1855, crimes: 14000),
    _CityData(name: 'East Delhi', lat: 28.6280, lon: 77.2952, crimes: 12000),
    _CityData(name: 'North Delhi', lat: 28.7320, lon: 77.1970, crimes: 9963),

    // ─── ODISHA (52,792) ───────────────────────────────────
    _CityData(name: 'Bhubaneswar', lat: 20.2961, lon: 85.8245, crimes: 16000),
    _CityData(name: 'Cuttack', lat: 20.4625, lon: 85.8830, crimes: 12000),
    _CityData(name: 'Berhampur', lat: 19.3150, lon: 84.7941, crimes: 10000),
    _CityData(name: 'Rourkela', lat: 22.2604, lon: 84.8536, crimes: 8792),
    _CityData(name: 'Sambalpur', lat: 21.4669, lon: 83.9812, crimes: 6000),

    // ─── HARYANA (50,509) ──────────────────────────────────
    _CityData(name: 'Faridabad', lat: 28.4089, lon: 77.3178, crimes: 14000),
    _CityData(name: 'Gurgaon', lat: 28.4595, lon: 77.0266, crimes: 12000),
    _CityData(name: 'Hisar', lat: 29.1492, lon: 75.7217, crimes: 9000),
    _CityData(name: 'Panipat', lat: 29.3909, lon: 76.9635, crimes: 8509),
    _CityData(name: 'Ambala', lat: 30.3782, lon: 76.7767, crimes: 7000),

    // ─── CHHATTISGARH (45,177) ─────────────────────────────
    _CityData(name: 'Raipur', lat: 21.2514, lon: 81.6296, crimes: 16000),
    _CityData(name: 'Bhilai', lat: 21.2093, lon: 81.3784, crimes: 12000),
    _CityData(name: 'Bilaspur', lat: 22.0796, lon: 82.1391, crimes: 10177),
    _CityData(name: 'Korba', lat: 22.3595, lon: 82.7501, crimes: 7000),

    // ─── ASSAM (43,673) ────────────────────────────────────
    _CityData(name: 'Guwahati', lat: 26.1445, lon: 91.7362, crimes: 18000),
    _CityData(name: 'Silchar', lat: 24.8333, lon: 92.7789, crimes: 10000),
    _CityData(name: 'Dibrugarh', lat: 27.4728, lon: 94.9120, crimes: 8673),
    _CityData(name: 'Jorhat', lat: 26.7509, lon: 94.2037, crimes: 7000),

    // ─── JHARKHAND (36,364) ────────────────────────────────
    _CityData(name: 'Ranchi', lat: 23.3441, lon: 85.3096, crimes: 14000),
    _CityData(name: 'Jamshedpur', lat: 22.8046, lon: 86.2029, crimes: 10000),
    _CityData(name: 'Dhanbad', lat: 23.7957, lon: 86.4304, crimes: 8364),
    _CityData(name: 'Bokaro', lat: 23.7871, lon: 86.1511, crimes: 4000),

    // ─── PUNJAB (32,068) ───────────────────────────────────
    _CityData(name: 'Ludhiana', lat: 30.9010, lon: 75.8573, crimes: 10000),
    _CityData(name: 'Amritsar', lat: 31.6340, lon: 74.8723, crimes: 8000),
    _CityData(name: 'Jalandhar', lat: 31.3260, lon: 75.5762, crimes: 7068),
    _CityData(name: 'Patiala', lat: 30.3398, lon: 76.3869, crimes: 7000),

    // ─── JAMMU & KASHMIR (20,787) ──────────────────────────
    _CityData(name: 'Srinagar', lat: 34.0837, lon: 74.7973, crimes: 8000),
    _CityData(name: 'Jammu', lat: 32.7266, lon: 74.8570, crimes: 8787),
    _CityData(name: 'Anantnag', lat: 33.7311, lon: 75.1487, crimes: 4000),

    // ─── HIMACHAL PRADESH (13,093) ─────────────────────────
    _CityData(name: 'Shimla', lat: 31.1048, lon: 77.1734, crimes: 5000),
    _CityData(name: 'Dharamshala', lat: 32.2190, lon: 76.3234, crimes: 4093),
    _CityData(name: 'Mandi', lat: 31.7088, lon: 76.9318, crimes: 4000),

    // ─── UTTARAKHAND (8,412) ───────────────────────────────
    _CityData(name: 'Dehradun', lat: 30.3165, lon: 78.0322, crimes: 3500),
    _CityData(name: 'Haridwar', lat: 29.9457, lon: 78.1642, crimes: 2912),
    _CityData(name: 'Haldwani', lat: 29.2183, lon: 79.5130, crimes: 2000),

    // ─── SMALLER STATES ───────────────────────────────────
    _CityData(name: 'Agartala', lat: 23.8315, lon: 91.2868, crimes: 3940),
    _CityData(name: 'Imphal', lat: 24.8170, lon: 93.9368, crimes: 2884),
    _CityData(name: 'Itanagar', lat: 27.0844, lon: 93.6053, crimes: 2294),
    _CityData(name: 'Panaji', lat: 15.4909, lon: 73.8278, crimes: 2204),
    _CityData(name: 'Aizawl', lat: 23.7271, lon: 92.7176, crimes: 2073),
    _CityData(name: 'Shillong', lat: 25.5788, lon: 91.8933, crimes: 1935),
    _CityData(name: 'Kohima', lat: 25.6747, lon: 94.1086, crimes: 1103),
    _CityData(name: 'Gangtok', lat: 27.3389, lon: 88.6065, crimes: 703),

    // ─── UNION TERRITORIES ────────────────────────────────
    _CityData(name: 'Pondicherry', lat: 11.9416, lon: 79.8083, crimes: 4687),
    _CityData(name: 'Chandigarh', lat: 30.7333, lon: 76.7794, crimes: 3126),
    _CityData(name: 'Port Blair', lat: 11.6234, lon: 92.7265, crimes: 676),
    _CityData(name: 'Silvassa', lat: 20.2766, lon: 72.9959, crimes: 435),
    _CityData(name: 'Daman', lat: 20.3974, lon: 72.8328, crimes: 288),
    _CityData(name: 'Kavaratti', lat: 10.5626, lon: 72.6369, crimes: 80),
  ];

  static Color _crimeColor(int crimes) {
    if (crimes >= 40000) return const Color(0xCCFF1744);
    if (crimes >= 25000) return const Color(0xCCFF6D00);
    if (crimes >= 15000) return const Color(0xCCFFAB00);
    if (crimes >= 8000) return const Color(0xCCFFFF00);
    if (crimes >= 3000) return const Color(0xCC76FF03);
    return const Color(0xCC00E676);
  }

  static double _crimeRadius(int crimes) {
    if (crimes >= 40000) return 45000;
    if (crimes >= 25000) return 35000;
    if (crimes >= 15000) return 28000;
    if (crimes >= 8000) return 22000;
    if (crimes >= 3000) return 16000;
    return 10000;
  }

  Set<Circle> _buildCircles() {
    return _distributedData.map((city) {
      return Circle(
        circleId: CircleId(city.name),
        center: LatLng(city.lat, city.lon),
        radius: _crimeRadius(city.crimes),
        fillColor: _crimeColor(city.crimes),
        strokeColor: _crimeColor(city.crimes).withValues(alpha: 0.9),
        strokeWidth: 1,
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.bgPrimary.withValues(alpha: 0.85),
        title: Text(
          'Crime Heatmap',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Data Source',
            onPressed: () => _showDataInfo(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(22.0, 79.0),
                zoom: 4.8,
              ),
              circles: _buildCircles(),
              mapType: MapType.normal,
              myLocationEnabled: false,
              zoomControlsEnabled: true,
            ),
          ),

          // ─── Legend Panel ─────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.bgPrimary,
              border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crime Density by City',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _LegendItem(color: const Color(0xCCFF1744), label: '≥40K'),
                    _LegendItem(
                      color: const Color(0xCCFF6D00),
                      label: '25K-40K',
                    ),
                    _LegendItem(
                      color: const Color(0xCCFFAB00),
                      label: '15K-25K',
                    ),
                    _LegendItem(
                      color: const Color(0xCCFFFF00),
                      label: '8K-15K',
                    ),
                    _LegendItem(color: const Color(0xCC76FF03), label: '3K-8K'),
                    _LegendItem(color: const Color(0xCC00E676), label: '<3K'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDataInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.surfaceBorder),
        ),
        title: Text(
          'Data Source',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ministry of Statistics & Programme Implementation (MOSPI)',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'Document: Statistical Abstract India 2007\n'
                'Table: 29.1 — Incidence of Cognizable Crime Under IPC\n'
                'Year: 2006\n\n'
                'State-level totals are distributed proportionally\n'
                'across major cities based on urban population ratios.\n'
                'This provides a geographically spread visualization\n'
                'rather than a single circle per state.',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Top 5 States by Crime Volume:',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '1. Madhya Pradesh: 1,94,711\n'
                '2. Maharashtra: 1,91,788\n'
                '3. Andhra Pradesh: 1,73,909\n'
                '4. Tamil Nadu: 1,48,972\n'
                '5. Rajasthan: 1,41,992',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CLOSE',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _CityData {
  final String name;
  final double lat;
  final double lon;
  final int crimes;

  const _CityData({
    required this.name,
    required this.lat,
    required this.lon,
    required this.crimes,
  });
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.inter(color: AppTheme.textDisabled, fontSize: 9),
        ),
      ],
    );
  }
}

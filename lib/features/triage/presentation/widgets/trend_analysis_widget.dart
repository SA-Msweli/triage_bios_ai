import 'package:flutter/material.dart';
import '../../../../shared/services/vitals_trend_service.dart';

class TrendAnalysisWidget extends StatefulWidget {
  const TrendAnalysisWidget({super.key});

  @override
  State<TrendAnalysisWidget> createState() => _TrendAnalysisWidgetState();
}

class _TrendAnalysisWidgetState extends State<TrendAnalysisWidget> {
  final VitalsTrendService _trendService = VitalsTrendService();
  VitalsTrendAnalysis? _trendAnalysis;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTrendAnalysis();
  }

  Future<void> _loadTrendAnalysis() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final analysis = await _trendService.analyzeTrends(hoursBack: 24);
      setState(() {
        _trendAnalysis = analysis;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('Analyzing vitals trends...'),
            ],
          ),
        ),
      );
    }

    if (_trendAnalysis == null || _trendAnalysis!.dataPoints == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(
                Icons.trending_up,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'Trend Analysis',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'No trend data available yet. Continue monitoring vitals to see patterns.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: _getTrendColor(context, _trendAnalysis!.overallStability),
                ),
                const SizedBox(width: 8),
                Text(
                  'Vitals Trend Analysis',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTrendColor(context, _trendAnalysis!.overallStability),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStabilityText(_trendAnalysis!.overallStability),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Data summary
            Text(
              '${_trendAnalysis!.dataPoints} readings over ${_trendAnalysis!.timeSpanHours} hours',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 16),

            // Individual trend indicators
            _buildTrendIndicator(
              context,
              'Heart Rate',
              Icons.favorite,
              _trendAnalysis!.heartRateTrend,
            ),
            const SizedBox(height: 8),
            _buildTrendIndicator(
              context,
              'Oxygen Saturation',
              Icons.air,
              _trendAnalysis!.oxygenSaturationTrend,
            ),
            const SizedBox(height: 8),
            _buildTrendIndicator(
              context,
              'Temperature',
              Icons.thermostat,
              _trendAnalysis!.temperatureTrend,
            ),
            const SizedBox(height: 8),
            _buildBloodPressureTrendIndicator(
              context,
              _trendAnalysis!.bloodPressureTrend,
            ),

            const SizedBox(height: 16),

            // Deterioration risk assessment
            if (_trendAnalysis!.deteriorationRisk != DeteriorationRisk.minimal) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getDeteriorationRiskColor(context, _trendAnalysis!.deteriorationRisk),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deterioration Risk: ${_getDeteriorationRiskText(_trendAnalysis!.deteriorationRisk)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_trendAnalysis!.recommendations.isNotEmpty)
                            Text(
                              _trendAnalysis!.recommendations.first,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Recommendations
            if (_trendAnalysis!.recommendations.isNotEmpty) ...[
              Text(
                'Recommendations:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ...(_trendAnalysis!.recommendations.take(3).map((rec) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: Theme.of(context).textTheme.bodySmall),
                    Expanded(
                      child: Text(
                        rec,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrendIndicator(
    BuildContext context,
    String label,
    IconData icon,
    TrendDirection trend,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Icon(
              _getTrendIcon(trend),
              size: 16,
              color: _getTrendDirectionColor(context, trend),
            ),
            const SizedBox(width: 4),
            Text(
              _getTrendText(trend),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _getTrendDirectionColor(context, trend),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBloodPressureTrendIndicator(
    BuildContext context,
    BloodPressureTrend bpTrend,
  ) {
    return Row(
      children: [
        Icon(
          Icons.monitor_heart,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          'Blood Pressure',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Text(
                  'Systolic: ',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Icon(
                  _getTrendIcon(bpTrend.systolicTrend),
                  size: 14,
                  color: _getTrendDirectionColor(context, bpTrend.systolicTrend),
                ),
                Text(
                  _getTrendText(bpTrend.systolicTrend),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _getTrendDirectionColor(context, bpTrend.systolicTrend),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  'Diastolic: ',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Icon(
                  _getTrendIcon(bpTrend.diastolicTrend),
                  size: 14,
                  color: _getTrendDirectionColor(context, bpTrend.diastolicTrend),
                ),
                Text(
                  _getTrendText(bpTrend.diastolicTrend),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _getTrendDirectionColor(context, bpTrend.diastolicTrend),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  IconData _getTrendIcon(TrendDirection trend) {
    switch (trend) {
      case TrendDirection.increasing:
        return Icons.trending_up;
      case TrendDirection.decreasing:
        return Icons.trending_down;
      case TrendDirection.stable:
        return Icons.trending_flat;
    }
  }

  String _getTrendText(TrendDirection trend) {
    switch (trend) {
      case TrendDirection.increasing:
        return 'Rising';
      case TrendDirection.decreasing:
        return 'Falling';
      case TrendDirection.stable:
        return 'Stable';
    }
  }

  Color _getTrendDirectionColor(BuildContext context, TrendDirection trend) {
    switch (trend) {
      case TrendDirection.increasing:
        return Colors.orange;
      case TrendDirection.decreasing:
        return Colors.red;
      case TrendDirection.stable:
        return Colors.green;
    }
  }

  Color _getTrendColor(BuildContext context, StabilityLevel stability) {
    switch (stability) {
      case StabilityLevel.stable:
        return Colors.green;
      case StabilityLevel.mildlyUnstable:
        return Colors.orange;
      case StabilityLevel.concerning:
        return Colors.deepOrange;
      case StabilityLevel.unstable:
        return Colors.red;
      case StabilityLevel.unknown:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  String _getStabilityText(StabilityLevel stability) {
    switch (stability) {
      case StabilityLevel.stable:
        return 'Stable';
      case StabilityLevel.mildlyUnstable:
        return 'Mild Variation';
      case StabilityLevel.concerning:
        return 'Concerning';
      case StabilityLevel.unstable:
        return 'Unstable';
      case StabilityLevel.unknown:
        return 'Unknown';
    }
  }

  Color _getDeteriorationRiskColor(BuildContext context, DeteriorationRisk risk) {
    switch (risk) {
      case DeteriorationRisk.minimal:
        return Colors.green;
      case DeteriorationRisk.low:
        return Colors.blue;
      case DeteriorationRisk.moderate:
        return Colors.orange;
      case DeteriorationRisk.high:
        return Colors.red;
      case DeteriorationRisk.unknown:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  String _getDeteriorationRiskText(DeteriorationRisk risk) {
    switch (risk) {
      case DeteriorationRisk.minimal:
        return 'Minimal';
      case DeteriorationRisk.low:
        return 'Low';
      case DeteriorationRisk.moderate:
        return 'Moderate';
      case DeteriorationRisk.high:
        return 'High';
      case DeteriorationRisk.unknown:
        return 'Unknown';
    }
  }
}
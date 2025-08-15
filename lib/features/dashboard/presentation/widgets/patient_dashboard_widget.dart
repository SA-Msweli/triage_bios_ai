import 'package:flutter/material.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/constrained_responsive_container.dart';
import '../../../../shared/widgets/responsive_layouts.dart';
import '../../../../shared/utils/overflow_detection.dart';

/// Quick action item model
class QuickAction {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isEnabled;
  final String? badge;
  final bool isPrimary;

  const QuickAction({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isEnabled = true,
    this.badge,
    this.isPrimary = false,
  });
}

/// Patient dashboard widget showing health data and triage options
class PatientDashboardWidget extends StatefulWidget {
  final String? patientName;
  final Function(String action)? onActionTap;

  const PatientDashboardWidget({super.key, this.patientName, this.onActionTap});

  @override
  State<PatientDashboardWidget> createState() => _PatientDashboardWidgetState();
}

class _PatientDashboardWidgetState extends State<PatientDashboardWidget> {
  late List<QuickAction> _quickActions;

  @override
  void initState() {
    super.initState();
    _initializeQuickActions();
  }

  void _initializeQuickActions() {
    _quickActions = [
      QuickAction(
        title: 'AI Triage',
        description: 'Start emergency health assessment',
        icon: Icons.psychology,
        color: Colors.red.shade600,
        onTap: () => _handleActionTap('triage'),
        isPrimary: true,
        badge: 'Emergency',
      ),
      QuickAction(
        title: 'Find Hospitals',
        description: 'Locate nearby medical facilities',
        icon: Icons.local_hospital,
        color: Colors.blue.shade600,
        onTap: () => _handleActionTap('hospitals'),
      ),
      QuickAction(
        title: 'Health Data',
        description: 'View vitals and health trends',
        icon: Icons.favorite,
        color: Colors.green.shade600,
        onTap: () => _handleActionTap('vitals'),
        badge: 'Live',
      ),
      QuickAction(
        title: 'Consent Management',
        description: 'Manage data sharing preferences',
        icon: Icons.security,
        color: Colors.orange.shade600,
        onTap: () => _handleActionTap('consent'),
      ),
      QuickAction(
        title: 'Medical History',
        description: 'View past assessments',
        icon: Icons.history,
        color: Colors.purple.shade600,
        onTap: () => _handleActionTap('history'),
      ),
      QuickAction(
        title: 'Emergency Contacts',
        description: 'Manage emergency contacts',
        icon: Icons.contact_phone,
        color: Colors.teal.shade600,
        onTap: () => _handleActionTap('contacts'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: ResponsiveBreakpoints.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(),
            SizedBox(height: ResponsiveBreakpoints.isMobile(context) ? 20 : 24),

            _buildPrimaryActions(),
            SizedBox(height: ResponsiveBreakpoints.isMobile(context) ? 20 : 24),

            _buildSecondaryActions(),
            SizedBox(height: ResponsiveBreakpoints.isMobile(context) ? 20 : 24),

            _buildHealthTrends(),
            SizedBox(height: ResponsiveBreakpoints.isMobile(context) ? 20 : 24),

            _buildQuickStats(),
          ],
        ),
      ),
    ).withOverflowDetection(debugName: 'Patient Dashboard');
  }

  Widget _buildWelcomeHeader() {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return ConstrainedResponsiveContainer.card(
      child: Container(
        width: double.infinity,
        padding: ResponsiveBreakpoints.getResponsivePadding(context),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade600, Colors.blue.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.health_and_safety,
                    color: Colors.white,
                    size: isMobile ? 28 : 32,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome${widget.patientName != null ? ', ${widget.patientName}' : ''}',
                        style: TextStyle(
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      SizedBox(height: isMobile ? 4 : 6),
                      Text(
                        'Your AI-powered health dashboard',
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: isMobile ? 16 : 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'System Ready',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryActions() {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final primaryActions = _quickActions
        .where((action) => action.isPrimary)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emergency Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 18 : 20,
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),

        ResponsiveGrid(
          mobileColumns: 1,
          tabletColumns: 1,
          desktopColumns: 1,
          spacing: isMobile ? 12 : 16,
          children: primaryActions
              .map((action) => _buildPrimaryActionCard(action))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPrimaryActionCard(QuickAction action) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return ConstrainedResponsiveContainer.button(
      child: Card(
        elevation: 4,
        child: InkWell(
          onTap: action.isEnabled ? action.onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: action.color.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    action.icon,
                    size: isMobile ? 32 : 40,
                    color: action.color,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              action.title,
                              style: TextStyle(
                                fontSize: isMobile ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: action.isEnabled ? null : Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (action.badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: action.color,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                action.badge!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isMobile ? 10 : 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: isMobile ? 4 : 6),
                      Text(
                        action.description,
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          color: action.isEnabled
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: isMobile ? 16 : 18,
                  color: action.isEnabled ? action.color : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryActions() {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final secondaryActions = _quickActions
        .where((action) => !action.isPrimary)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 18 : 20,
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),

        ResponsiveGrid(
          mobileColumns: 2,
          tabletColumns: 3,
          desktopColumns: 4,
          spacing: isMobile ? 12 : 16,
          children: secondaryActions
              .map((action) => _buildSecondaryActionCard(action))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSecondaryActionCard(QuickAction action) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return ConstrainedResponsiveContainer.button(
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: action.isEnabled ? action.onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 8 : 12),
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    action.icon,
                    size: isMobile ? 24 : 28,
                    color: action.isEnabled ? action.color : Colors.grey,
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 12),
                Text(
                  action.title,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.bold,
                    color: action.isEnabled ? null : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                SizedBox(height: isMobile ? 4 : 6),
                Text(
                  action.description,
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12,
                    color: action.isEnabled
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                if (action.badge != null) ...[
                  SizedBox(height: isMobile ? 4 : 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: action.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      action.badge!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 8 : 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHealthTrends() {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Health Trends',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 18 : 20,
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),

        ResponsiveGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 2,
          spacing: isMobile ? 12 : 16,
          children: [
            _buildTrendCard(
              'Heart Rate',
              '72 BPM',
              'Normal range',
              Icons.favorite,
              Colors.red,
              _buildMockChart(Colors.red.shade100, Colors.red),
            ),
            _buildTrendCard(
              'Blood Pressure',
              '120/80',
              'Optimal',
              Icons.monitor_heart,
              Colors.green,
              _buildMockChart(Colors.green.shade100, Colors.green),
            ),
            if (!isMobile) ...[
              _buildTrendCard(
                'Temperature',
                '98.6°F',
                'Normal',
                Icons.thermostat,
                Colors.orange,
                _buildMockChart(Colors.orange.shade100, Colors.orange),
              ),
              _buildTrendCard(
                'Sleep Quality',
                '7.5 hrs',
                'Good',
                Icons.bedtime,
                Colors.purple,
                _buildMockChart(Colors.purple.shade100, Colors.purple),
              ),
            ],
          ],
        ),

        // Show additional trends on mobile in a separate row
        if (isMobile) ...[
          SizedBox(height: isMobile ? 12 : 16),
          ResponsiveGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 2,
            spacing: isMobile ? 12 : 16,
            children: [
              _buildTrendCard(
                'Temperature',
                '98.6°F',
                'Normal',
                Icons.thermostat,
                Colors.orange,
                _buildMockChart(Colors.orange.shade100, Colors.orange),
              ),
              _buildTrendCard(
                'Sleep Quality',
                '7.5 hrs',
                'Good',
                Icons.bedtime,
                Colors.purple,
                _buildMockChart(Colors.purple.shade100, Colors.purple),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTrendCard(
    String title,
    String value,
    String status,
    IconData icon,
    Color color,
    Widget chart,
  ) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return ConstrainedResponsiveContainer.card(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: ResponsiveBreakpoints.getResponsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 8 : 10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: isMobile ? 20 : 24),
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 12 : 16),

              // Responsive chart container with proper constraints
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: isMobile ? 80 : 100,
                  maxHeight: isMobile ? 120 : 150,
                ),
                child: chart,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMockChart(Color backgroundColor, Color lineColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: _MockChartPainter(lineColor),
        child: Container(),
      ),
    );
  }

  Widget _buildQuickStats() {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return ConstrainedResponsiveContainer.card(
      child: Card(
        child: Padding(
          padding: ResponsiveBreakpoints.getResponsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics,
                    color: Colors.blue.shade700,
                    size: isMobile ? 20 : 24,
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  Text(
                    'Quick Stats',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 16 : 18,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 12 : 16),

              ResponsiveGrid(
                mobileColumns: 2,
                tabletColumns: 4,
                desktopColumns: 4,
                spacing: isMobile ? 8 : 12,
                children: [
                  _buildStatItem(
                    'Last Triage',
                    '2 days ago',
                    Icons.psychology,
                    Colors.blue,
                  ),
                  _buildStatItem(
                    'Vitals Check',
                    '5 min ago',
                    Icons.favorite,
                    Colors.red,
                  ),
                  _buildStatItem(
                    'Hospitals',
                    '12 nearby',
                    Icons.local_hospital,
                    Colors.green,
                  ),
                  _buildStatItem(
                    'Health Score',
                    '85/100',
                    Icons.health_and_safety,
                    Colors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isMobile ? 16 : 20),
          SizedBox(height: isMobile ? 4 : 6),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 9 : 11,
              color: color.withValues(alpha: 0.8),
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  void _handleActionTap(String action) {
    widget.onActionTap?.call(action);

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening $action...'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

/// Custom painter for mock health trend charts
class _MockChartPainter extends CustomPainter {
  final Color lineColor;

  _MockChartPainter(this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();

    // Create a simple trend line with some variation
    final points = [
      Offset(0, size.height * 0.7),
      Offset(size.width * 0.2, size.height * 0.5),
      Offset(size.width * 0.4, size.height * 0.6),
      Offset(size.width * 0.6, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.4),
      Offset(size.width, size.height * 0.2),
    ];

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);

    // Draw data points
    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 3.0, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'dart:async';
import '../../domain/entities/triage_result.dart';
import '../../domain/repositories/triage_repository.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';

/// Widget for displaying patient triage history with filtering and real-time updates
class PatientHistoryWidget extends StatefulWidget {
  final String patientId;
  final TriageRepository triageRepository;
  final bool showRealTimeUpdates;

  const PatientHistoryWidget({
    super.key,
    required this.patientId,
    required this.triageRepository,
    this.showRealTimeUpdates = true,
  });

  @override
  State<PatientHistoryWidget> createState() => _PatientHistoryWidgetState();
}

class _PatientHistoryWidgetState extends State<PatientHistoryWidget> {
  List<TriageResult> _history = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription<List<TriageResult>>? _historySubscription;

  // Filtering options
  UrgencyLevel? _selectedUrgencyFilter;
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.showRealTimeUpdates) {
        // Use real-time stream
        _historySubscription = widget.triageRepository
            .watchPatientHistory(widget.patientId)
            .listen(
              (history) {
                if (mounted) {
                  setState(() {
                    _history = _applyFilters(history);
                    _isLoading = false;
                    _error = null;
                  });
                }
              },
              onError: (error) {
                if (mounted) {
                  setState(() {
                    _error = error.toString();
                    _isLoading = false;
                  });
                }
              },
            );
      } else {
        // Load once
        final result = await widget.triageRepository.getPatientHistory(
          widget.patientId,
        );
        result.fold(
          (failure) {
            setState(() {
              _error = failure.message;
              _isLoading = false;
            });
          },
          (history) {
            setState(() {
              _history = _applyFilters(history);
              _isLoading = false;
            });
          },
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<TriageResult> _applyFilters(List<TriageResult> history) {
    var filtered = history;

    // Apply urgency filter
    if (_selectedUrgencyFilter != null) {
      filtered = filtered
          .where((result) => result.urgencyLevel == _selectedUrgencyFilter)
          .toList();
    }

    // Apply date range filter
    if (_selectedDateRange != null) {
      filtered = filtered.where((result) {
        final resultDate = result.timestamp;
        return resultDate.isAfter(_selectedDateRange!.start) &&
            resultDate.isBefore(
              _selectedDateRange!.end.add(const Duration(days: 1)),
            );
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((result) {
        return result.symptoms.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            result.explanation.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            result.keySymptoms.any(
              (symptom) =>
                  symptom.toLowerCase().contains(_searchQuery.toLowerCase()),
            );
      }).toList();
    }

    // Sort by timestamp (newest first)
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return filtered;
  }

  void _updateFilters() {
    setState(() {
      _history = _applyFilters(_history);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, isMobile),
            const SizedBox(height: 16),
            _buildFilters(context, isMobile),
            const SizedBox(height: 16),
            Expanded(child: _buildContent(context, isMobile)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Row(
      children: [
        Icon(
          Icons.history,
          color: Theme.of(context).colorScheme.primary,
          size: isMobile ? 20 : 24,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Patient History',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 18 : 24,
            ),
          ),
        ),
        if (widget.showRealTimeUpdates) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi, size: 12, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        IconButton(
          icon: Icon(Icons.refresh, size: isMobile ? 20 : 24),
          onPressed: _loadHistory,
          tooltip: 'Refresh history',
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context, bool isMobile) {
    return Column(
      children: [
        // Search bar
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search symptoms, explanations...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                      _updateFilters();
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
            _updateFilters();
          },
        ),

        const SizedBox(height: 12),

        // Filter chips
        if (isMobile)
          Column(
            children: [
              _buildUrgencyFilter(context),
              const SizedBox(height: 8),
              _buildDateRangeFilter(context),
            ],
          )
        else
          Row(
            children: [
              Expanded(child: _buildUrgencyFilter(context)),
              const SizedBox(width: 16),
              Expanded(child: _buildDateRangeFilter(context)),
            ],
          ),
      ],
    );
  }

  Widget _buildUrgencyFilter(BuildContext context) {
    return DropdownButtonFormField<UrgencyLevel?>(
      decoration: const InputDecoration(
        labelText: 'Filter by Urgency',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      value: _selectedUrgencyFilter,
      items: [
        const DropdownMenuItem<UrgencyLevel?>(
          value: null,
          child: Text('All Urgency Levels'),
        ),
        ...UrgencyLevel.values.map(
          (level) => DropdownMenuItem(
            value: level,
            child: Row(
              children: [
                Icon(
                  _getUrgencyIcon(level),
                  size: 16,
                  color: _getUrgencyColor(level),
                ),
                const SizedBox(width: 8),
                Text(_getUrgencyText(level)),
              ],
            ),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedUrgencyFilter = value;
        });
        _updateFilters();
      },
    );
  }

  Widget _buildDateRangeFilter(BuildContext context) {
    return InkWell(
      onTap: () async {
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now(),
          initialDateRange: _selectedDateRange,
        );
        if (range != null) {
          setState(() {
            _selectedDateRange = range;
          });
          _updateFilters();
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Filter by Date Range',
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: _selectedDateRange != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _selectedDateRange = null;
                    });
                    _updateFilters();
                  },
                )
              : const Icon(Icons.date_range),
        ),
        child: Text(
          _selectedDateRange != null
              ? '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}'
              : 'All Dates',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isMobile) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading history',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadHistory, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No triage history found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'No results match your current filters',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final result = _history[index];
        return _buildHistoryItem(context, result, isMobile);
      },
    );
  }

  Widget _buildHistoryItem(
    BuildContext context,
    TriageResult result,
    bool isMobile,
  ) {
    final urgencyColor = _getUrgencyColor(result.urgencyLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: () => _showResultDetails(context, result),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: urgencyColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getUrgencyText(result.urgencyLevel),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Score: ${result.severityScore.toStringAsFixed(1)}/10',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: urgencyColor,
                            ),
                      ),
                    ),
                    Text(
                      _formatTimestamp(result.timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Symptoms preview
                Text(
                  'Symptoms:',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  result.symptoms.length > 100
                      ? '${result.symptoms.substring(0, 100)}...'
                      : result.symptoms,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                const SizedBox(height: 8),

                // Key symptoms chips
                if (result.keySymptoms.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: result.keySymptoms
                        .take(3)
                        .map(
                          (symptom) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              symptom,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                ],

                // Footer
                Row(
                  children: [
                    Icon(
                      Icons.psychology,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AI Model: ${result.aiModelVersion}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Confidence: ${result.confidenceLower.toStringAsFixed(1)}-${result.confidenceUpper.toStringAsFixed(1)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResultDetails(BuildContext context, TriageResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Triage Result Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Timestamp: ${result.timestamp}'),
              const SizedBox(height: 8),
              Text(
                'Severity Score: ${result.severityScore.toStringAsFixed(1)}/10',
              ),
              const SizedBox(height: 8),
              Text('Urgency Level: ${_getUrgencyText(result.urgencyLevel)}'),
              const SizedBox(height: 16),
              Text('Symptoms:', style: Theme.of(context).textTheme.titleSmall),
              Text(result.symptoms),
              const SizedBox(height: 16),
              Text(
                'AI Explanation:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(result.explanation),
              if (result.keySymptoms.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Key Symptoms:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                ...result.keySymptoms.map((symptom) => Text('• $symptom')),
              ],
              if (result.recommendedActions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Recommended Actions:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                ...result.recommendedActions.map((action) => Text('• $action')),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _getUrgencyIcon(UrgencyLevel level) {
    switch (level) {
      case UrgencyLevel.critical:
        return Icons.emergency;
      case UrgencyLevel.urgent:
        return Icons.priority_high;
      case UrgencyLevel.standard:
        return Icons.medical_services;
      case UrgencyLevel.nonUrgent:
        return Icons.health_and_safety;
    }
  }

  Color _getUrgencyColor(UrgencyLevel level) {
    switch (level) {
      case UrgencyLevel.critical:
        return Colors.red;
      case UrgencyLevel.urgent:
        return Colors.orange;
      case UrgencyLevel.standard:
        return Colors.blue;
      case UrgencyLevel.nonUrgent:
        return Colors.green;
    }
  }

  String _getUrgencyText(UrgencyLevel level) {
    switch (level) {
      case UrgencyLevel.critical:
        return 'CRITICAL';
      case UrgencyLevel.urgent:
        return 'URGENT';
      case UrgencyLevel.standard:
        return 'STANDARD';
      case UrgencyLevel.nonUrgent:
        return 'NON-URGENT';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return _formatDate(timestamp);
    }
  }
}

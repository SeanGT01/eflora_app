import 'package:flutter/material.dart';
import 'package:eflowers/services/api_service.dart';
import 'package:intl/intl.dart';

class StockHistoryViewer extends StatefulWidget {
  final int productId;
  final String productName;
  final int currentStock;

  const StockHistoryViewer({
    required this.productId,
    required this.productName,
    required this.currentStock,
    super.key,
  });

  @override
  State<StockHistoryViewer> createState() => _StockHistoryViewerState();
}

class _StockHistoryViewerState extends State<StockHistoryViewer> {
  late Future<Map<String, dynamic>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchStockHistory();
  }

  Future<Map<String, dynamic>> _fetchStockHistory() async {
    try {
      final response = await ApiService.get(
        '/seller/products/${widget.productId}/stock-history',
      );
      return response;
    } catch (e) {
      throw Exception('Failed to load stock history: $e');
    }
  }

  Color _getReasonColor(String reason) {
    switch (reason) {
      case 'spoilage':
        return Colors.orange;
      case 'damage':
        return Colors.red;
      case 'defect':
        return Colors.purple;
      case 'other':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _getReasonIcon(String reason) {
    switch (reason) {
      case 'spoilage':
        return Icons.local_florist;
      case 'damage':
        return Icons.broken_image;
      case 'defect':
        return Icons.warning;
      case 'other':
        return Icons.more_horiz;
      default:
        return Icons.info;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Stock History')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Stock History')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _historyFuture = _fetchStockHistory();
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final product = data['product'] as Map<String, dynamic>? ?? {};
        final history = (data['stock_history'] as List<dynamic>?) ?? [];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Stock History'),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Header card with summary
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.productName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoTile(
                              label: 'Current Stock',
                              value: '${widget.currentStock} units',
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoTile(
                              label: 'Total Reductions',
                              value: '${product['total_reductions'] ?? 0} units',
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoTile(
                              label: 'Times Reduced',
                              value: '${product['reduction_count'] ?? 0}x',
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // History list
                if (history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No stock reductions yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(8),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final entry = history[index] as Map<String, dynamic>;
                      final reason = entry['reason'] as String? ?? 'unknown';
                      final amount = entry['reduction_amount'] ?? 0;
                      final reducedBy = entry['reducer_name'] ?? 'Unknown';
                      final notes = entry['reason_notes'] as String?;
                      final date = _formatDate(entry['created_at'] as String?);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ExpansionTile(
                          leading: Icon(
                            _getReasonIcon(reason),
                            color: _getReasonColor(reason),
                          ),
                          title: Row(
                            children: [
                              Text(
                                '-$amount units',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Chip(
                                  label: Text(reason[0].toUpperCase() + reason.substring(1)),
                                  backgroundColor: _getReasonColor(reason).withOpacity(0.2),
                                  labelStyle: TextStyle(
                                    color: _getReasonColor(reason),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  side: BorderSide(
                                    color: _getReasonColor(reason),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'By: $reducedBy • $date',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (notes != null && notes.isNotEmpty) ...[
                                    Text(
                                      'Notes:',
                                      style: Theme.of(context).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        notes,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ),
                                  ] else
                                    Text(
                                      'No notes provided',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        reducedBy,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      const Spacer(),
                                      const Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        date,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

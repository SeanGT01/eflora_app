import 'package:flutter/material.dart';
import 'package:eflowers/services/api_service.dart';

class StockReductionForm extends StatefulWidget {
  final int productId;
  final int currentStock;
  final String productName;
  final VoidCallback? onSuccess;

  const StockReductionForm({
    required this.productId,
    required this.currentStock,
    required this.productName,
    this.onSuccess,
    super.key,
  });

  @override
  State<StockReductionForm> createState() => _StockReductionFormState();
}

class _StockReductionFormState extends State<StockReductionForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  
  String _selectedReason = 'spoilage';
  bool _isLoading = false;
  
  final List<String> reasons = ['spoilage', 'damage', 'defect', 'other'];
  
  final Map<String, String> reasonDescriptions = {
    'spoilage': 'Product has spoiled or expired',
    'damage': 'Product is damaged',
    'defect': 'Product has manufacturing defect',
    'other': 'Other reason (explain in notes)',
  };
  
  final Map<String, IconData> reasonIcons = {
    'spoilage': Icons.local_florist,
    'damage': Icons.broken_image,
    'defect': Icons.warning,
    'other': Icons.more_horiz,
  };

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitReduction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final amount = int.parse(_amountController.text);
      
      final response = await ApiService.post(
        '/seller/products/${widget.productId}/reduce-stock',
        body: {
          'amount': amount,
          'reason': _selectedReason,
          'reason_notes': _notesController.text.isNotEmpty 
            ? _notesController.text 
            : null,
        },
      );

      if (!mounted) return;

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock reduced by $amount units'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        _formKey.currentState!.reset();
        _amountController.clear();
        _notesController.clear();
        setState(() => _selectedReason = 'spoilage');
        
        widget.onSuccess?.call();
        
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? 'Failed to reduce stock'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reduce Stock'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.productName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Current Stock: ${widget.currentStock} units',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Reduction amount
              Text(
                'Reduction Amount',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Units to reduce',
                  hintText: 'Enter number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.remove),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  final amount = int.tryParse(value!);
                  if (amount == null || amount <= 0) {
                    return 'Must be a positive number';
                  }
                  if (amount > widget.currentStock) {
                    return 'Cannot reduce more than ${widget.currentStock} units';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Reason selection
              Text(
                'Reason for Reduction',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: reasons.map((reason) {
                  final isSelected = _selectedReason == reason;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedReason = reason),
                    child: Card(
                      color: isSelected ? Colors.blue.shade50 : null,
                      child: Container(
                        decoration: BoxDecoration(
                          border: isSelected
                            ? Border.all(color: Colors.blue, width: 2)
                            : Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              reasonIcons[reason],
                              size: 32,
                              color: isSelected ? Colors.blue : Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              reason[0].toUpperCase() + reason.substring(1),
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.blue : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                reasonDescriptions[_selectedReason] ?? '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),
              
              // Additional notes
              Text(
                'Additional Notes (Optional)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Add notes',
                  hintText: 'e.g., Damaged during shipping, expired on...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.note),
                ),
                maxLines: 3,
                validator: (value) {
                  // Notes are optional, but if provided, should be meaningful
                  if (value != null && 
                      _selectedReason == 'other' && 
                      value.isEmpty) {
                    return 'Please explain the reason';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitReduction,
                  icon: _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.check),
                  label: Text(_isLoading ? 'Processing...' : 'Record Reduction'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Cancel button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

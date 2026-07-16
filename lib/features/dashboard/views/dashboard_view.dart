import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/custom_urdu_header.dart';
import '../viewmodels/dashboard_controller.dart';
import '../../accounts/viewmodels/accounts_controller.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(dashboardControllerProvider.notifier).refreshDashboard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardControllerProvider);
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Analytics'),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add Expense'),
            onPressed: () => _showAddExpenseDialog(context, ref),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref
                .read(dashboardControllerProvider.notifier)
                .refreshDashboard(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CustomUrduHeader(),
                  const SizedBox(height: 16),
                  // Stat Cards
                  isWide
                      ? Row(
                          children: [
                            Expanded(
                              child: _buildGradientStatCard(
                                title: 'TOTAL SALES',
                                value:
                                    'Rs. ${state.totalSales.toStringAsFixed(0)}',
                                icon: Icons.monetization_on_rounded,
                                colors: [
                                  const Color(0xFF0F9D58),
                                  const Color(0xFF0D9488),
                                ],
                                onTap: () => context.go('/sales'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildGradientStatCard(
                                title: 'ESTIMATED PROFIT',
                                value:
                                    'Rs. ${state.totalProfit.toStringAsFixed(0)}',
                                icon: Icons.trending_up_rounded,
                                colors: [
                                  const Color(0xFF3B82F6),
                                  const Color(0xFF1E3A8A),
                                ],
                                onTap: () => context.go('/reports'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildGradientStatCard(
                                title: 'TOTAL EXPENSES',
                                value:
                                    'Rs. ${state.totalExpenses.toStringAsFixed(0)}',
                                icon: Icons.receipt_long_rounded,
                                colors: [
                                  const Color(0xFFEF4444),
                                  const Color(0xFFB91C1C),
                                ],
                                onTap: () => context.go('/expenses'),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildGradientStatCard(
                              title: 'TOTAL SALES (TODAY)',
                              value:
                                  'Rs. ${state.totalSales.toStringAsFixed(0)}',
                              icon: Icons.account_balance_wallet_rounded,
                              colors: [
                                const Color(0xFF10B981),
                                const Color(0xFF047857),
                              ],
                              onTap: () => context.go('/sales'),
                            ),
                            const SizedBox(height: 16),
                            _buildGradientStatCard(
                              title: 'ESTIMATED PROFIT',
                              value:
                                  'Rs. ${state.totalProfit.toStringAsFixed(0)}',
                              icon: Icons.trending_up_rounded,
                              colors: [
                                const Color(0xFF3B82F6),
                                const Color(0xFF1E3A8A),
                              ],
                              onTap: () => context.go('/reports'),
                            ),
                            const SizedBox(height: 16),
                            _buildGradientStatCard(
                              title: 'TOTAL EXPENSES',
                              value:
                                  'Rs. ${state.totalExpenses.toStringAsFixed(0)}',
                              icon: Icons.receipt_long_rounded,
                              colors: [
                                const Color(0xFFEF4444),
                                const Color(0xFFB91C1C),
                              ],
                              onTap: () => context.go('/expenses'),
                            ),
                          ],
                        ),
                  const SizedBox(height: 32),
                  // Responsive Split Panels
                  isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildAlertsColumn(state)),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 4,
                              child: _buildSalesCard(state, context),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildAlertsColumn(state),
                            const SizedBox(height: 24),
                            _buildSalesCard(state, context),
                          ],
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildAlertsColumn(dynamic state) {
    return Column(
      children: [
        _buildAlertSection(
          title: 'Low Stock Alerts',
          icon: Icons.warning_amber_rounded,
          color: Colors.redAccent,
          products: state.lowStockProducts,
        ),
        const SizedBox(height: 20),
        _buildAlertSection(
          title: 'Near Expiry Alerts (30 Days)',
          icon: Icons.hourglass_bottom_rounded,
          color: Colors.orange,
          products: state.nearExpiryProducts,
        ),
      ],
    );
  }

  Widget _buildSalesCard(dynamic state, BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/sales'),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent Sales Invoices',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (state.recentSales.isEmpty)
                const Center(child: Text('No transactions recorded today.'))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.recentSales.length,
                  itemBuilder: (context, index) {
                    final sale = state.recentSales[index];
                    return ListTile(
                      dense: true,
                      leading: const CircleAvatar(
                        child: Icon(Icons.receipt_rounded),
                      ),
                      title: Text(sale.invoiceNumber),
                      subtitle: Text(
                        sale.timestamp.toLocal().toString().split(' ')[0],
                      ),
                      trailing: Text(
                        'Rs. ${sale.total.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientStatCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> colors,
    VoidCallback? onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Icon(icon, color: Colors.white30, size: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<dynamic> products,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${products.length}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (products.isEmpty)
              const Text('Everything looks healthy!')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final p = products[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        title.contains('Expiry')
                            ? 'Expiry: ${p.expiryDate.toString().split(' ')[0]}'
                            : 'Remaining Stock: ${p.stock} ${p.unit}',
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final personCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'Local (Food/Fuel)';
    final categories = [
      'Local (Food/Fuel)',
      'Bills & Utilities',
      'Salary',
      'Maintenance',
      'Other',
    ];
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Add Local Expense'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Expense Title',
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: categories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setStateDialog(() => category = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: personCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Expense By (Person Name)',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Amount (Rs.)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            v == null || double.tryParse(v) == null
                            ? 'Invalid Amount'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final amount = double.parse(amountCtrl.text);
                      final fullDesc = 'By: ${personCtrl.text.trim()} | ${descCtrl.text.trim()}';
                      await ref
                          .read(accountsControllerProvider.notifier)
                          .addExpense(
                            title: titleCtrl.text.trim().toUpperCase(),
                            category: category,
                            amount: amount,
                            description: fullDesc,
                          );
                      // Also refresh dashboard to update stats
                      ref
                          .read(dashboardControllerProvider.notifier)
                          .refreshDashboard();
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Expense Added Successfully!'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save Expense'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

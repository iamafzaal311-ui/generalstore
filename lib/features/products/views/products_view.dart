import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/imgbb_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../../../data/models/brand_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/supplier_model.dart';

import '../../../core/providers/global_providers.dart';
import '../viewmodels/inventory_controller.dart';

class ProductsView extends ConsumerStatefulWidget {
  const ProductsView({super.key});

  @override
  ConsumerState<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends ConsumerState<ProductsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedProductIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.toLowerCase();
      });
    });
    // Clear search when switching tabs
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _searchCtrl.clear();
        setState(() {
          _selectedProductIds.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Inventory Management',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A), // Deep blue
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Products'),
            Tab(icon: Icon(Icons.category_outlined), text: 'Categories'),
            Tab(icon: Icon(Icons.branding_watermark_outlined), text: 'Brands'),
            Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Suppliers'),
          ],
        ),
        actions: [
          if (_tabController.index == 0 && state.products.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              tooltip: 'Delete ALL Products',
              onPressed: () {
                _confirmDelete(context, () async {
                  final ctrl = ref.read(inventoryControllerProvider.notifier);
                  for (final p in state.products) {
                    await ctrl.deleteProduct(p.productId);
                  }
                  setState(() {
                    _selectedProductIds.clear();
                  });
                });
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: [
                              'Search products by name, SKU, barcode...',
                              'Search categories...',
                              'Search brands...',
                              'Search suppliers by name or phone...',
                            ].elementAt(_tabController.index),
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () => _searchCtrl.clear(),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (_tabController.index == 0 && _selectedProductIds.isNotEmpty) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          onPressed: _deleteSelectedProducts,
                          icon: const Icon(Icons.delete_rounded),
                          label: Text('Delete (${_selectedProductIds.length})'),
                        ),
                        const SizedBox(width: 16),
                      ],
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        onPressed: () => _handleAddAction(context),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add New'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildProductsTab(state),
                      _buildCategoriesTab(state),
                      _buildBrandsTab(state),
                      _buildSuppliersTab(state),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _handleAddAction(BuildContext context) {
    switch (_tabController.index) {
      case 0:
        _showProductFormDialog();
        break;
      case 1:
        _showCategoryFormDialog();
        break;
      case 2:
        _showBrandFormDialog();
        break;
      case 3:
        _showSupplierFormDialog();
        break;
    }
  }

  void _deleteSelectedProducts() {
    _confirmDelete(context, () async {
      final ctrl = ref.read(inventoryControllerProvider.notifier);
      for (final id in _selectedProductIds) {
        await ctrl.deleteProduct(id);
      }
      setState(() {
        _selectedProductIds.clear();
      });
    });
  }

  // --- TABS ---
  Widget _buildProductsTab(InventoryState state) {
    var list = state.products;
    if (_searchQuery.isNotEmpty) {
      list = list
          .where(
            (p) =>
                p.name.toLowerCase().contains(_searchQuery) ||
                (p.sku ?? '').toLowerCase().contains(_searchQuery),
          )
          .toList();
    }
    if (list.isEmpty) return const Center(child: Text('No products found.'));

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Mobile View: Cards
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final p = list[index];
              final cat =
                  state.categories
                      .where((c) => c.categoryId == p.categoryId)
                      .firstOrNull
                      ?.name ??
                  '-';
              final br =
                  state.brands
                      .where((b) => b.brandId == p.brandId)
                      .firstOrNull
                      ?.name ??
                  '-';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _selectedProductIds.contains(p.productId),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedProductIds.add(p.productId);
                            } else {
                              _selectedProductIds.remove(p.productId);
                            }
                          });
                        },
                      ),
                      p.imagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                p.imagePath!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.inventory_2,
                                      color: Colors.grey,
                                    ),
                              ),
                            )
                          : const Icon(
                              Icons.inventory_2,
                              size: 40,
                              color: Colors.grey,
                            ),
                    ],
                  ),
                  title: Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Stock: ${p.stock} ${p.unit}\nPrice: Rs. ${p.retailPrice.toStringAsFixed(0)}\nCat: $cat | Brand: $br',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _showProductFormDialog(p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(
                          context,
                          () => ref
                              .read(inventoryControllerProvider.notifier)
                              .deleteProduct(p.productId),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }

        // Desktop View: DataTable
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              showCheckboxColumn: true,
              onSelectAll: (val) {
                setState(() {
                  if (val == true) {
                    _selectedProductIds.addAll(list.map((p) => p.productId));
                  } else {
                    _selectedProductIds.clear();
                  }
                });
              },
              columns: const [
                DataColumn(label: Text('Image')),
                DataColumn(label: Text('Product Name')),
                DataColumn(label: Text('SKU / Barcode')),
                DataColumn(label: Text('Category & Brand')),
                DataColumn(label: Text('Stock')),
                DataColumn(label: Text('Price')),
                DataColumn(label: Text('Actions')),
              ],
              rows: list.map((p) {
                final cat =
                    state.categories
                        .where((c) => c.categoryId == p.categoryId)
                        .firstOrNull
                        ?.name ??
                    '-';
                final br =
                    state.brands
                        .where((b) => b.brandId == p.brandId)
                        .firstOrNull
                        ?.name ??
                    '-';
                return DataRow(
                  selected: _selectedProductIds.contains(p.productId),
                  onSelectChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedProductIds.add(p.productId);
                      } else {
                        _selectedProductIds.remove(p.productId);
                      }
                    });
                  },
                  cells: [
                    DataCell(
                      p.imagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                p.imagePath!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.inventory_2,
                                      color: Colors.grey,
                                    ),
                              ),
                            )
                          : const Icon(Icons.inventory_2, color: Colors.grey),
                    ),
                    DataCell(Text(p.name)),
                    DataCell(Text('${p.sku ?? '-'}\n${p.barcode ?? '-'}')),
                    DataCell(Text('$cat\n$br')),
                    DataCell(Text('${p.stock} ${p.unit}')),
                    DataCell(Text('Rs. ${p.retailPrice.toStringAsFixed(0)}')),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () => _showProductFormDialog(p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(
                              context,
                              () => ref
                                  .read(inventoryControllerProvider.notifier)
                                  .deleteProduct(p.productId),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoriesTab(InventoryState state) {
    var items = state.categories;
    if (_searchQuery.isNotEmpty) {
      items = items
          .where((c) => c.name.toLowerCase().contains(_searchQuery))
          .toList();
    }
    return _buildSimpleTable(
      items: items,
      columns: ['Category Name', 'Description', 'Actions'],
      cellBuilder: (c) => [
        DataCell(Text((c as CategoryModel).name)),
        DataCell(Text(c.description ?? '-')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.orange),
                onPressed: () => _showCategoryFormDialog(c),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDelete(
                  context,
                  () => ref
                      .read(inventoryControllerProvider.notifier)
                      .deleteCategory(c.categoryId),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBrandsTab(InventoryState state) {
    var items = state.brands;
    if (_searchQuery.isNotEmpty) {
      items = items
          .where((b) => b.name.toLowerCase().contains(_searchQuery))
          .toList();
    }
    return _buildSimpleTable(
      items: items,
      columns: ['Brand Name', 'Description', 'Actions'],
      cellBuilder: (b) => [
        DataCell(Text((b as BrandModel).name)),
        DataCell(Text(b.description ?? '-')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.orange),
                onPressed: () => _showBrandFormDialog(b),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDelete(
                  context,
                  () => ref
                      .read(inventoryControllerProvider.notifier)
                      .deleteBrand(b.brandId),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuppliersTab(InventoryState state) {
    var items = state.suppliers;
    if (_searchQuery.isNotEmpty) {
      items = items
          .where(
            (s) =>
                s.name.toLowerCase().contains(_searchQuery) ||
                (s.phone ?? '').toLowerCase().contains(_searchQuery) ||
                (s.contactName ?? '').toLowerCase().contains(_searchQuery),
          )
          .toList();
    }
    return _buildSimpleTable(
      items: items,
      columns: ['Company Name', 'Contact', 'Phone', 'Actions'],
      cellBuilder: (s) => [
        DataCell(Text((s as SupplierModel).name)),
        DataCell(Text(s.contactName ?? '-')),
        DataCell(Text(s.phone ?? '-')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.orange),
                onPressed: () => _showSupplierFormDialog(s),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDelete(
                  context,
                  () => ref
                      .read(inventoryControllerProvider.notifier)
                      .deleteSupplier(s.supplierId),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleTable({
    required List<dynamic> items,
    required List<String> columns,
    required List<DataCell> Function(dynamic) cellBuilder,
  }) {
    if (items.isEmpty) return const Center(child: Text('No records found.'));

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Mobile view: list of cards
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final cells = cellBuilder(items[index]);
              // Assuming first column is Name/Title, last is Actions, middle is subtitle info
              final titleText = (cells[0].child as Text).data ?? '';
              final subtitleText = cells.length > 2
                  ? (cells[1].child as Text).data ?? ''
                  : '';
              final actionsWidget = cells.last.child;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    titleText,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(subtitleText),
                  trailing: actionsWidget,
                ),
              );
            },
          );
        }

        // Desktop view: DataTable
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
              rows: items
                  .map((item) => DataRow(cells: cellBuilder(item)))
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- DIALOGS ---
  void _showCategoryFormDialog([CategoryModel? category]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: category?.name);
    final descCtrl = TextEditingController(text: category?.description);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'Add Category' : 'Edit Category'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Category Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final cat =
                    category ??
                    (CategoryModel()
                      ..categoryId = const Uuid().v4().toString().substring(
                        0,
                        8,
                      )
                      ..isDeleted = false);
                cat.name = nameCtrl.text;
                cat.description = descCtrl.text;
                ref
                    .read(inventoryControllerProvider.notifier)
                    .saveCategory(cat);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBrandFormDialog([BrandModel? brand]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: brand?.name);
    final descCtrl = TextEditingController(text: brand?.description);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(brand == null ? 'Add Brand' : 'Edit Brand'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Brand Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final b =
                    brand ??
                    (BrandModel()
                      ..brandId = const Uuid().v4().toString().substring(0, 8)
                      ..isDeleted = false);
                b.name = nameCtrl.text;
                b.description = descCtrl.text;
                ref.read(inventoryControllerProvider.notifier).saveBrand(b);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSupplierFormDialog([SupplierModel? supplier]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: supplier?.name);
    final phoneCtrl = TextEditingController(text: supplier?.phone);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(supplier == null ? 'Add Supplier' : 'Edit Supplier'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Supplier Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final s =
                    supplier ??
                    (SupplierModel()
                      ..supplierId = const Uuid().v4().toString().substring(
                        0,
                        8,
                      )
                      ..isDeleted = false
                      ..balance = 0.0);
                s.name = nameCtrl.text;
                s.phone = phoneCtrl.text;
                ref.read(inventoryControllerProvider.notifier).saveSupplier(s);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showProductFormDialog([ProductModel? product]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: product?.name);

    final generatedSku =
        'HT-PROD-${Random().nextInt(9999).toString().padLeft(4, '0')}';
    final generatedBarcode = '${Random().nextInt(999999999) + 100000000000}';
    final skuCtrl = TextEditingController(text: product?.sku ?? generatedSku);
    final barcodeCtrl = TextEditingController(
      text: product?.barcode ?? generatedBarcode,
    );

    final purchasePriceCtrl = TextEditingController(
      text: product?.purchasePrice.toString() ?? '0',
    );
    final retailPriceCtrl = TextEditingController(
      text: product?.retailPrice.toString() ?? '0',
    );
    final stockCtrl = TextEditingController(
      text: product?.stock.toString() ?? '0',
    );
    final minStockCtrl = TextEditingController(
      text: product?.minimumStock.toString() ?? '10',
    );
    final expiryCtrl = TextEditingController(
      text: product?.expiryDate != null
          ? product!.expiryDate!.toIso8601String().split('T')[0]
          : '',
    );
    final unitCtrl = TextEditingController(text: product?.unit ?? 'pcs');

    final cartonsCtrl = TextEditingController(
      text: '0',
    ); // Start at 0 so user adds new cartons
    final piecesPerCartonCtrl = TextEditingController(
      text: product?.piecesPerCarton?.toString() ?? '1',
    );
    final cartonPriceCtrl = TextEditingController(
      text: '0',
    ); // Start at 0 for new stock addition

    void recalcPrices() {
      final cPrice = double.tryParse(cartonPriceCtrl.text) ?? 0;
      final pcs = double.tryParse(piecesPerCartonCtrl.text) ?? 1;
      final ctns = double.tryParse(cartonsCtrl.text) ?? 0;
      if (cPrice > 0 && pcs > 0) {
        purchasePriceCtrl.text = (cPrice / pcs).toStringAsFixed(2);
      }

      final existingStock = product?.stock ?? 0;
      if (ctns > 0 && pcs > 0) {
        stockCtrl.text = (existingStock + (ctns * pcs)).toStringAsFixed(0);
      } else {
        stockCtrl.text = existingStock.toStringAsFixed(0);
      }
    }

    cartonPriceCtrl.addListener(recalcPrices);
    piecesPerCartonCtrl.addListener(recalcPrices);
    cartonsCtrl.addListener(recalcPrices);

    String? selectedCategory = product?.categoryId;
    String? selectedBrand = product?.brandId;
    String? uploadedImageUrl = product?.imagePath;
    bool isUploadingImage = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          final storeProfile = ref.read(storeProfileProvider);
          return AlertDialog(
            title: Text(
              product == null
                  ? 'Add Stock (${storeProfile?.storeName ?? 'General Store'})'
                  : 'Edit Product',
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width > 600
                      ? 500
                      : double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: uploadedImageUrl != null
                                  ? NetworkImage(uploadedImageUrl!)
                                  : null,
                              child: uploadedImageUrl == null
                                  ? const Icon(
                                      Icons.inventory_2,
                                      size: 40,
                                      color: Colors.grey,
                                    )
                                  : null,
                            ),
                            if (isUploadingImage)
                              const Positioned.fill(
                                child: CircularProgressIndicator(),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: theme.colorScheme.primary,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  onPressed: () async {
                                    final picker = ImagePicker();
                                    final xfile = await picker.pickImage(
                                      source: ImageSource.gallery,
                                    );
                                    if (xfile != null) {
                                      setState(() => isUploadingImage = true);
                                      try {
                                        final imgbb = ImgBBService();
                                        final url = await imgbb.uploadImage(
                                          xfile,
                                        );
                                        if (url != null) {
                                          setState(() {
                                            uploadedImageUrl = url;
                                            isUploadingImage = false;
                                          });
                                        } else {
                                          setState(
                                            () => isUploadingImage = false,
                                          );
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Failed to upload image',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        setState(
                                          () => isUploadingImage = false,
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Product Name*',
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      Consumer(
                        builder: (context, ref, child) {
                          final invState = ref.watch(
                            inventoryControllerProvider,
                          );

                          // Ensure selected values still exist in the lists, otherwise reset to null
                          if (selectedBrand != null &&
                              !invState.brands.any(
                                (b) => b.brandId == selectedBrand,
                              )) {
                            selectedBrand = null;
                          }
                          if (selectedCategory != null &&
                              !invState.categories.any(
                                (c) => c.categoryId == selectedCategory,
                              )) {
                            selectedCategory = null;
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: selectedBrand,
                                  decoration: const InputDecoration(
                                    labelText: 'Brand',
                                  ),
                                  items: invState.brands
                                      .map(
                                        (b) => DropdownMenuItem(
                                          value: b.brandId,
                                          child: Text(
                                            b.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => selectedBrand = v,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.teal,
                                ),
                                onPressed: _showBrandFormDialog,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: selectedCategory,
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                  ),
                                  items: invState.categories
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c.categoryId,
                                          child: Text(
                                            c.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => selectedCategory = v,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.teal,
                                ),
                                onPressed: _showCategoryFormDialog,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Carton & Stock Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: cartonsCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Cartons',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: piecesPerCartonCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Pieces in Carton',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: cartonPriceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Carton Price (Total Purchase)',
                          helperText: 'Auto-calculates Purchase Price',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Prices & Identifiers',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: purchasePriceCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Purchase / Wholesale Price (Rs.)*',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: retailPriceCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Retail / Sale Price (Rs.)*',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: stockCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Total Pieces in Stock*',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: unitCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Unit (pcs, etc)*',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: skuCtrl,
                              decoration: const InputDecoration(
                                labelText: 'SKU (Auto Generated)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: barcodeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Barcode (Auto Generated)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: minStockCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Low Stock Limit*',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: expiryCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Expiry Date (YYYY-MM-DD)',
                                hintText: 'Optional',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final p = product ?? ProductModel()
                      ..productId = const Uuid().v4().toString().substring(0, 8)
                      ..isDeleted = false
                      ..isDirty = true
                      ..lastUpdated = DateTime.now()
                      ..openingStock = 0
                      ..minimumStock = 0
                      ..maximumStock = 0
                      ..wholesalePrice = 0
                      ..minimumPrice = 0;

                    p.name = nameCtrl.text;
                    p.sku = skuCtrl.text;
                    p.barcode = barcodeCtrl.text;
                    p.categoryId = selectedCategory;
                    p.brandId = selectedBrand;
                    p.purchasePrice =
                        double.tryParse(purchasePriceCtrl.text) ?? 0;
                    p.retailPrice = double.tryParse(retailPriceCtrl.text) ?? 0;
                    p.stock = double.tryParse(stockCtrl.text) ?? 0;
                    p.minimumStock = double.tryParse(minStockCtrl.text) ?? 0;
                    if (expiryCtrl.text.trim().isNotEmpty) {
                      try {
                        p.expiryDate = DateTime.parse(expiryCtrl.text.trim());
                      } catch (_) {}
                    }
                    p.unit = unitCtrl.text;
                    p.imagePath = uploadedImageUrl;

                    final addedCartons = double.tryParse(cartonsCtrl.text) ?? 0;
                    p.cartons = (product?.cartons ?? 0) + addedCartons;
                    p.piecesPerCarton =
                        double.tryParse(piecesPerCartonCtrl.text) ?? 1;

                    final newCartonPrice =
                        double.tryParse(cartonPriceCtrl.text) ?? 0;
                    if (newCartonPrice > 0) {
                      p.cartonPrice =
                          newCartonPrice; // Update to the latest carton price
                    }

                    ref
                        .read(inventoryControllerProvider.notifier)
                        .saveProduct(p);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save Stock'),
              ),
            ],
          );
        },
      ),
    );
  }
}

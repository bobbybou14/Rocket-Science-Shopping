import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../service/product_service.dart';
import 'edit_product_screen.dart';
import 'product_details_screen.dart';

class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({super.key});

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  static const Color primaryRed = Color(0xFFD6001C);

  final TextEditingController searchController = TextEditingController();

  List<Product> products = [];
  bool isLoading = true;
  String? errorMessage;
  String searchText = '';
  String selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedProducts = await ProductService.getProducts();

      loadedProducts.sort(
        (a, b) => productDisplayName(a).compareTo(productDisplayName(b)),
      );

      if (!mounted) return;

      setState(() {
        products = loadedProducts;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load products: $error';
      });
    }
  }

  String productDisplayName(Product product) {
    final parts = [
      product.brand,
      product.name,
      product.size,
    ].where((value) => value.trim().isNotEmpty).toList();

    if (parts.isEmpty) {
      return product.barcode;
    }

    return parts.join(' ');
  }

  List<String> get categories {
    final values = products
        .map((product) => product.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList();

    values.sort();

    return ['All', ...values];
  }

  List<Product> get filteredProducts {
    final query = searchText.trim().toLowerCase();

    return products.where((product) {
      final matchesCategory =
          selectedCategory == 'All' ||
          product.category.trim() == selectedCategory;

      if (!matchesCategory) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final searchableText = [
        product.name,
        product.brand,
        product.category,
        product.size,
        product.barcode,
      ].join(' ').toLowerCase();

      return searchableText.contains(query);
    }).toList();
  }

  Future<void> openProductDetails(Product product) async {
    final cart = context.read<CartProvider>();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(
          product: product,
          onAddToCart: (CartItem item) {
            cart.addItem(item);
          },
        ),
      ),
    );

    if (!mounted) return;

    setState(() {});
  }

  Future<void> editProduct(Product product) async {
    final updatedProduct = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => EditProductScreen(product: product)),
    );

    if (updatedProduct == null || !mounted) {
      return;
    }

    await loadProducts();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${updatedProduct.name} updated successfully.')),
    );
  }

  void clearSearch() {
    searchController.clear();

    setState(() {
      searchText = '';
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Catalog'),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Badge(
                label: Text('${cart.itemCount}'),
                isLabelVisible: cart.itemCount > 0,
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadProducts,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _CatalogHeader(
                productCount: products.length,
                cartItemCount: cart.itemCount,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: searchController,
                  onChanged: (value) {
                    setState(() {
                      searchText = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Search products',
                    hintText: 'Name, brand, category or barcode',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchText.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: clearSearch,
                            icon: const Icon(Icons.clear),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            if (categories.length > 1)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 52,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) {
                      return const SizedBox(width: 8);
                    },
                    itemBuilder: (context, index) {
                      final category = categories[index];

                      return ChoiceChip(
                        label: Text(category),
                        selected: selectedCategory == category,
                        onSelected: (_) {
                          setState(() {
                            selectedCategory = category;
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
            if (isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(
                  message: errorMessage!,
                  onRetry: loadProducts,
                ),
              )
            else if (products.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyCatalog(),
              )
            else if (filteredProducts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _NoSearchResults(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.separated(
                  itemCount: filteredProducts.length,
                  separatorBuilder: (_, _) {
                    return const SizedBox(height: 10);
                  },
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];

                    final cartItem = cart.findByBarcode(product.barcode);

                    return _ProductCard(
                      product: product,
                      displayName: productDisplayName(product),
                      cartQuantity: cartItem?.quantity ?? 0,
                      onTap: () {
                        openProductDetails(product);
                      },
                      onEdit: () {
                        editProduct(product);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  final int productCount;
  final int cartItemCount;

  const _CatalogHeader({
    required this.productCount,
    required this.cartItemCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: _ProductCatalogScreenState.primaryRed,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$productCount '
              '${productCount == 1 ? "product" : "products"} available',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$cartItemCount in cart',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final String displayName;
  final int cartQuantity;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ProductCard({
    required this.product,
    required this.displayName,
    required this.cartQuantity,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final category = product.category.trim();
    final imageUrl = product.imageUrl.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl.isEmpty
                    ? Icon(
                        Icons.shopping_bag_outlined,
                        size: 34,
                        color: Colors.grey.shade500,
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) {
                          return Icon(
                            Icons.shopping_bag_outlined,
                            size: 34,
                            color: Colors.grey.shade500,
                          );
                        },
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      category.isEmpty ? 'Uncategorized' : category,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Barcode: ${product.barcode}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (cartQuantity > 0) ...[
                      const SizedBox(height: 7),
                      Text(
                        '$cartQuantity '
                        '${cartQuantity == 1 ? "item" : "items"} in cart',
                        style: const TextStyle(
                          color: _ProductCatalogScreenState.primaryRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Edit product',
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: _ProductCatalogScreenState.primaryRed,
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: _ProductCatalogScreenState.primaryRed,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No products available',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Products will appear here once they have been added to the catalog.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No matching products',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try changing your search or selecting a different category.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

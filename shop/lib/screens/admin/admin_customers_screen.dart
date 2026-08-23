import 'dart:async';

import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/core/utils/formatters.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/admin_models.dart';
import 'package:too_good_to_leave_shop/screens/admin/admin_customer_detail_screen.dart';

/// Every registered customer, searchable by name/phone/email — the back
/// office's support-lookup tab ("customer says their order didn't show").
/// Tapping a row opens [AdminCustomerDetailScreen] for their order history.
class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  late Future<List<AdminCustomerSummary>> _future = widget.repository
      .adminGetCustomers();
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(
      () => _future = widget.repository.adminGetCustomers(query: _query),
    );
    await _future;
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _query = query;
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        title: Text('Customers', style: context.type.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.x4,
              Space.x4,
              Space.x4,
              0,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, or email',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: colors.surfaceRaised,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: FutureBuilder<List<AdminCustomerSummary>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData && !snapshot.hasError) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        const SizedBox(height: Space.x12),
                        Center(
                          child: Text(
                            "Couldn't load customers.",
                            style: context.type.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  final customers = snapshot.data!;
                  if (customers.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: Space.x12),
                        Center(
                          child: Text(
                            _query.isEmpty
                                ? 'No customers yet.'
                                : 'No customers match this search.',
                            style: context.type.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(Space.x4),
                    itemCount: customers.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Space.x3),
                    itemBuilder: (context, i) {
                      final customer = customers[i];
                      return _CustomerRow(
                        customer: customer,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AdminCustomerDetailScreen(
                              repository: widget.repository,
                              customer: customer,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.customer, required this.onTap});

  final AdminCustomerSummary customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Space.x4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.name, style: context.type.title),
                    const SizedBox(height: Space.x1),
                    Text(
                      [
                        Fmt.maskedPhone(customer.phoneE164),
                        if (customer.email != null &&
                            customer.email!.isNotEmpty)
                          customer.email!,
                      ].join(' · '),
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

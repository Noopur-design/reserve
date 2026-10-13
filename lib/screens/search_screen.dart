import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';

/// Explore + Search tab. Shows discovery content until the user types, then
/// live results.
class SearchScreen extends StatefulWidget {
  final bool autofocus;
  const SearchScreen({super.key, this.autofocus = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _q = '';
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _run(String q) {
    _ctrl.text = q;
    _ctrl.selection = TextSelection.collapsed(offset: q.length);
    setState(() => _q = q);
    context.read<AppState>().addRecentSearch(q);
    _focus.unfocus();
  }

  Future<void> _voice() async {
    setState(() => _listening = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _listening = false);
    _run('Single Malt');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final w = MediaQuery.of(context).size.width;
    final results = state.search(_q);

    return Container(
      color: AppColors.cream,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.creamLight,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppColors.border, width: 1.4),
              ),
              child: Row(children: [
                const SizedBox(width: 20),
                const Icon(Icons.search, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) => setState(() => _q = v),
                    onSubmitted: (v) => _run(v),
                    style: T.sans(17),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: _listening ? 'Listening…' : 'Search whisky, gin, wine…',
                      hintStyle: T.sans(17, color: _listening ? AppColors.maroon : AppColors.greyLight),
                    ),
                  ),
                ),
                if (_q.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _ctrl.clear();
                      setState(() => _q = '');
                    },
                    icon: const Icon(Icons.close, color: AppColors.grey),
                  )
                else
                  IconButton(
                    onPressed: _voice,
                    icon: Icon(_listening ? Icons.graphic_eq : Icons.mic_none,
                        size: 28, color: _listening ? AppColors.maroon : AppColors.ink),
                  ),
                const SizedBox(width: 8),
              ]),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _q.trim().isEmpty ? _discover(state, w) : _results(results, w),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _results(List results, double w) {
    if (results.isEmpty) {
      return Center(
        key: const ValueKey('empty'),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search_off, size: 64, color: AppColors.greyLight),
          const SizedBox(height: 12),
          Text('No results for "$_q"', style: T.serif(20)),
          const SizedBox(height: 6),
          Text('Try whisky, gin, wine or a brand name', style: T.sans(14, color: AppColors.grey)),
        ]),
      );
    }
    return CustomScrollView(
      key: const ValueKey('results'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
          sliver: SliverToBoxAdapter(
            child: Text('${results.length} results for "$_q"', style: T.sans(15, color: AppColors.grey)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverGrid.builder(
            gridDelegate: productGridDelegate(context, w),
            itemCount: results.length,
            itemBuilder: (_, i) => FadeIn(
                delayMs: 30 * (i % 6), child: ProductCard(product: results[i], heroTag: 'search-${results[i].id}')),
          ),
        ),
      ],
    );
  }

  Widget _discover(AppState state, double w) {
    return ListView(
      key: const ValueKey('discover'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        SectionTitle('Recent Searches',
            size: 26,
            action: state.recentSearches.isEmpty ? null : 'View All',
            actionColor: AppColors.maroon,
            onAction: _allRecent),
        const SizedBox(height: 14),
        if (state.recentSearches.isEmpty)
          Text('No recent searches', style: T.sans(15, color: AppColors.grey))
        else
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: state.recentSearches
                .take(9)
                .map((s) => Pressable(
                      onTap: () => _run(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.chip,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(s, style: T.sans(15.5)),
                      ),
                    ))
                .toList(),
          ),
        const SizedBox(height: 30),
        Row(children: [
          Text('Trending Searches', style: T.serif(26, weight: FontWeight.w600)),
          const SizedBox(width: 14),
          Expanded(child: Container(height: 1, color: AppColors.border)),
        ]),
        const SizedBox(height: 6),
        ...trendingSearches.map((t) => InkWell(
              onTap: () => _run(t),
              child: SizedBox(
                height: 64,
                child: Row(children: [
                  const Icon(Icons.north_east, size: 28),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Container(
                      height: 64,
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                      child: Row(children: [
                        Expanded(child: Text(t, style: T.sans(18))),
                        const Icon(Icons.chevron_right, color: AppColors.grey),
                      ]),
                    ),
                  ),
                ]),
              ),
            )),
        const SizedBox(height: 32),
        SectionTitle('Popular Brands',
            size: 26,
            action: 'View All',
            actionColor: AppColors.maroon,
            onAction: () => _run('Whisky')),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: brands
              .map((b) => Expanded(
                    child: Pressable(
                      onTap: () => _run(b.$1 == 'Royal Stag' ? 'Whisky' : b.$1),
                      child: Column(children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ClipOval(child: Image.asset(b.$2, fit: BoxFit.cover)),
                        ),
                        const SizedBox(height: 10),
                        Text(b.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.sans(15)),
                      ]),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 32),
        SectionTitle('Categories',
            size: 26, action: 'View All', actionColor: AppColors.maroon, onAction: _allCategories),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.3),
          itemBuilder: (_, i) => FadeIn(delayMs: 40 * i, child: CategoryTile(category: categories[i], fontSize: 19)),
        ),
      ],
    );
  }

  void _allRecent() {
    final state = context.read<AppState>();
    showAppSheet(
      context,
      title: 'Recent Searches',
      child: Column(children: [
        ...state.recentSearches.map((s) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history, color: AppColors.grey),
              title: Text(s, style: T.sans(16)),
              onTap: () {
                Navigator.pop(context);
                _run(s);
              },
            )),
        const SizedBox(height: 10),
        OutlineButtonX(
          label: 'Clear History',
          arrow: false,
          fontSize: 18,
          onTap: () {
            state.clearRecentSearches();
            Navigator.pop(context);
          },
        ),
      ]),
    );
  }

  void _allCategories() {
    showAppSheet(
      context,
      title: 'All Categories',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.45),
        itemBuilder: (ctx, i) => CategoryTile(category: categories[i]),
      ),
    );
  }
}

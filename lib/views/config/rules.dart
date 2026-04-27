import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/config.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/views/profiles/override_profile.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddedRulesView extends ConsumerStatefulWidget {
  const AddedRulesView({super.key});

  @override
  ConsumerState<AddedRulesView> createState() => _AddedRulesViewState();
}

class _AddedRulesViewState extends ConsumerState<AddedRulesView> {
  final Set<String> _selectedRules = {};
  ClashConfigSnippet _snippet = const ClashConfigSnippet();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSnippet();
    });
  }

  Future<void> _loadSnippet() async {
    final profileId = globalState.config.currentProfileId;
    if (profileId == null) {
      return;
    }
    final rawConfig = await globalState.getProfileConfig(profileId);
    if (!mounted) {
      return;
    }
    setState(() {
      _snippet = ClashConfigSnippet.fromJson(rawConfig);
    });
  }

  List<Rule> _rulesFromConfig(List<String> rules) => rules
      .map(
        (value) => Rule(id: value, value: value),
      )
      .toList();

  void _updateRules(List<Rule> rules) {
    ref.read(patchClashConfigProvider.notifier).updateState(
          (state) => state.copyWith(
            rule: rules.map((item) => item.value).toList(),
          ),
        );
  }

  Future<void> _handleAddOrUpdate([Rule? rule]) async {
    final res = await globalState.showCommonDialog<Rule>(
      child: AddRuleDialog(
        rule: rule,
        snippet: _snippet,
      ),
    );
    if (res == null) {
      return;
    }
    final rules = _rulesFromConfig(ref.read(patchClashConfigProvider).rule);
    final index = rules.indexWhere((item) => item.id == rule?.id);
    if (index == -1) {
      _updateRules([res, ...rules]);
      return;
    }
    rules[index] = res;
    _updateRules(rules);
  }

  Future<void> _handleDelete(List<Rule> rules) async {
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: appLocalizations.deleteMultipTip(appLocalizations.rule),
      ),
    );
    if (res != true) {
      return;
    }
    _updateRules(
      rules.where((item) => !_selectedRules.contains(item.id)).toList(),
    );
    setState(_selectedRules.clear);
  }

  void _handleSelect(String ruleId) {
    setState(() {
      if (_selectedRules.contains(ruleId)) {
        _selectedRules.remove(ruleId);
      } else {
        _selectedRules.add(ruleId);
      }
    });
  }

  void _handleSelectAll(List<Rule> rules) {
    setState(() {
      final ids = rules.map((item) => item.id).toSet();
      if (_selectedRules.containsAll(ids)) {
        _selectedRules.clear();
      } else {
        _selectedRules
          ..clear()
          ..addAll(ids);
      }
    });
  }

  Widget _buildItem(Rule rule) {
    final isSelected = _selectedRules.contains(rule.id);
    final isEditing = _selectedRules.isNotEmpty;
    return Padding(
      key: ValueKey(rule.id),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: CommonCard(
        padding: EdgeInsets.zero,
        radius: 18,
        type: CommonCardType.filled,
        isSelected: isSelected,
        onPressed: () {
          if (isEditing) {
            _handleSelect(rule.id);
          } else {
            _handleAddOrUpdate(rule);
          }
        },
        child: ListTile(
          minTileHeight: 0,
          minVerticalPadding: 0,
          titleTextStyle: context.textTheme.bodyMedium?.toJetBrainsMono,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          title: Text(rule.value),
          trailing: isEditing
              ? CommonCheckBox(
                  value: isSelected,
                  isCircle: true,
                  onChanged: (_) => _handleSelect(rule.id),
                )
              : IconButton(
                  onPressed: () => _handleSelect(rule.id),
                  icon: const Icon(Icons.check_circle_outline),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rules = _rulesFromConfig(
      ref.watch(patchClashConfigProvider.select((state) => state.rule)),
    );
    return CommonScaffold(
      disableBackground: true,
      title: appLocalizations.addedRules,
      actions: [
        if (_selectedRules.isNotEmpty)
          IconButton(
            onPressed: () => _handleDelete(rules),
            icon: const Icon(Icons.delete),
          ),
        if (_selectedRules.isNotEmpty)
          TextButton(
            onPressed: () => _handleSelectAll(rules),
            child: Text(appLocalizations.selectAll),
          )
        else
          TextButton(
            onPressed: _handleAddOrUpdate,
            child: Text(appLocalizations.add),
          ),
      ],
      body: rules.isEmpty
          ? NullStatus(label: appLocalizations.nullTip(appLocalizations.rule))
          : ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemBuilder: (_, index) => ReorderableDelayedDragStartListener(
                key: ValueKey(rules[index].id),
                index: index,
                child: _buildItem(rules[index]),
              ),
              itemCount: rules.length,
              onReorder: (oldIndex, newIndex) {
                final nextRules = List<Rule>.from(rules);
                var targetIndex = newIndex;
                if (oldIndex < targetIndex) {
                  targetIndex -= 1;
                }
                final item = nextRules.removeAt(oldIndex);
                nextRules.insert(targetIndex, item);
                _updateRules(nextRules);
              },
            ),
    );
  }
}

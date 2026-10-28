import 'package:flutter/foundation.dart';

import '../models/patient.dart';
import '../repositories/patient_repository.dart';

/// قائمة المرضى + البحث + الترقيم.
class PatientsProvider extends ChangeNotifier {
  PatientsProvider(this._repo);

  final PatientRepository _repo;

  List<Patient> _items = [];
  String _query = '';
  bool _showArchived = false;
  bool _loading = false;
  int _total = 0;
  int _offset = 0;
  int _request = 0;
  final int _pageSize = 100;

  List<Patient> get items => _items;
  bool get loading => _loading;
  int get total => _total;
  String get query => _query;
  bool get showArchived => _showArchived;
  bool get hasMore => _items.length < _total;

  Future<void> load({bool reset = true}) async {
    if (reset) {
      _offset = 0;
      _items = [];
    }
    final request = ++_request;
    final query = _query;
    final archived = _showArchived;
    final offset = _offset;
    _loading = true;
    notifyListeners();
    try {
      final total = await _repo.count(query: query, onlyActive: !archived);
      final items = await _repo.search(
        query: query,
        onlyActive: !archived,
        limit: _pageSize,
        offset: offset,
      );
      if (request != _request) return;
      _total = total;
      _items = items;
    } finally {
      if (request == _request) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || _loading) return;
    final query = _query;
    final archived = _showArchived;
    final nextOffset = _items.length;
    final request = ++_request;
    _loading = true;
    notifyListeners();
    try {
      final more = await _repo.search(
        query: query,
        onlyActive: !archived,
        limit: _pageSize,
        offset: nextOffset,
      );
      if (request == _request) {
        _offset = nextOffset;
        final ids = _items.map((p) => p.id).toSet();
        _items = [..._items, ...more.where((p) => !ids.contains(p.id))];
      }
    } finally {
      if (request == _request) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  void setQuery(String q) {
    _query = q;
    load();
  }

  void setShowArchived(bool v) {
    _showArchived = v;
    load();
  }

  Future<int> add(Patient p) async {
    final id = await _repo.insert(p);
    await load();
    return id;
  }

  Future<void> edit(Patient p) async {
    await _repo.update(p);
    await load();
  }

  Future<void> archive(int id) async {
    await _repo.archive(id);
    await load();
  }

  Future<void> restore(int id) async {
    await _repo.restore(id);
    await load();
  }

  Future<void> remove(int id) async {
    await _repo.deletePermanently(id);
    await load();
  }
}


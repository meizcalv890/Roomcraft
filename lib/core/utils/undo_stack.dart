/// Riwayat undo/redo generik. Simpan keadaan SEBELUM perubahan lewat
/// [record]; [undo] dan [redo] menerima keadaan saat ini dan mengembalikan
/// keadaan yang harus dipulihkan (atau null jika kosong).
class UndoStack<T extends Object> {
  UndoStack({this.limit = 100});

  final int limit;

  final List<T> _undo = [];
  final List<T> _redo = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void record(T state) {
    _undo.add(state);

    if (_undo.length > limit) _undo.removeAt(0);

    _redo.clear();
  }

  T? undo(T current) {
    if (_undo.isEmpty) return null;

    _redo.add(current);
    return _undo.removeLast();
  }

  T? redo(T current) {
    if (_redo.isEmpty) return null;

    _undo.add(current);
    return _redo.removeLast();
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}

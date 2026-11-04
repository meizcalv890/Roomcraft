/// Pembuat ID unik berbasis waktu yang dijamin selalu naik, sehingga dua
/// pemanggilan dalam mikrodetik yang sama tidak menghasilkan ID kembar.
class IdGenerator {
  IdGenerator._();

  static int _last = 0;

  static String next() {
    var id = DateTime.now().microsecondsSinceEpoch;

    if (id <= _last) id = _last + 1;

    _last = id;
    return id.toString();
  }
}
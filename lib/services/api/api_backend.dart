enum LiveGoApiBackend {
  anichin,
  dobda,
}

extension LiveGoApiBackendX on LiveGoApiBackend {
  String get label {
    switch (this) {
      case LiveGoApiBackend.anichin:
        return 'ANICHIN API';
      case LiveGoApiBackend.dobda:
        return 'DOBDA API';
    }
  }

  String get key {
    switch (this) {
      case LiveGoApiBackend.anichin:
        return 'anichin';
      case LiveGoApiBackend.dobda:
        return 'dobda';
    }
  }
}

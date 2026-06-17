enum LiveGoApiBackend {
  dobda,
}

extension LiveGoApiBackendX on LiveGoApiBackend {
  String get label => 'LIVEGO SOURCE';

  String get key => 'dobda';
}

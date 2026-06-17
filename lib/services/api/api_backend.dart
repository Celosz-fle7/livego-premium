enum LiveGoApiBackend {
  nobuzero,
}

extension LiveGoApiBackendX on LiveGoApiBackend {
  String get label => 'LIVEGO SOURCE';

  String get key => 'nobuzero';
}

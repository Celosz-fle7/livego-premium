enum LiveGoApiBackend {
  direct,
}

extension LiveGoApiBackendX on LiveGoApiBackend {
  String get label => 'DIRECT';

  String get key => 'direct';
}

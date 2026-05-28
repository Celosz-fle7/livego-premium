class LiveGoEpisode {
  final String id;
  final int index;
  final String title;

  const LiveGoEpisode({
    required this.id,
    required this.index,
    required this.title,
  });

  factory LiveGoEpisode.fromJson(Map<String, dynamic> json) {
    return LiveGoEpisode(
      id: '${json['id'] ?? json['chapterId'] ?? json['index'] ?? ''}',
      index: int.tryParse('${json['index'] ?? json['id'] ?? 0}') ?? 0,
      title: '${json['title'] ?? 'Episode ${json['index'] ?? json['id'] ?? ''}'}',
    );
  }
}

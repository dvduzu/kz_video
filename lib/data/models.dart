class VideoInfo {
  final String bvid;
  final String title;
  final String pic;
  final int duration;
  final String owner;
  final int view;
  final int pubdate;
  final int mid;
  final int tid;
  VideoInfo({required this.bvid, required this.title, required this.pic, required this.duration, required this.owner, required this.view, this.pubdate = 0, this.mid = 0, this.tid = 0});
  factory VideoInfo.fromJson(Map<String, dynamic> json) => VideoInfo(
    bvid: json['bvid'] as String,
    title: json['title'] as String,
    pic: json['pic'] as String,
    duration: json['duration'] as int,
    owner: json['owner'] as String,
    view: json['view'] as int,
    pubdate: json['pubdate'] as int? ?? 0,
    mid: json['mid'] as int? ?? 0,
    tid: json['tid'] as int? ?? 0,
  );
  Map<String, dynamic> toJson() => {'bvid': bvid, 'title': title, 'pic': pic, 'duration': duration, 'owner': owner, 'view': view, 'pubdate': pubdate, 'mid': mid, 'tid': tid};
}
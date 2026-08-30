class VideoInfo {
  final String bvid;
  final String title;
  final String pic;
  final int duration;
  final String owner;
  final int view;
  VideoInfo({required this.bvid, required this.title, required this.pic, required this.duration, required this.owner, required this.view});
  factory VideoInfo.fromJson(Map<String, dynamic> json) => VideoInfo(
    bvid: json['bvid'] as String,
    title: json['title'] as String,
    pic: json['pic'] as String,
    duration: json['duration'] as int,
    owner: json['owner'] as String,
    view: json['view'] as int,
  );
  Map<String, dynamic> toJson() => {'bvid': bvid, 'title': title, 'pic': pic, 'duration': duration, 'owner': owner, 'view': view};
}

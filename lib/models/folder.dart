class Folder {
  String id;
  String name;
  List<String> imagePaths;

  Folder({required this.id, required this.name, this.imagePaths = const []});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'imagePaths': imagePaths};
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'],
      name: map['name'],
      imagePaths: List<String>.from(map['imagePaths']),
    );
  }
}

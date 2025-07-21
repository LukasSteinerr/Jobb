import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/folder.dart';
import 'folder_screen.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class FolderListScreen extends StatefulWidget {
  const FolderListScreen({super.key});

  @override
  _FolderListScreenState createState() => _FolderListScreenState();
}

class _FolderListScreenState extends State<FolderListScreen> {
  List<Folder> _folders = [];
  final _folderNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final folderListJson = prefs.getStringList('folders') ?? [];
    setState(() {
      _folders = folderListJson
          .map((json) => Folder.fromMap(jsonDecode(json)))
          .toList();
    });
  }

  Future<void> _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final folderListJson = _folders
        .map((folder) => jsonEncode(folder.toMap()))
        .toList();
    await prefs.setStringList('folders', folderListJson);
  }

  void _addFolder() {
    if (_folderNameController.text.isNotEmpty) {
      final newFolder = Folder(
        id: Uuid().v4(),
        name: _folderNameController.text,
        imagePaths: [],
      );
      setState(() {
        _folders.add(newFolder);
      });
      _saveFolders();
      _folderNameController.clear();
      Navigator.of(context).pop();
    }
  }

  void _deleteFolder(int index) {
    setState(() {
      _folders.removeAt(index);
    });
    _saveFolders();
  }

  void _renameFolder(int index, String newName) {
    setState(() {
      _folders[index].name = newName;
    });
    _saveFolders();
  }

  void _showAddFolderDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Folder'),
          content: TextField(
            controller: _folderNameController,
            decoration: const InputDecoration(hintText: "Folder Name"),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(onPressed: _addFolder, child: const Text('Create')),
          ],
        );
      },
    );
  }

  void _showRenameFolderDialog(int index, String currentName) {
    _folderNameController.text = currentName;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Folder'),
          content: TextField(
            controller: _folderNameController,
            decoration: const InputDecoration(hintText: "New Folder Name"),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                _folderNameController.clear();
              },
            ),
            TextButton(
              onPressed: () {
                if (_folderNameController.text.isNotEmpty) {
                  _renameFolder(index, _folderNameController.text);
                  Navigator.of(context).pop();
                  _folderNameController.clear();
                }
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Folders')),
      body: ListView.builder(
        itemCount: _folders.length,
        itemBuilder: (context, index) {
          final folder = _folders[index];
          return Slidable(
            key: ValueKey(folder.id),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) => _deleteFolder(index),
                  backgroundColor: const Color(0xFFFE4A49),
                  foregroundColor: Colors.white,
                  icon: Icons.delete,
                  label: 'Delete',
                ),
                SlidableAction(
                  onPressed: (context) =>
                      _showRenameFolderDialog(index, folder.name),
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  icon: Icons.edit,
                  label: 'Rename',
                ),
              ],
            ),
            child: ListTile(
              title: Text(folder.name),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => FolderScreen(
                      folder: folder,
                      onUpdate: (updatedFolder) {
                        setState(() {
                          _folders[index] = updatedFolder;
                        });
                        _saveFolders();
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFolderDialog,
        child: const Icon(Icons.create_new_folder),
      ),
    );
  }
}

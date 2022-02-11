import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../domain/sysmac_project.dart';
import 'data_type.dart';
import 'event.dart';
import 'project_index.dart';
import 'variable.dart';

class SysmacProjectFactory {
  SysmacProject create(String sysmacProjectFilePath) {
    var sysmacProjectArchive = SysmacProjectArchive(sysmacProjectFilePath);
    var dataTypeTree = DataTypeTreeFactory().create(sysmacProjectArchive);
    var globalVariableService =
        GlobalVariableService(sysmacProjectArchive, dataTypeTree);
    var eventService = EventService(globalVariableService);

    return SysmacProject(
      dataTypeTree: dataTypeTree,
      globalVariableService: globalVariableService,
      eventService: eventService,
    );
  }
}

/// Represents a physical Sysmac project file,
/// which is actually a zip [Archive] containing [ArchiveFile]s
class SysmacProjectArchive {
  static String extension = 'smc2';

  late ProjectIndexXml projectIndexXml;

  SysmacProjectArchive(String sysmacProjectFilePath) {
    _validateNotEmpty(sysmacProjectFilePath);
    final file = File(sysmacProjectFilePath);
    _validateExtension(file);
    _validateExists(file);
    Archive archive = readArchive(file);
    projectIndexXml = ProjectIndexXml(archive);
  }

  _validateExtension(File file) {
    if (!file.path.toLowerCase().endsWith(".$extension")) {
      throw ArgumentError(
          "does not end with .$extension extension", 'sysmacProjectFilePath');
    }
  }

  _validateExists(File file) {
    if (!file.existsSync()) {
      throw ArgumentError('does not point to a existing Sysmac project file',
          'sysmacProjectFilePath');
    }
  }

  _validateNotEmpty(String sysmacProjectFilePath) {
    if (sysmacProjectFilePath.trim().isEmpty) {
      throw ArgumentError('may not be empty', 'sysmacProjectFilePath');
    }
  }

  Archive readArchive(File file) {
    final bytes = file.readAsBytesSync();
    return ZipDecoder().decodeBytes(bytes);
  }
}

/// Parses the XML of an [ArchiveFile] inside a [SysmacProjectFile]
/// to an [XmlDocument] and can convert it to more meaningful domain objects
abstract class ArchiveXml {
  final XmlDocument xmlDocument;

  ArchiveXml.fromArchiveFile(ArchiveFile archiveFile)
      : this.fromXml(_convertContentToUtf8(archiveFile));

  ArchiveXml.fromXml(String xml) : xmlDocument = XmlDocument.parse(xml);

  static String _convertContentToUtf8(ArchiveFile archiveFile) {
    var content = archiveFile.content;
    return utf8.decode(content);
  }
}

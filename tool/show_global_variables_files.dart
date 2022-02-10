import 'package:sysmac_cmd/infrastructure/data_type.dart';
import 'package:sysmac_cmd/infrastructure/sysmac_project.dart';

import '../test/infrastructure/test_resource.dart';

main() {
  var sysmacProjectArchive =
      SysmacProjectArchive(SysmacProjectTestResource().file.path);
  var dataTypeTree = DataTypeTreeFactory().create(sysmacProjectArchive);
  for (var file in sysmacProjectArchive.projectIndexXml
      .globalVariableArchiveXmlFiles(dataTypeTree)) {
    print(file.nameSpacePath);
    print(file.xmlDocument.toXmlString(pretty: true));
    print("");
  }
}

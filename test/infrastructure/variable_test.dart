import 'dart:io';

import 'package:sysmac_cmd/domain/base_type.dart';
import 'package:sysmac_cmd/infrastructure/sysmac_project.dart';
import 'package:sysmac_cmd/infrastructure/variable.dart';

import 'test_resource.dart';
import 'package:test/test.dart';

main() {
  File file = SysmacProjectTestResource().file;
  var sysmacProject = SysmacProjectFactory().create(file.path);
  var variableService = sysmacProject.globalVariableService;

  group('class: $GlobalVariableService', () {
    group('field: globalVariables', () {
      var results = variableService.variables;
      test('variables isNot Empty', () {
        expect(results, isNotEmpty);
      });
    });
    group('method: findVariablesByName', () {
      var nameToFind = 'LineNumber';
      var results = variableService.findVariablesByName(nameToFind);
      test('contains one variable with $nameToFind', () {
        expect(results, hasLength(1));
      });
    });
    group('method: findVariablesWithEventsGlobalName', () {
      var results = variableService.findVariablesWithEventGlobalName();
      test(
          'contains one variable with ${GlobalVariableService.eventGlobalVariableName}',
          () {
        expect(results, hasLength(1));
        expect(results[0].name, GlobalVariableService.eventGlobalVariableName);
        expect(results[0].baseType, isA<DataTypeReference>());
        expect(results[0].children.isNotEmpty, true);
        expect((results[0].baseType as DataTypeReference).dataType.baseType,
            isA<Struct>());
      });
    });
  });
}

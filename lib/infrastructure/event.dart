import 'package:recase/recase.dart';
import 'package:sysmac_generator/domain/base_type.dart';
import 'package:sysmac_generator/domain/data_type.dart';
import 'package:sysmac_generator/domain/event/event.dart';
import 'package:sysmac_generator/domain/event/parser/acknowledge_parser.dart';
import 'package:sysmac_generator/domain/event/parser/component_code_parser.dart';
import 'package:sysmac_generator/domain/event/parser/event_parser.dart';
import 'package:sysmac_generator/domain/event/parser/panel_nr_parser.dart';
import 'package:sysmac_generator/domain/event/parser/priority_parser.dart';
import 'package:sysmac_generator/domain/event/parser/site_nr_parser.dart';
import 'package:sysmac_generator/domain/event/parser/solution_parser.dart';
import 'package:sysmac_generator/domain/namespace.dart';
import 'package:sysmac_generator/domain/sysmac_project.dart';
import 'package:sysmac_generator/domain/variable.dart';
import 'package:sysmac_generator/util/sentence.dart';

class EventService {
  // final GlobalVariableService globalVariableService;

  final Site site;
  final ElectricPanel electricPanel;
  static final _groupNameIndex = 1;
  static final _eventTagsParser = EventTagsParser();

  EventService({required this.site, required this.electricPanel});

  List<EventGroup> createFromVariable(List<Variable> variables) {
    List<List<NameSpace>> eventPaths = _createEventPaths(variables);

    List<EventGroup> eventGroups = [];
    EventCounter eventCounter = EventCounter();
    for (var eventPath in eventPaths) {
      if (_newEventGroup(eventGroups, eventPath)) {
        EventGroup eventGroup = EventGroup(_createEventGroupName(eventPath));
        eventGroups.add(eventGroup);
      }
      EventGroup eventGroup = eventGroups.last;
      eventGroup.children
          .addAll(_createEvents(eventGroup, eventPath, eventCounter));
    }

    return eventGroups;
  }

  bool _newEventGroup(List<EventGroup> eventGroups, List<NameSpace> eventPath) {
    return eventGroups.isEmpty ||
        !_createEventGroupName(eventPath)
            .toLowerCase()
            .startsWith(eventGroups.last.name.toLowerCase());
  }

  List<List<NameSpace>> _createEventPaths(List<Variable> variables) {
    List<List<NameSpace>> eventPaths = [];

    for (var variable in variables) {
      eventPaths.addAll(variable.findPaths((nameSpace) =>
          nameSpace is DataType &&
          nameSpace.baseType is VbBoolean &&
          nameSpace.children.isEmpty));
    }

    _sortOnFirstDataTypeNames(eventPaths);

    return eventPaths;
  }

  /// Sort on the name of the first [DataType] members of the EventGlobal variable
  void _sortOnFirstDataTypeNames(List<List<NameSpace>> eventPaths) {
    eventPaths.sort((a, b) => a[1].name.compareTo(b[1].name));
  }

  List<Event> _createEvents(EventGroup eventGroup, List<NameSpace> eventPath,
      EventCounter eventCounter) {
    var parsedComments = _parseComments(eventPath);
    var eventTags = _findEventTags(parsedComments);
    var groupName1 = eventGroup.name;
    var groupName2 = _findGroupName2(groupName1, eventPath);
    var priority = _findPriority(eventTags);
    var componentCode = _findComponentCode(eventTags);
    var message = _findMessage(parsedComments);
    Event event = Event(
      groupName1: groupName1,
      groupName2: groupName2,
      id: eventCounter.next,
      componentCode: componentCode == null ? '' : componentCode.toCode(),
      expression: _createExpression(eventPath),
      priority: priority,
      message: message,
      solution: _findSolution(eventTags, componentCode),
      acknowledge: _findAcknowledge(eventTags, priority),
    );
    return [
      event
    ]; //TODO return multiple events if eventPath contains DataTypes with baseType.array!=null
  }

  String _createExpression(List<NameSpace> eventPath) {
    List<NameSpace> filteredEventPath = eventPath
        .where((nameSpace) => nameSpace is! Site && nameSpace is! ElectricPanel)
        .toList();
    return filteredEventPath.map((nameSpace) => nameSpace.name).join('.');
  }

  List<EventTag> _findEventTags(List<dynamic> parsedComments) =>
      parsedComments.whereType<EventTag>().toList();

  String _joinComments(List<NameSpace> eventPath) {
    var joinedComments = '';
    for (var nameSpace in eventPath) {
      if (nameSpace is NameSpaceWithTypeAndComment) {
        if (joinedComments.isNotEmpty) {
          joinedComments += ' ';
        }
        joinedComments += nameSpace.comment;
        if (nameSpace is NameSpaceWithTypeAndComment &&
            nameSpace.baseType is DataTypeReference) {
          var dataTypeReference = nameSpace.baseType as DataTypeReference;
          joinedComments += ' ' + dataTypeReference.dataType.comment;
        }
      }
    }
    return joinedComments;
  }

  List<dynamic> _parseComments(List<NameSpace> eventPath) {
    String joinedComments = _joinComments(eventPath);
    var result = _eventTagsParser.parse(joinedComments).value;
    result.insert(0, PanelNumberTag(electricPanel.number));
    result.insert(0, SiteNumberTag(site.number));
    return result;
  }

  String _findMessage(List parsedComments) =>
      Sentence.normalize(parsedComments.whereType<String>().join());

  ComponentCode? _findComponentCode(List<EventTag> eventTags) {
    var partialComponentCodes =
        eventTags.whereType<ComponentCodeTag>().toList();
    if (partialComponentCodes.isNotEmpty) {
      var partialComponentCode = partialComponentCodes.first;
      return ComponentCode(
        site: Site(_findSiteNumberTag(eventTags).number),
        electricPanel: ElectricPanel(
            number: _findPanelNumberTag(eventTags).number,
            name: electricPanel.name),
        pageNumber: partialComponentCode.pageNumber,
        letters: partialComponentCode.letters,
        columnNumber: partialComponentCode.columnNumber,
      );
    } else {
      return null;
    }
  }

  PanelNumberTag _findPanelNumberTag(List<EventTag> eventTags) =>
      eventTags.whereType<PanelNumberTag>().last;

  SiteNumberTag _findSiteNumberTag(List<EventTag> eventTags) =>
      eventTags.whereType<SiteNumberTag>().last;

  EventPriority _findPriority(List<EventTag> eventTags) {
    var priorityTags = eventTags.whereType<PriorityTag>();
    if (priorityTags.isEmpty) {
      return EventPriorities.medium;
    } else {
      return priorityTags.last.priority;
    }
  }

  bool _findAcknowledge(List<EventTag> eventTags, EventPriority priority) {
    var acknowledgeTags = eventTags.whereType<AcknowledgeTag>();
    if (acknowledgeTags.isEmpty) {
      return priority != EventPriorities.info;
    } else {
      return acknowledgeTags.last.acknowledge;
    }
  }

  String _findGroupName2(
    String groupName1,
    List<NameSpace> eventPath,
  ) {
    var groupName2 = _createEventGroupName(eventPath);
    if (groupName1 == groupName2) {
      return '';
    } else {
      return groupName2.substring(groupName1.length).trim();
    }
  }

  _findSolution(List<EventTag> eventTags, ComponentCode? componentCode) {
    var solutionTexts = eventTags
        .whereType<SolutionTag>()
        .map((solutionTag) => solutionTag.solution)
        .toList();
    if (componentCode != null) {
      solutionTexts.add(
          'See component ${componentCode.toCode()} on electric diagram ${componentCode.site.code}.${componentCode.electricPanel.code} on page ${componentCode.pageNumber} at column ${componentCode.columnNumber}.');
    }
    return solutionTexts.join(' ');
  }

  String _createEventGroupName(List<NameSpace> eventPath) {
    return eventPath[_groupNameIndex].name.titleCase;
  }
}

class EventCounter {
  int value = 1;

  String get next => (value++).toString();
}

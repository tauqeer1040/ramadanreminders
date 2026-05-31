class OnboardingData {
  final DateTime startTime = DateTime.now();
  String? displayName;
  String? catName;
  int? age;
  int? phoneHours;

  String? intentionAnswer;
  String? heartAnswer;
  String? challengeAnswer;
  String? journeyAnswer;

  String? intentionAnalogy;
  String? heartAnalogy;
  String? challengeAnalogy;
  String? journeyAnalogy;

  String? journalEntry;
  List<String> journalTags = [];
  List<String> journalAnalogies = [];
  String? lastGeneratedJournalEntry;

  String? commitmentLevel;

  bool notificationsEnabled = false;
  bool locationEnabled = false;
}

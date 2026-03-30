class StatusConfig {
  final List<String> taskStatuses;
  final List<String> salesCategories;
  final List<String> salesStatuses;

  StatusConfig({
    required this.taskStatuses,
    required this.salesCategories,
    required this.salesStatuses,
  });

  factory StatusConfig.fromJson(Map<String, dynamic> json) {
    return StatusConfig(
      taskStatuses: json['taskStatuses'] != null
          ? List<String>.from(json['taskStatuses'])
          : ['pending', 'in_progress', 'completed', 'cancelled'],
      salesCategories: json['salesCategories'] != null
          ? List<String>.from(json['salesCategories'])
          : ['hot', 'warm', 'cold'],
      salesStatuses: json['salesStatuses'] != null
          ? List<String>.from(json['salesStatuses'])
          : ['lead', 'prospect', 'negotiation', 'closed', 'disqualified'],
    );
  }

  static StatusConfig get defaultConfig => StatusConfig(
    taskStatuses: ['pending', 'in_progress', 'completed', 'cancelled'],
    salesCategories: ['hot', 'warm', 'cold'],
    salesStatuses: [
      'lead',
      'prospect',
      'negotiation',
      'closed',
      'disqualified',
    ],
  );
}

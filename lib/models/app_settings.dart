class AppSettings {
  static const double defaultMonthlyBudget = 600;

  final double monthlyBudget;

  const AppSettings({this.monthlyBudget = defaultMonthlyBudget});

  const AppSettings.defaults() : monthlyBudget = defaultMonthlyBudget;

  AppSettings copyWith({double? monthlyBudget}) {
    return AppSettings(monthlyBudget: monthlyBudget ?? this.monthlyBudget);
  }
}

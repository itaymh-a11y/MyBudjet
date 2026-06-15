class FirestorePaths {
  static String userDoc(String userId) => 'users/$userId';

  // Personal
  static String personalCategories(String userId) =>
      'users/$userId/personal_categories';

  static String personalExpenses(String userId) =>
      'users/$userId/personal_expenses';

  static String personalCycles(String userId) =>
      'users/$userId/personal_cycles';

  static String recurringExpenseTemplates(String userId) =>
      'users/$userId/recurring_expense_templates';

  // Pension
  static String pensionMonths(String userId) =>
      'users/$userId/pension_months';
  static String workHoursEntries(String userId) =>
      'users/$userId/work_hours_entries';
  static String businessIncomeEntries(String userId) =>
      'users/$userId/business_income_entries';
  static String businessExpenseEntries(String userId) =>
      'users/$userId/business_expense_entries';
  static String incomeWorkLogs(String userId) =>
      'users/$userId/income_work_logs';
  static String scholarshipEntries(String userId) =>
      'users/$userId/scholarship_entries';

  // Savings plan
  static String savingsSettingsDoc(String userId) =>
      'users/$userId/savings_settings/savings';

  static String savingsMonths(String userId) => 'users/$userId/savings_months';
}


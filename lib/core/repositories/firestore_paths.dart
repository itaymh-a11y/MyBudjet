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

  // Savings plan
  static String savingsSettingsDoc(String userId) =>
      'users/$userId/savings_settings/savings';

  static String savingsMonths(String userId) => 'users/$userId/savings_months';
}


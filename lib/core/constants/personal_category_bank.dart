class PredefinedPersonalCategory {
  final String name;
  final String iconName;

  const PredefinedPersonalCategory({
    required this.name,
    required this.iconName,
  });
}

class PersonalCategoryBank {
  static const List<PredefinedPersonalCategory> categories = [
    // General categories
    PredefinedPersonalCategory(name: 'מגורים', iconName: 'home'),
    PredefinedPersonalCategory(name: 'חשבונות', iconName: 'receipt_long'),
    PredefinedPersonalCategory(name: 'מזון', iconName: 'shopping_cart'),
    PredefinedPersonalCategory(name: 'אוכל בחוץ', iconName: 'restaurant'),
    PredefinedPersonalCategory(name: 'בריאות', iconName: 'medical_services'),
    PredefinedPersonalCategory(name: 'תחבורה', iconName: 'directions_bus'),
    PredefinedPersonalCategory(name: 'רכב', iconName: 'build'),
    PredefinedPersonalCategory(name: 'קניות', iconName: 'checkroom'),
    PredefinedPersonalCategory(name: 'בילויים ופנאי', iconName: 'movie'),
    PredefinedPersonalCategory(name: 'חינוך', iconName: 'school'),
    PredefinedPersonalCategory(name: 'לימודים', iconName: 'menu_book'),
    PredefinedPersonalCategory(name: 'משפחה וילדים', iconName: 'child_care'),
    PredefinedPersonalCategory(name: 'בעלי חיים', iconName: 'pets'),
    PredefinedPersonalCategory(name: 'שופינג', iconName: 'checkroom'),
    PredefinedPersonalCategory(name: 'קניות לבית', iconName: 'home'),
    PredefinedPersonalCategory(name: 'בילויים', iconName: 'confirmation_number'),
    PredefinedPersonalCategory(name: 'תרבות', iconName: 'movie'),
    PredefinedPersonalCategory(name: 'נסיעות', iconName: 'flight'),
    PredefinedPersonalCategory(name: 'אירועים ומתנות', iconName: 'celebration'),
    PredefinedPersonalCategory(name: 'טיפוח אישי', iconName: 'spa'),
    PredefinedPersonalCategory(name: 'ציוד ושירותים', iconName: 'devices'),
    PredefinedPersonalCategory(name: 'תיקונים ותחזוקה', iconName: 'build'),
    PredefinedPersonalCategory(name: 'שירותים רפואיים', iconName: 'local_hospital'),
    PredefinedPersonalCategory(name: 'ספורט וכושר', iconName: 'fitness_center'),
    PredefinedPersonalCategory(name: 'עבודה וקריירה', iconName: 'work'),
    PredefinedPersonalCategory(name: 'הלוואות והחזרים', iconName: 'payments'),
    PredefinedPersonalCategory(name: 'עמלות וחיובים', iconName: 'attach_money'),
    PredefinedPersonalCategory(name: 'תקשורת ומנויים', iconName: 'wifi'),
    PredefinedPersonalCategory(name: 'פיננסים וביטוחים', iconName: 'account_balance'),
    PredefinedPersonalCategory(name: 'חיסכון', iconName: 'savings'),
    PredefinedPersonalCategory(name: 'אחר', iconName: 'misc'),
  ];
}

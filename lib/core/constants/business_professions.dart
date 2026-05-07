import 'package:flutter/material.dart';

class BusinessProfession {
  final String id;
  final String label;
  final IconData icon;

  const BusinessProfession({
    required this.id,
    required this.label,
    required this.icon,
  });
}

class BusinessProfessionCatalog {
  static const String defaultIconName = 'business';

  static const List<BusinessProfession> professions = [
    // Technology
    BusinessProfession(id: 'computer', label: 'מחשבים / IT', icon: Icons.computer),
    BusinessProfession(id: 'code', label: 'פיתוח תוכנה', icon: Icons.code),
    BusinessProfession(id: 'smartphone', label: 'מובייל', icon: Icons.smartphone),
    BusinessProfession(id: 'memory', label: 'חומרה', icon: Icons.memory),
    BusinessProfession(id: 'dns', label: 'תשתיות', icon: Icons.dns),
    BusinessProfession(id: 'cloud', label: 'ענן', icon: Icons.cloud),

    // Construction & engineering
    BusinessProfession(id: 'build', label: 'בנייה', icon: Icons.build),
    BusinessProfession(id: 'engineering', label: 'הנדסה', icon: Icons.engineering),
    BusinessProfession(id: 'straighten', label: 'מדידה', icon: Icons.straighten),
    BusinessProfession(id: 'architecture', label: 'אדריכלות', icon: Icons.architecture),
    BusinessProfession(id: 'construction', label: 'קבלנות', icon: Icons.construction),
    BusinessProfession(id: 'plumbing', label: 'אינסטלציה', icon: Icons.plumbing),

    // Culinary
    BusinessProfession(id: 'restaurant', label: 'שף / מסעדנות', icon: Icons.restaurant),
    BusinessProfession(id: 'lunch_dining', label: 'אוכל מהיר', icon: Icons.lunch_dining),
    BusinessProfession(id: 'bakery_dining', label: 'מאפייה', icon: Icons.bakery_dining),
    BusinessProfession(id: 'local_cafe', label: 'בית קפה', icon: Icons.local_cafe),
    BusinessProfession(id: 'emoji_food_beverage', label: 'מזון ומשקאות', icon: Icons.emoji_food_beverage),

    // Finance
    BusinessProfession(id: 'monetization_on', label: 'כספים', icon: Icons.monetization_on),
    BusinessProfession(id: 'calculate', label: 'הנהלת חשבונות', icon: Icons.calculate),
    BusinessProfession(id: 'trending_up', label: 'השקעות', icon: Icons.trending_up),
    BusinessProfession(id: 'account_balance', label: 'בנקאות', icon: Icons.account_balance),
    BusinessProfession(id: 'receipt_long', label: 'חשבוניות', icon: Icons.receipt_long),
    BusinessProfession(id: 'savings', label: 'חיסכון', icon: Icons.savings),

    // Services
    BusinessProfession(id: 'cleaning_services', label: 'ניקיון', icon: Icons.cleaning_services),
    BusinessProfession(id: 'handyman', label: 'תיקונים', icon: Icons.handyman),
    BusinessProfession(id: 'delivery_dining', label: 'שליחויות', icon: Icons.delivery_dining),
    BusinessProfession(id: 'local_shipping', label: 'הובלות', icon: Icons.local_shipping),
    BusinessProfession(id: 'home_repair_service', label: 'שירות בית', icon: Icons.home_repair_service),
    BusinessProfession(id: 'support_agent', label: 'שירות לקוחות', icon: Icons.support_agent),

    // Healthcare
    BusinessProfession(id: 'favorite', label: 'טיפול / בריאות', icon: Icons.favorite),
    BusinessProfession(id: 'medical_services', label: 'רפואה', icon: Icons.medical_services),
    BusinessProfession(id: 'psychology', label: 'פסיכולוגיה', icon: Icons.psychology),
    BusinessProfession(id: 'healing', label: 'רפואה משלימה', icon: Icons.healing),
    BusinessProfession(id: 'medication', label: 'תרופות', icon: Icons.medication),
    BusinessProfession(id: 'vaccines', label: 'מעבדה / חיסונים', icon: Icons.vaccines),

    // Marketing & sales
    BusinessProfession(id: 'campaign', label: 'שיווק', icon: Icons.campaign),
    BusinessProfession(id: 'store', label: 'מכירות', icon: Icons.store),
    BusinessProfession(id: 'percent', label: 'מבצעים', icon: Icons.percent),
    BusinessProfession(id: 'shopping_cart', label: 'איקומרס', icon: Icons.shopping_cart),
    BusinessProfession(id: 'point_of_sale', label: 'קופה / POS', icon: Icons.point_of_sale),
    BusinessProfession(id: 'groups', label: 'ניהול קהילה', icon: Icons.groups),

    // Art & design
    BusinessProfession(id: 'palette', label: 'עיצוב', icon: Icons.palette),
    BusinessProfession(id: 'photo_camera', label: 'צילום', icon: Icons.photo_camera),
    BusinessProfession(id: 'brush', label: 'אמנות', icon: Icons.brush),
    BusinessProfession(id: 'music_note', label: 'מוזיקה', icon: Icons.music_note),
    BusinessProfession(id: 'movie', label: 'וידאו', icon: Icons.movie),
    BusinessProfession(id: 'design_services', label: 'עיצוב גרפי', icon: Icons.design_services),

    // Other common sectors
    BusinessProfession(id: 'school', label: 'חינוך', icon: Icons.school),
    BusinessProfession(id: 'gavel', label: 'משפטים', icon: Icons.gavel),
    BusinessProfession(id: 'directions_car', label: 'תחבורה', icon: Icons.directions_car),
    BusinessProfession(id: 'pets', label: 'בעלי חיים', icon: Icons.pets),
    BusinessProfession(id: 'fitness_center', label: 'כושר', icon: Icons.fitness_center),
    BusinessProfession(id: 'business', label: 'עסק כללי', icon: Icons.business),
  ];

  static IconData iconFromName(String? iconName) {
    final key = (iconName == null || iconName.trim().isEmpty)
        ? defaultIconName
        : iconName.trim();
    final match = professions.where((p) => p.id == key).toList();
    if (match.isEmpty) return Icons.business;
    return match.first.icon;
  }
}

class Payment {
  final String id;
  final String? studentId;
  final double amount;
  final String currency;
  final String? method;
  final String receivedAt;
  final String? courseId;
  final String? note;
  final String? receiptUrl;

  const Payment({
    required this.id,
    required this.amount,
    this.studentId,
    this.currency = 'THB',
    this.method,
    required this.receivedAt,
    this.courseId,
    this.note,
    this.receiptUrl,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'] as String,
        studentId: json['student_id'] as String?,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'THB',
        method: json['method'] as String?,
        receivedAt: json['received_at'] as String? ?? '',
        courseId: json['course_id'] as String?,
        note: json['note'] as String?,
        receiptUrl: json['receipt_url'] as String?,
      );
}

class Expense {
  final String id;
  final String date;
  final String category;
  final double amount;
  final String? description;
  final String? method;
  final String? receiptUrl;

  const Expense({
    required this.id,
    required this.date,
    required this.category,
    required this.amount,
    this.description,
    this.method,
    this.receiptUrl,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        date: json['date'] as String? ?? '',
        category: json['category'] as String? ?? 'other',
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String?,
        method: json['method'] as String?,
        receiptUrl: json['receipt_url'] as String?,
      );
}

class MonthlySummary {
  final String id;
  final int month;
  final int year;
  final double income;
  final double expenses;
  final double profit;

  const MonthlySummary({
    required this.id,
    required this.month,
    required this.year,
    required this.income,
    required this.expenses,
    required this.profit,
  });

  factory MonthlySummary.fromJson(Map<String, dynamic> json) =>
      MonthlySummary(
        id: json['id'] as String,
        month: (json['month'] as num).toInt(),
        year: (json['year'] as num).toInt(),
        income: (json['income'] as num).toDouble(),
        expenses: (json['expenses'] as num).toDouble(),
        profit: (json['profit'] as num).toDouble(),
      );
}

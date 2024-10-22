class DateFormatter {
  static String format(DateTime date) {
    String formattedDate = '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    return formattedDate;
  }
}


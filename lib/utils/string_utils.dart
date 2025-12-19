String toTitleCase(String text) {
  if (text.isEmpty) return text;
  
  // Split by capital letters, but keep them
  final RegExp exp = RegExp(r'(?=[A-Z])');
  final List<String> parts = text.split(exp);
  
  // Clean up empty parts if any (e.g. if string starts with capital)
  final cleanedParts = parts.where((p) => p.isNotEmpty).toList();
  
  if (cleanedParts.isEmpty) return text;
  
  // Join with space
  return cleanedParts.join(' ');
}

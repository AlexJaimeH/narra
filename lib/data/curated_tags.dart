import 'package:flutter/material.dart';

String normalizeTagName(String value) {
  const diacriticReplacements = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'ã': 'a',
    'å': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };

  final normalized = value.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final codePoint in normalized.runes) {
    final char = String.fromCharCode(codePoint);
    buffer.write(diacriticReplacements[char] ?? char);
  }
  return buffer.toString();
}

class CuratedTagCategory {
  final String title;
  final String description;
  final IconData icon;

  const CuratedTagCategory({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class CuratedTagDefinition {
  final String name;
  final String category;
  final Color color;
  final String? emoji;

  const CuratedTagDefinition({
    required this.name,
    required this.category,
    required this.color,
    this.emoji,
  });
}

const List<CuratedTagCategory> curatedTagCategories = [
  CuratedTagCategory(
    title: 'Raíces y familia',
    description:
        'Recuerdos del hogar, figuras importantes y tradiciones que marcaron tu infancia.',
    icon: Icons.family_restroom,
  ),
  CuratedTagCategory(
    title: 'Amor y amistades',
    description:
        'Personas especiales, vínculos afectivos y momentos que hicieron latir tu corazón.',
    icon: Icons.favorite_outline,
  ),
  CuratedTagCategory(
    title: 'Escuela y formación',
    description:
        'Aulas, aprendizajes, maestros y descubrimientos que formaron tu manera de ver la vida.',
    icon: Icons.school,
  ),
  CuratedTagCategory(
    title: 'Trabajo y propósito',
    description:
        'Profesiones, vocaciones y proyectos que te dieron identidad y sentido.',
    icon: Icons.work_outline,
  ),
  CuratedTagCategory(
    title: 'Aventuras y viajes',
    description:
        'Travesías, cambios de ciudad y experiencias que te mostraron nuevos horizontes.',
    icon: Icons.flight_takeoff,
  ),
  CuratedTagCategory(
    title: 'Logros y celebraciones',
    description:
        'Metas alcanzadas, sorpresas y momentos brillantes para compartir con los tuyos.',
    icon: Icons.emoji_events_outlined,
  ),
  CuratedTagCategory(
    title: 'Desafíos y resiliencia',
    description:
        'Historias de fortaleza, aprendizajes difíciles y caminos de sanación.',
    icon: Icons.psychology_alt_outlined,
  ),
  CuratedTagCategory(
    title: 'Momentos cotidianos',
    description:
        'Pequeños detalles, pasatiempos y costumbres que hacen tu vida única.',
    icon: Icons.local_florist_outlined,
  ),
  CuratedTagCategory(
    title: 'Para todo lo demás',
    description:
        'Etiquetas versátiles para recuerdos únicos que quieres conservar.',
    icon: Icons.auto_awesome_outlined,
  ),
];

const List<CuratedTagDefinition> curatedTagDefinitions = [
  CuratedTagDefinition(
    name: 'Familia',
    category: 'Raíces y familia',
    color: Color(0xFFF97362),
    emoji: '🏡',
  ),
  CuratedTagDefinition(
    name: 'Infancia',
    category: 'Raíces y familia',
    color: Color(0xFFFABF58),
    emoji: '🧸',
  ),
  CuratedTagDefinition(
    name: 'Padres',
    category: 'Raíces y familia',
    color: Color(0xFFFF8A80),
    emoji: '❤️',
  ),
  CuratedTagDefinition(
    name: 'Hermanos',
    category: 'Raíces y familia',
    color: Color(0xFFFFAFCC),
    emoji: '🤗',
  ),
  CuratedTagDefinition(
    name: 'Tradiciones familiares',
    category: 'Raíces y familia',
    color: Color(0xFFFFD166),
    emoji: '🎎',
  ),
  CuratedTagDefinition(
    name: 'Hogar',
    category: 'Raíces y familia',
    color: Color(0xFFFFC4A8),
    emoji: '🏠',
  ),
  CuratedTagDefinition(
    name: 'Nacimiento',
    category: 'Raíces y familia',
    color: Color(0xFFFFE5A5),
    emoji: '👶',
  ),
  CuratedTagDefinition(
    name: 'Historia de amor',
    category: 'Amor y amistades',
    color: Color(0xFFFF8FA2),
    emoji: '💕',
  ),
  CuratedTagDefinition(
    name: 'Pareja',
    category: 'Amor y amistades',
    color: Color(0xFFFB6F92),
    emoji: '💑',
  ),
  CuratedTagDefinition(
    name: 'Matrimonio',
    category: 'Amor y amistades',
    color: Color(0xFFFFC6A5),
    emoji: '💍',
  ),
  CuratedTagDefinition(
    name: 'Hijos',
    category: 'Amor y amistades',
    color: Color(0xFFFFB347),
    emoji: '👶',
  ),
  CuratedTagDefinition(
    name: 'Nietos',
    category: 'Amor y amistades',
    color: Color(0xFFFFD6BA),
    emoji: '👵',
  ),
  CuratedTagDefinition(
    name: 'Amistad',
    category: 'Amor y amistades',
    color: Color(0xFF74C69D),
    emoji: '🤝',
  ),
  CuratedTagDefinition(
    name: 'Escuela',
    category: 'Escuela y formación',
    color: Color(0xFF4BA3C3),
    emoji: '🏫',
  ),
  CuratedTagDefinition(
    name: 'Universidad',
    category: 'Escuela y formación',
    color: Color(0xFF6C63FF),
    emoji: '🎓',
  ),
  CuratedTagDefinition(
    name: 'Mentores',
    category: 'Escuela y formación',
    color: Color(0xFF89A1EF),
    emoji: '🧑‍🏫',
  ),
  CuratedTagDefinition(
    name: 'Primer día de clases',
    category: 'Escuela y formación',
    color: Color(0xFF80C7FF),
    emoji: '📚',
  ),
  CuratedTagDefinition(
    name: 'Graduación',
    category: 'Escuela y formación',
    color: Color(0xFF9381FF),
    emoji: '🎉',
  ),
  CuratedTagDefinition(
    name: 'Actividades escolares',
    category: 'Escuela y formación',
    color: Color(0xFF59C3C3),
    emoji: '🎨',
  ),
  CuratedTagDefinition(
    name: 'Primer trabajo',
    category: 'Trabajo y propósito',
    color: Color(0xFF0077B6),
    emoji: '💼',
  ),
  CuratedTagDefinition(
    name: 'Carrera profesional',
    category: 'Trabajo y propósito',
    color: Color(0xFF00B4D8),
    emoji: '📈',
  ),
  CuratedTagDefinition(
    name: 'Emprendimiento',
    category: 'Trabajo y propósito',
    color: Color(0xFF48CAE4),
    emoji: '🚀',
  ),
  CuratedTagDefinition(
    name: 'Mentoría laboral',
    category: 'Trabajo y propósito',
    color: Color(0xFF8ECAE6),
    emoji: '🧭',
  ),
  CuratedTagDefinition(
    name: 'Jubilación',
    category: 'Trabajo y propósito',
    color: Color(0xFF90E0EF),
    emoji: '⛱️',
  ),
  CuratedTagDefinition(
    name: 'Servicio comunitario',
    category: 'Trabajo y propósito',
    color: Color(0xFF6BCB77),
    emoji: '🤲',
  ),
  CuratedTagDefinition(
    name: 'Viajes',
    category: 'Aventuras y viajes',
    color: Color(0xFF00A6FB),
    emoji: '✈️',
  ),
  CuratedTagDefinition(
    name: 'Mudanzas',
    category: 'Aventuras y viajes',
    color: Color(0xFF72EFDD),
    emoji: '🚚',
  ),
  CuratedTagDefinition(
    name: 'Naturaleza',
    category: 'Aventuras y viajes',
    color: Color(0xFF2BB673),
    emoji: '🌿',
  ),
  CuratedTagDefinition(
    name: 'Cultura',
    category: 'Aventuras y viajes',
    color: Color(0xFFFFC857),
    emoji: '🎭',
  ),
  CuratedTagDefinition(
    name: 'Descubrimientos',
    category: 'Aventuras y viajes',
    color: Color(0xFF4D96FF),
    emoji: '🧭',
  ),
  CuratedTagDefinition(
    name: 'Aventura en carretera',
    category: 'Aventuras y viajes',
    color: Color(0xFF5E60CE),
    emoji: '🛣️',
  ),
  CuratedTagDefinition(
    name: 'Logros',
    category: 'Logros y celebraciones',
    color: Color(0xFFFFB703),
    emoji: '🏆',
  ),
  CuratedTagDefinition(
    name: 'Sueños cumplidos',
    category: 'Logros y celebraciones',
    color: Color(0xFFFF9E00),
    emoji: '🌟',
  ),
  CuratedTagDefinition(
    name: 'Celebraciones familiares',
    category: 'Logros y celebraciones',
    color: Color(0xFFFFD670),
    emoji: '🎊',
  ),
  CuratedTagDefinition(
    name: 'Reconocimientos',
    category: 'Logros y celebraciones',
    color: Color(0xFFFFC8DD),
    emoji: '🥇',
  ),
  CuratedTagDefinition(
    name: 'Momentos de orgullo',
    category: 'Logros y celebraciones',
    color: Color(0xFFFF8FAB),
    emoji: '🙌',
  ),
  CuratedTagDefinition(
    name: 'Cumpleaños memorables',
    category: 'Logros y celebraciones',
    color: Color(0xFFFFC4D6),
    emoji: '🎂',
  ),
  CuratedTagDefinition(
    name: 'Enfermedad',
    category: 'Desafíos y resiliencia',
    color: Color(0xFF9D4EDD),
    emoji: '💜',
  ),
  CuratedTagDefinition(
    name: 'Recuperación',
    category: 'Desafíos y resiliencia',
    color: Color(0xFFB15EFF),
    emoji: '🦋',
  ),
  CuratedTagDefinition(
    name: 'Momentos difíciles',
    category: 'Desafíos y resiliencia',
    color: Color(0xFF845EC2),
    emoji: '⛈️',
  ),
  CuratedTagDefinition(
    name: 'Pérdidas',
    category: 'Desafíos y resiliencia',
    color: Color(0xFF6D597A),
    emoji: '🕯️',
  ),
  CuratedTagDefinition(
    name: 'Fe y esperanza',
    category: 'Desafíos y resiliencia',
    color: Color(0xFF80CED7),
    emoji: '🕊️',
  ),
  CuratedTagDefinition(
    name: 'Lecciones de vida',
    category: 'Desafíos y resiliencia',
    color: Color(0xFF577590),
    emoji: '📖',
  ),
  CuratedTagDefinition(
    name: 'Hobbies',
    category: 'Momentos cotidianos',
    color: Color(0xFF06D6A0),
    emoji: '🎨',
  ),
  CuratedTagDefinition(
    name: 'Mascotas',
    category: 'Momentos cotidianos',
    color: Color(0xFFFFA69E),
    emoji: '🐾',
  ),
  CuratedTagDefinition(
    name: 'Recetas favoritas',
    category: 'Momentos cotidianos',
    color: Color(0xFFFFC15E),
    emoji: '🍲',
  ),
  CuratedTagDefinition(
    name: 'Música',
    category: 'Momentos cotidianos',
    color: Color(0xFF118AB2),
    emoji: '🎶',
  ),
  CuratedTagDefinition(
    name: 'Tecnología',
    category: 'Momentos cotidianos',
    color: Color(0xFF73B0FF),
    emoji: '💡',
  ),
  CuratedTagDefinition(
    name: 'Conversaciones especiales',
    category: 'Momentos cotidianos',
    color: Color(0xFF9EADC8),
    emoji: '🗣️',
  ),
  CuratedTagDefinition(
    name: 'Otros momentos',
    category: 'Para todo lo demás',
    color: Color(0xFFB0BEC5),
    emoji: '✨',
  ),
  CuratedTagDefinition(
    name: 'Recuerdos únicos',
    category: 'Para todo lo demás',
    color: Color(0xFFCDB4DB),
    emoji: '🌀',
  ),
  CuratedTagDefinition(
    name: 'Sin categoría',
    category: 'Para todo lo demás',
    color: Color(0xFFE2E2E2),
    emoji: '📁',
  ),
];

const List<String> forbiddenSuggestedTagNames = [
  'Hogar',
  'Primer día de clases',
  'Actividades escolares',
  'Mentoría laboral',
  'Servicio comunitario',
  'Naturaleza',
  'Cultura',
  'Descubrimientos',
  'Aventura en carretera',
  'Recuperación',
  'Fe y esperanza',
  'Recetas favoritas',
  'Música',
  'Tecnología',
  'Conversaciones especiales',
  'Otros momentos',
  'Recuerdos únicos',
  'Sin categoría',
];

final Set<String> normalizedForbiddenSuggestedTagNames =
    forbiddenSuggestedTagNames.map(normalizeTagName).toSet();

final List<String> curatedTagNames =
    curatedTagDefinitions.map((tag) => tag.name).toList(growable: false);

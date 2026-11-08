/// Fechas de cuidado como días de calendario, sin horas. Sumar días con
/// `Duration` falla al cruzar el cambio de horario (un día puede durar 23 o
/// 25 horas): por eso se suman componentes de fecha.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// [d] más [n] días de calendario, a medianoche.
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Días de calendario entre dos fechas (negativo si [to] es anterior).
int daysBetween(DateTime from, DateTime to) => DateTime.utc(to.year, to.month, to.day)
    .difference(DateTime.utc(from.year, from.month, from.day))
    .inDays;

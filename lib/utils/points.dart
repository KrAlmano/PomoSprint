/// Pomodoro seans süresine göre kazanılan puanı hesaplar.
/// 25 dk -> 20 puan, 50 dk -> 40 puan (25 dk başına 20 puan).
int pointsForMinutes(int minutes) {
  return ((minutes / 25).round()) * 20;
}

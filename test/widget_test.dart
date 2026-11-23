import 'package:flutter_test/flutter_test.dart';
import 'package:little_game_maker/game_models.dart';

void main() {
  test('project factory creates a playable maze template', () {
    final project = GameProject.create(GameType.maze, 'آزمایش');
    expect(project.cells.length, 121);
    expect(project.cells.indexOf(5), 12);
    expect(project.cells.indexOf(4), 108);
  });
}

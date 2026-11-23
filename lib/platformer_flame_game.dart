import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import 'game_audio.dart';
import 'game_models.dart';

const double _cellSize = 2.2;

/// A real-time platform game powered by Flame's game loop and Forge2D bodies.
class PlatformerPhysicsGame extends Forge2DGame<Forge2DWorld> {
  PlatformerPhysicsGame({
    required this.project,
    this.onScore,
    this.onLives,
    this.onFinished,
  }) : super(gravity: Vector2(0, 30));

  final GameProject project;
  final ValueChanged<int>? onScore;
  final ValueChanged<int>? onLives;
  final ValueChanged<bool>? onFinished;

  late PlatformerPlayer player;
  final List<Rect> _solidBounds = [];
  final List<_Pickup> _coins = [];
  final List<_Pickup> _enemies = [];
  int score = 0;
  int lives = 3;
  int _direction = 0;
  int _airJumps = 0;
  double _coyoteTimer = 0;
  double _jumpBufferTimer = 0;
  double _invulnerable = 0;
  double _enemyClock = 0;
  bool _finished = false;
  bool _pausedByUser = false;
  bool _playerCreated = false;

  double get _worldWidth => project.columns * _cellSize;
  double get _worldHeight => project.rows * _cellSize;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.zoom = 2.6;

    final startIndex = project.cells.indexOf(5);
    final startColumn = startIndex < 0 ? 0 : startIndex % project.columns;
    final startRow = startIndex < 0 ? project.rows - 2 : startIndex ~/ project.columns;
    final start = Vector2(
      (startColumn + .5) * _cellSize,
      (startRow + .42) * _cellSize,
    );

    // Load the premium animation pack once per level. Each sheet is authored
    // as evenly-sized frames so Flame can animate it without runtime slicing.
    final heroImage = await images.load('fox_hero_animations.png');
    final legacyHeroImage = await images.load('fox_animations.png');
    final slimeImage = await images.load('forest_slime_animations.png');
    final coinImage = await images.load('sun_coin_animations.png');
    final premiumHeroSheet = SpriteSheet(image: heroImage, srcSize: Vector2(362, 362));
    final legacyHeroSheet = SpriteSheet(image: legacyHeroImage, srcSize: Vector2(64, 64));
    final slimeSheet = SpriteSheet(image: slimeImage, srcSize: Vector2(256, 256));
    final coinSheet = SpriteSheet(image: coinImage, srcSize: Vector2(256, 256));
    final slimeAnimation = slimeSheet.createAnimation(row: 0, stepTime: .14, to: 4);
    final coinAnimation = coinSheet.createAnimation(row: 0, stepTime: .12, to: 4);

    // A hand-painted world-space backdrop gives the camera a real illustrated
    // environment instead of a flat color. It is the first world component so
    // all platforms, collectibles and characters are drawn above it.
    world.add(_AdventureBackdrop(
      Vector2(_worldWidth, _worldHeight),
      theme: project.background,
    ));
    world.add(_AmbientSparkles(Vector2(_worldWidth, _worldHeight)));

    // The level is built from static Forge2D bodies. The visual components are
    // separate so the physics shapes stay simple and inexpensive.
    for (var row = 0; row < project.rows; row++) {
      for (var col = 0; col < project.columns; col++) {
        final value = project.cells[row * project.columns + col];
        final center = Vector2((col + .5) * _cellSize, (row + .82) * _cellSize);
        if (value == 1) {
          final size = Vector2(_cellSize, .48);
          _solidBounds.add(Rect.fromCenter(
            center: Offset(center.x, center.y),
            width: size.x,
            height: size.y,
          ));
          world.add(_PlatformBody(center, size));
        } else if (value == 2) {
          final pickup = _Pickup(center, enemy: false, animation: coinAnimation); 
          _coins.add(pickup);
          add(pickup);
        } else if (value == 3) {
          final enemy = _Pickup(center, enemy: true, animation: slimeAnimation);
          _enemies.add(enemy);
          add(enemy);
        } else if (value == 4) {
          add(_GoalVisual(center));
        }
      }
    }

    // A continuous floor and invisible side walls keep the player in the level.
    final floorY = _worldHeight - .18;
    final floorCenter = Vector2(_worldWidth / 2, floorY);
    final floorSize = Vector2(_worldWidth + 2, .55);
    _solidBounds.add(Rect.fromCenter(
      center: Offset(floorCenter.x, floorCenter.y),
      width: floorSize.x,
      height: floorSize.y,
    ));
    world.add(_PlatformBody(floorCenter, floorSize));
    world.add(_PlatformBody(Vector2(-.4, _worldHeight / 2), Vector2(.8, _worldHeight * 2)));
    world.add(_PlatformBody(Vector2(_worldWidth + .4, _worldHeight / 2), Vector2(.8, _worldHeight * 2)));

    final characterIndex = project.character.clamp(0, characterOptions.length - 1).toInt();
    final usePremiumFox = characterIndex == 4;
    final heroSheet = usePremiumFox ? premiumHeroSheet : legacyHeroSheet;
    final characterRow = usePremiumFox ? 0 : characterIndex * 3;
    final idleAnimation = heroSheet.createAnimation(row: characterRow, stepTime: .24, to: 4);
    final runAnimation = heroSheet.createAnimation(row: characterRow + 1, stepTime: .105, to: 4);
    final jumpAnimation = heroSheet.createAnimation(row: characterRow + 2, stepTime: .16, to: 4);
    player = PlatformerPlayer(start, idleAnimation, runAnimation, jumpAnimation);
    _playerCreated = true;
    world.add(player);

    camera.viewfinder.position = start;
  }

  void setDirection(int direction) => _direction = direction.clamp(-1, 1).toInt();

  void jump() {
    if (_finished || _pausedByUser || !_playerCreated || !player.isLoaded) return;
    // A short input buffer makes touch controls forgiving on mobile devices.
    _jumpBufferTimer = .16;
  }

  void setPaused(bool value) {
    _pausedByUser = value;
    if (value) {
      pauseEngine();
      _direction = 0;
    } else {
      resumeEngine();
    }
  }

  bool _isGrounded() {
    final bodyPosition = player.body.position;
    final foot = bodyPosition.y + .52;
    for (final platform in _solidBounds) {
      if ((foot - platform.top).abs() < .24 &&
          bodyPosition.x >= platform.left - .32 &&
          bodyPosition.x <= platform.right + .32 &&
          player.body.linearVelocity.y >= -.25) {
        return true;
      }
    }
    return false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished || _pausedByUser || !_playerCreated || !player.isLoaded) return;

    final step = dt.clamp(0.0, 1 / 30).toDouble();
    final velocity = player.body.linearVelocity;
    final grounded = _isGrounded();
    if (grounded) {
      _airJumps = 0;
      _coyoteTimer = .12;
    } else {
      _coyoteTimer = math.max(0.0, _coyoteTimer - step);
    }
    _jumpBufferTimer = math.max(0.0, _jumpBufferTimer - step);
    if (_jumpBufferTimer > 0) {
      if (grounded || _coyoteTimer > 0) {
        _airJumps = 1;
        player.body.linearVelocity = Vector2(velocity.x, -13.2);
        _jumpBufferTimer = 0;
        _coyoteTimer = 0;
        if (project.soundEnabled) GameAudio.instance.effect(frequency: 610, durationMs: 75);
      } else if (_airJumps < 2) {
        _airJumps = 2;
        player.body.linearVelocity = Vector2(velocity.x, -11.4);
        _jumpBufferTimer = 0;
        if (project.soundEnabled) GameAudio.instance.effect(frequency: 760, durationMs: 65);
      }
    }
    final targetSpeed = _direction * 7.4;
    final acceleration = grounded ? 34.0 : 17.0;
    final horizontalDelta = (targetSpeed - velocity.x).clamp(-acceleration * step, acceleration * step).toDouble();
    player.body.linearVelocity = Vector2(velocity.x + horizontalDelta, player.body.linearVelocity.y);
    if (velocity.y.abs() > 1.1) {
      player.setMotion('jump');
    } else if (_direction != 0) {
      player.setMotion('run');
    } else {
      player.setMotion('idle');
    }
    player.setFacingLeft(_direction < 0);

    _invulnerable = math.max(0.0, _invulnerable - dt);
    _enemyClock += dt;
    for (var i = 0; i < _enemies.length; i++) {
      final enemy = _enemies[i];
      enemy.position.x += math.sin(_enemyClock * 1.8 + i) * dt * .55;
    }

    // Keep the camera centered on the player without changing the physics world.
    final desiredCamera = Vector2(
      player.body.position.x,
      _worldHeight / 2,
    );
    final cameraBlend = 1 - math.exp(-5.5 * step);
    final currentCamera = camera.viewfinder.position;
    camera.viewfinder.position = Vector2(
      currentCamera.x + (desiredCamera.x - currentCamera.x) * cameraBlend,
      currentCamera.y + (desiredCamera.y - currentCamera.y) * cameraBlend,
    );

    for (final coin in List<_Pickup>.from(_coins)) {
      if ((coin.position - player.body.position).length < .95) {
        _coins.remove(coin);
        coin.removeFromParent();
        score += 10;
        onScore?.call(score);
        if (project.soundEnabled) GameAudio.instance.collect();
      }
    }

    if (_invulnerable <= 0) {
      for (final enemy in _enemies) {
        if ((enemy.position - player.body.position).length < .95) {
          _takeHit();
          break;
        }
      }
    }

    final goal = project.cells.indexOf(4);
    if (goal >= 0) {
      final goalPosition = Vector2(
        ((goal % project.columns) + .5) * _cellSize,
        ((goal ~/ project.columns) + .82) * _cellSize,
      );
      if ((goalPosition - player.body.position).length < 1.15) {
        _finish(true);
      }
    } else if (player.body.position.x > _worldWidth - .8) {
      _finish(true);
    }

    if (player.body.position.y > _worldHeight + 3) _takeHit();
  }

  void _takeHit() {
    if (_invulnerable > 0 || _finished) return;
    lives--;
    onLives?.call(lives);
    _invulnerable = 1.25;
    if (project.soundEnabled) GameAudio.instance.bump();
    if (lives <= 0) {
      _finish(false);
      return;
    }
    final startIndex = project.cells.indexOf(5);
    final col = startIndex < 0 ? 0 : startIndex % project.columns;
    final row = startIndex < 0 ? project.rows - 2 : startIndex ~/ project.columns;
    player.body.setTransform(
      Vector2((col + .5) * _cellSize, (row + .42) * _cellSize),
      Rot.identity(),
    );
    player.body.linearVelocity = Vector2.zero();
    _airJumps = 0;
    _coyoteTimer = 0;
    _jumpBufferTimer = 0;
  }

  void _finish(bool success) {
    if (_finished) return;
    _finished = true;
    _direction = 0;
    pauseEngine();
    if (project.soundEnabled) {
      if (success) {
        GameAudio.instance.success();
      } else {
        GameAudio.instance.bump();
      }
    }
    onFinished?.call(success);
  }
}

class _AdventureBackdrop extends PositionComponent {
  _AdventureBackdrop(Vector2 worldSize, {required this.theme})
      : super(position: Vector2.zero(), size: worldSize, priority: -1000);

  final int theme;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final palettes = <List<Color>>[
      [const Color(0xFF78C9F4), const Color(0xFFD9F4C3)],
      [const Color(0xFF48BDEB), const Color(0xFFFFE4A2)],
      [const Color(0xFF18275E), const Color(0xFF7457A8)],
      [const Color(0xFFFFAFCB), const Color(0xFFFFE6B2)],
    ];
    final palette = palettes[theme.clamp(0, palettes.length - 1).toInt()];
    canvas.drawRect(rect, Paint()..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: palette,
    ).createShader(rect));

    final night = theme == 2;
    final sunCenter = Offset(size.x * .78, size.y * .19);
    canvas.drawCircle(sunCenter, 1.12, Paint()..color = night
        ? const Color(0xFFFFE9B4).withOpacity(.16)
        : const Color(0xFFFFF1A8).withOpacity(.28));
    canvas.drawCircle(sunCenter, .72, Paint()..color = night
        ? const Color(0xFFFFE9B4)
        : const Color(0xFFFFF4C5));

    final cloudPaint = Paint()..color = Colors.white.withOpacity(night ? .2 : .64);
    for (var i = 0; i < 5; i++) {
      final x = (i * 5.7 + 1.3) % (size.x + 3) - 1.5;
      final y = 1.2 + (i % 3) * 1.1;
      canvas.drawOval(Rect.fromLTWH(x, y, 1.8, .48), cloudPaint);
      canvas.drawCircle(Offset(x + .48, y - .12), .34, cloudPaint);
      canvas.drawCircle(Offset(x + 1.03, y - .2), .43, cloudPaint);
      canvas.drawCircle(Offset(x + 1.43, y - .04), .29, cloudPaint);
    }

    Path hill(double base, double amplitude, double phase) {
      final path = Path()..moveTo(0, size.y);
      for (var x = 0.0; x <= size.x + .5; x += .5) {
        final y = base + math.sin(x * .34 + phase) * amplitude
            + math.sin(x * .13 + phase * 1.7) * amplitude * .55;
        path.lineTo(x, y);
      }
      return path..lineTo(size.x, size.y)..close();
    }

    canvas.drawPath(hill(size.y * .64, 1.05, .4), Paint()..color = night
        ? const Color(0xFF394B87)
        : const Color(0xFF82C98A));
    canvas.drawPath(hill(size.y * .72, 1.25, 2.2), Paint()..color = night
        ? const Color(0xFF293B72)
        : const Color(0xFF4FAE72));
    canvas.drawPath(hill(size.y * .82, .62, 1.1), Paint()..color = night
        ? const Color(0xFF1D315F)
        : const Color(0xFF318A58));

    // Repeated oversized storybook trees establish scale and depth.
    for (var i = 0; i < size.x ~/ 3 + 2; i++) {
      final x = i * 3.15 + .7;
      final base = size.y * .84 + (i.isEven ? .25 : -.1);
      final trunk = Paint()..color = night
          ? const Color(0xFF263B58)
          : const Color(0xFF80513D);
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, base - .72), width: .34, height: 1.75),
        const Radius.circular(.16),
      ), trunk);
      final leaves = Paint()..color = night
          ? const Color(0xFF315B76)
          : (i.isEven ? const Color(0xFF277D55) : const Color(0xFF3D9B60));
      canvas.drawCircle(Offset(x, base - 1.75), .92, leaves);
      canvas.drawCircle(Offset(x - .52, base - 1.42), .62, leaves);
      canvas.drawCircle(Offset(x + .54, base - 1.38), .66, leaves);
      canvas.drawCircle(Offset(x - .18, base - 2.08), .18,
          Paint()..color = Colors.white.withOpacity(.16));
    }

    // Distant storybook castle: intentionally low contrast so gameplay stays
    // readable while the world gains a recognizable landmark and depth.
    final castleX = size.x * .56;
    final castleY = size.y * .56;
    final stone = Paint()..color = night ? const Color(0xFF53618F) : const Color(0xFFD6C5A6);
    final shade = Paint()..color = night ? const Color(0xFF394A79) : const Color(0xFFAA987D);
    canvas.drawRect(Rect.fromLTWH(castleX - .9, castleY - 1.65, 1.8, 1.75), stone);
    canvas.drawRect(Rect.fromLTWH(castleX - 1.35, castleY - 2.15, .58, 2.25), shade);
    canvas.drawRect(Rect.fromLTWH(castleX + .77, castleY - 2.15, .58, 2.25), shade);
    Path towerRoof(double x) => Path()
      ..moveTo(x - .38, castleY - 2.1)
      ..lineTo(x, castleY - 2.85)
      ..lineTo(x + .38, castleY - 2.1)
      ..close();
    final roofPaint = Paint()..color = night ? const Color(0xFF8B79B8) : const Color(0xFFCA6D69);
    canvas.drawPath(towerRoof(castleX - 1.06), roofPaint);
    canvas.drawPath(towerRoof(castleX + 1.06), roofPaint);
    canvas.drawRect(Rect.fromLTWH(castleX - .18, castleY - .72, .36, .82),
        Paint()..color = night ? const Color(0xFF25365F) : const Color(0xFF805B48));
    for (final dx in [-.65, .65]) {
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(castleX + dx - .11, castleY - 1.35, .22, .35),
        const Radius.circular(.11)), Paint()..color = night ? const Color(0xFFFFE7A4) : const Color(0xFF8CC9E7));
    }

    // Floating grass islands and waterfalls reinforce the whimsical platformer
    // silhouette without affecting collision geometry.
    for (var i = 0; i < 3; i++) {
      final x = size.x * (.16 + i * .34);
      final y = size.y * (.47 + (i.isEven ? .06 : -.03));
      final island = Path()
        ..moveTo(x - .9, y)
        ..quadraticBezierTo(x, y - .38, x + .9, y)
        ..lineTo(x + .58, y + .72)
        ..lineTo(x - .52, y + .72)
        ..close();
      canvas.drawPath(island, Paint()..color = night ? const Color(0xFF334D6C) : const Color(0xFF986044));
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(x - .92, y - .12, 1.84, .25), const Radius.circular(.12)),
        Paint()..color = night ? const Color(0xFF4D8A70) : const Color(0xFF68B95A));
      canvas.drawRect(Rect.fromLTWH(x - .22, y + .12, .10, .45),
          Paint()..color = const Color(0x6688DDF5));
      canvas.drawRect(Rect.fromLTWH(x + .20, y + .12, .08, .32),
          Paint()..color = const Color(0x6688DDF5));
    }
  }
}

class _AmbientSparkles extends PositionComponent {
  _AmbientSparkles(Vector2 worldSize)
      : super(position: Vector2.zero(), size: worldSize, priority: -900);

  double _clock = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _clock += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    for (var i = 0; i < 22; i++) {
      final x = (i * 2.73 + math.sin(_clock * .22 + i) * .22) % size.x;
      final y = (i * 1.91 + math.sin(_clock * .7 + i * 1.7) * .24) % (size.y * .72);
      final pulse = .035 + (math.sin(_clock * 2.4 + i) + 1) * .018;
      final alpha = (90 + (math.sin(_clock * 1.8 + i * 2) + 1) * 70).round().clamp(0, 255).toInt();
      final paint = Paint()..color = const Color(0xFFFFF4B0).withAlpha(alpha);
      canvas.drawCircle(Offset(x, y), pulse, paint);
      if (i % 4 == 0) {
        canvas.drawLine(Offset(x - pulse * 2.2, y), Offset(x + pulse * 2.2, y), paint..strokeWidth = .018);
        canvas.drawLine(Offset(x, y - pulse * 2.2), Offset(x, y + pulse * 2.2), paint);
      }
    }
  }
}

class _PlatformBody extends BodyComponent<PlatformerPhysicsGame> {
  _PlatformBody(Vector2 center, Vector2 size)
      : _size = size,
        super(
          bodyDef: BodyDef(position: center, type: BodyType.static),
          shapeSpecs: [
            ShapeSpec(
              Polygon.box(size.x / 2, size.y / 2, radius: .08),
              ShapeDef(material: SurfaceMaterial(friction: .88)),
            ),
          ],
          renderBody: false,
        );

  final Vector2 _size;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: _size.x,
      height: _size.y,
    );
    // Layered, rounded earth with a bright grass cap and small hand-painted
    // details. The physics body remains a simple box for stable collisions.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.shift(const Offset(0, .055)), const Radius.circular(.15)),
      Paint()..color = const Color(0xFF68442F),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(.13)),
      Paint()..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB77A49), Color(0xFF865334), Color(0xFF70452F)],
      ).createShader(rect),
    );
    final grass = RRect.fromRectAndRadius(
      Rect.fromLTWH(rect.left - .015, rect.top - .045, rect.width + .03, .22),
      const Radius.circular(.11),
    );
    canvas.drawRRect(grass, Paint()..color = const Color(0xFF3D9C4D));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left, rect.top - .045, rect.width, .115),
        const Radius.circular(.09),
      ),
      Paint()..color = const Color(0xFF8BE36E),
    );
    final detail = Paint()..strokeCap = StrokeCap.round..strokeWidth = .035;
    for (var i = 0; i < 5; i++) {
      final x = rect.left + .18 + i * (rect.width - .36) / 4;
      detail.color = i.isEven ? const Color(0xFFB5F17B) : const Color(0xFF4CBA59);
      canvas.drawLine(Offset(x, rect.top - .025), Offset(x + .035, rect.top - .12), detail);
    }
    final pebble = Paint()..color = const Color(0xFFCB9568);
    canvas.drawCircle(Offset(rect.left + .28, rect.top + .27), .045, pebble);
    canvas.drawCircle(Offset(rect.right - .34, rect.top + .32), .035, pebble);
  }
}

class PlatformerPlayer extends BodyComponent<PlatformerPhysicsGame> {
  PlatformerPlayer(
    Vector2 position,
    SpriteAnimation idleAnimation,
    SpriteAnimation runAnimation,
    SpriteAnimation jumpAnimation,
  )   : _idleAnimation = idleAnimation,
        _runAnimation = runAnimation,
        _jumpAnimation = jumpAnimation,
        super(
          bodyDef: BodyDef(
            type: BodyType.dynamic,
            position: position,
            fixedRotation: true,
            linearDamping: .4,
            isBullet: true,
          ),
          shapeSpecs: [
            ShapeSpec(
              Polygon.box(.38, .48, radius: .16),
              ShapeDef(material: SurfaceMaterial(friction: .25, restitution: 0)),
            ),
          ],
          renderBody: false,
        );

  final SpriteAnimation _idleAnimation;
  final SpriteAnimation _runAnimation;
  final SpriteAnimation _jumpAnimation;
  late SpriteAnimationComponent _sprite;
  String _motion = 'idle';

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _sprite = SpriteAnimationComponent(
      animation: _idleAnimation,
      size: Vector2(1.35, 1.45),
      anchor: Anchor.center,
      position: Vector2(0, -.08),
    );
    add(_sprite);
  }

  void setMotion(String motion) {
    if (!isLoaded || motion == _motion) return;
    _motion = motion;
    _sprite.animation = switch (motion) {
      'run' => _runAnimation,
      'jump' => _jumpAnimation,
      _ => _idleAnimation,
    };
  }

  void setFacingLeft(bool value) {
    if (!isLoaded) return;
    final scale = _sprite.scale;
    _sprite.scale = Vector2(value ? -scale.x.abs() : scale.x.abs(), scale.y);
  }
}

class _Pickup extends SpriteAnimationComponent {
  _Pickup(Vector2 point, {required this.enemy, required SpriteAnimation animation})
      : super(
          animation: animation,
          position: point,
          size: Vector2.all(enemy ? .94 : .78),
          anchor: Anchor.center,
        );

  final bool enemy;
  double _phase = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _phase += dt * (enemy ? 2.8 : 4.2);
    if (!enemy) {
      angle = math.sin(_phase) * .12;
      scale = Vector2.all(1 + math.sin(_phase * 1.6) * .035);
    } else {
      angle = math.sin(_phase * .7) * .045;
      scale = Vector2(1 + math.sin(_phase * 1.8) * .025,
          1 - math.sin(_phase * 1.8) * .025);
    }
  }
}

class _GoalVisual extends PositionComponent {
  _GoalVisual(Vector2 point)
      : super(position: point, size: Vector2(1.3, 1.5), anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final pole = Paint()..color = const Color(0xFF7856A8)..strokeWidth = .09;
    canvas.drawLine(const Offset(-.38, .58), const Offset(-.38, -.62), pole);
    final flag = Path()
      ..moveTo(-.34, -.6)
      ..lineTo(.48, -.36)
      ..lineTo(-.34, -.08)
      ..close();
    canvas.drawPath(flag, Paint()..color = const Color(0xFFFFD34E));
    canvas.drawCircle(const Offset(-.38, -.65), .11, Paint()..color = const Color(0xFF8D72C8));
  }
}

class PlatformerGameScreen extends StatefulWidget {
  const PlatformerGameScreen({super.key, required this.project});
  final GameProject project;

  @override
  State<PlatformerGameScreen> createState() => _PlatformerGameScreenState();
}

class _PlatformerGameScreenState extends State<PlatformerGameScreen> {
  late GameProject project;
  late PlatformerPhysicsGame game;
  int score = 0;
  int lives = 3;
  bool paused = false;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    project = widget.project.copy();
    _createGame();
    GameAudio.instance.configure(sound: project.soundEnabled, music: project.musicEnabled);
  }

  void _createGame() {
    game = PlatformerPhysicsGame(
      project: project,
      onScore: (value) { if (mounted) setState(() => score = value); },
      onLives: (value) { if (mounted) setState(() => lives = value); },
      onFinished: _showResult,
    );
  }

  void _showResult(bool success) {
    if (!mounted || _dialogOpen) return;
    _dialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final nextAvailable = success && project.activeLevel < project.levels.length - 1;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(success ? 'آفرین، قهرمان! 🏆' : 'دوباره تلاش کن! 💪'),
          content: Text(success
              ? 'به پایان مرحله رسیدی. امتیاز تو: $score'
              : 'جان‌ها تمام شد. این بار می‌توانی بهتر عمل کنی.'),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(dialogContext); Navigator.pop(context); },
              child: const Text('بازگشت'),
            ),
            if (nextAvailable)
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  setState(() {
                    project.setActiveLevel(project.activeLevel + 1);
                    score = 0; lives = 3; paused = false; _dialogOpen = false;
                    _createGame();
                  });
                },
                child: const Text('مرحله بعدی'),
              ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                setState(() { score = 0; lives = 3; paused = false; _dialogOpen = false; _createGame(); });
              },
              child: const Text('شروع دوباره'),
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    game.setDirection(0);
    game.pauseEngine();
    GameAudio.instance.configure(sound: project.soundEnabled, music: false);
    super.dispose();
  }

  Widget _directionButton(IconData icon, int direction) => Listener(
        onPointerDown: (_) => game.setDirection(direction),
        onPointerUp: (_) => game.setDirection(0),
        onPointerCancel: (_) => game.setDirection(0),
        child: SizedBox(
          width: 76,
          height: 58,
          child: FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6E56B4), padding: EdgeInsets.zero, elevation: 5, shadowColor: const Color(0x556E56B4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19))),
            child: Icon(icon, size: 32),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.w900)),
            actions: [
              IconButton(
                tooltip: paused ? 'ادامه' : 'مکث',
                onPressed: () {
                  setState(() => paused = !paused);
                  game.setPaused(paused);
                },
                icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
              ),
              IconButton(
                tooltip: 'شروع دوباره',
                onPressed: () { game.pauseEngine(); setState(() { score = 0; lives = 3; paused = false; _dialogOpen = false; _createGame(); }); },
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(backgroundTop[project.background]),
                  Color(backgroundBottom[project.background]),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                child: Column(children: [
                  Row(children: [
                    _statusPill('⭐ $score', const Color(0xFFFFF1BE)),
                    const SizedBox(width: 8),
                    _statusPill('❤️ $lives', const Color(0xFFFFDDE4)),
                    const Spacer(),
                    _statusPill('مرحله ${project.activeLevel + 1}/${project.levels.length}', const Color(0xFFE8E0FF)),
                  ]),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(color: Color(0x663D8AC4)),
                        child: GameWidget<PlatformerPhysicsGame>(key: ObjectKey(game), game: game),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _directionButton(Icons.arrow_back_rounded, -1),
                    SizedBox(
                      width: 112,
                      height: 58,
                      child: FilledButton.icon(
                        onPressed: game.jump,
                        icon: const Icon(Icons.arrow_upward_rounded),
                        label: const Text('پرش'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFED9B39), elevation: 6, shadowColor: const Color(0x66A95C14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19))),
                      ),
                    ),
                    _directionButton(Icons.arrow_forward_rounded, 1),
                  ]),
                ]),
              ),
            ),
          ),
          floatingActionButton: paused
              ? FloatingActionButton.extended(
                  onPressed: () { setState(() => paused = false); game.setPaused(false); },
                  icon: const Icon(Icons.play_arrow), label: const Text('ادامه'),
                )
              : null,
        ),
      );

  Widget _statusPill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3D315B))),
      );
}

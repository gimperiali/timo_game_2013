import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'dart:math';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: GameWidget(
          game: MyGame(),
          overlayBuilderMap: {
            'RestartOverlay': (context, MyGame game) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showGameOverDialog(context, game);
              });
              return const SizedBox.shrink();
            },
          },
        ),
      ),
    ),
  );
}

class MyGame extends FlameGame with TapDetector {
  late Player player;
  late SpriteComponent background1;
  late SpriteComponent background2;
  List<Enemy> enemies = [];
  bool isGameOver = false;
  double elapsedTime = 0;
  double enemySpawnTime = 0;
  int score = 0;
  double scoreTimer = 0;

  @override
  Future<void> onLoad() async {
    // Load the background image
    background1 = SpriteComponent()
      ..sprite = await loadSprite('background.png')
      ..size = size // Set the size to cover the whole screen
      ..position = Vector2(0, 0); // Place the first background at (0, 0)

    background2 = SpriteComponent()
      ..sprite = await loadSprite('background.png')
      ..size = size // Set the size to cover the whole screen
      ..position = Vector2(size.x, 0); // Place the second background right after the first

    // Add the backgrounds to the game
    add(background1);
    add(background2);

    // Play background music after user interaction
    FlameAudio.bgm.initialize();

    startGame();
  }

  void startGame() {
    isGameOver = false;
    elapsedTime = 0;
    enemySpawnTime = 0;
    score = 0;
    scoreTimer = 0;
    enemies.clear();
    children.clear();
    add(background1);
    add(background2);

    player = Player();
    add(player);
    _spawnEnemy();
    overlays.remove('RestartOverlay');
    resumeEngine();
  }

  @override
  void update(double dt) {
    if (!isGameOver) {
      super.update(dt);
      elapsedTime += dt;
      enemySpawnTime += dt;
      scoreTimer += dt;

      if (enemySpawnTime >= 5) {
        _spawnEnemy();
        enemySpawnTime = 0;
      }

      if (scoreTimer >= 0.05) {
        score += 1;
        scoreTimer = 0;
      }

      for (var enemy in enemies) {
        if (player.toRect().overlaps(enemy.toRect())) {
          endGame();
        }
      }

      // Move the backgrounds to create a scrolling effect
      background1.position.x -= 100 * dt; // Move the first background
      background2.position.x -= 100 * dt; // Move the second background

      // Reset background1 when it moves off the screen
      if (background1.position.x <= -size.x) {
        background1.position.x = size.x;
      }

      // Reset background2 when it moves off the screen
      if (background2.position.x <= -size.x) {
        background2.position.x = size.x;
      }
    }
  }

  void endGame() {
    isGameOver = true;
    pauseEngine();
    overlays.add('RestartOverlay');
  }

  @override
  void onTap() {
    if (!isGameOver) {
      player.jump();

      // Play background music only after the first tap
      if (!FlameAudio.bgm.isPlaying) {
        FlameAudio.bgm.play('background_music.mp3', volume: 0.5);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _drawText(canvas, 'Time: ${elapsedTime.toStringAsFixed(2)}s', 10, 10);
    _drawText(canvas, 'Score: $score', size.x - 120, 10);
  }

  void _drawText(Canvas canvas, String text, double x, double y) {
    TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x, y));
  }

  void _spawnEnemy() {
    final random = Random();
    double randomY = random.nextDouble() * (size.y - 50);
    randomY = randomY.clamp(0, size.y - 50);
    final enemy = Enemy(randomY);
    add(enemy);
    enemies.add(enemy);
  }
}

class Player extends SpriteComponent with HasGameRef<MyGame> {
  double speedY = 0;
  static const double gravity = 1000;
  static const double jumpStrength = -300;

  Player() : super(size: Vector2(50, 50), position: Vector2(100, 300));

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('player.png');
  }

  void jump() {
    speedY = jumpStrength;
  }

  @override
  void update(double dt) {
    speedY += gravity * dt;
    y += speedY * dt;
    if (y > gameRef.size.y - height) {
      y = gameRef.size.y - height;
      speedY = 0;
      _losePoints();
    } else if (y < 0) {
      y = 0;
      speedY = 0;
      _losePoints();
    }
  }

  void _losePoints() {
    gameRef.score = max(0, gameRef.score - 5);
  }
}

class Enemy extends SpriteComponent with HasGameRef<MyGame> {
  static const double speedX = -200;
  final double initialY;

  Enemy(this.initialY) : super(size: Vector2(50, 50)) {
    position = Vector2(400, initialY);
  }

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('enemy.png');
  }

  @override
  void update(double dt) {
    if (!gameRef.isGameOver) {
      x += speedX * dt;
      if (x < -width) {
        x = gameRef.size.x;
        y = max(0, min(gameRef.size.y - height, y));
      }
    }
  }
}

void showGameOverDialog(BuildContext context, MyGame game) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("GAME OVER", textAlign: TextAlign.center),
        content: const Text("You lost!"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              game.startGame();
            },
            child: const Text("Restart"),
          ),
        ],
      );
    },
  );
}

import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import the SharedPreferences package
import 'dart:math'; // Add this import to use Random

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: GameWidget<MyGame>(
          game: MyGame(),
          overlayBuilderMap: {
            'RestartOverlay': (context, MyGame game) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showGameOverDialog(context, game);
              });
              return const SizedBox.shrink();
            },
            'PauseButton': (context, MyGame game) {
              return Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                        onPressed: () {
                          if (game.isPaused) {
                            game.resumeGame();
                          } else {
                            game.pauseGame();
                          }
                          setState(() {});
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              game.isPaused ? Icons.play_arrow : Icons.pause,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              game.isPaused ? "Resume" : "Pause",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            'StopButton': (context, MyGame game) {
              return Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () {
                      game.stopGame();
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stop, color: Colors.white),
                        SizedBox(width: 8),
                        Text("Stop", style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              );
            },
          },
          initialActiveOverlays: const ['PauseButton', 'StopButton'],
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
  bool isPaused = false;
  double elapsedTime = 0;
  double enemySpawnTime = 0;
  int score = 0;
  double scoreTimer = 0;
  bool isJumping = false;
  bool jumpPressed = false;
  int highScore = 0; // This will store the high score

  @override
  Future<void> onLoad() async {
    await loadHighScore(); // Load the high score when the game starts
    background1 = SpriteComponent()
      ..sprite = await loadSprite('background.png')
      ..size = size
      ..position = Vector2(0, 0);

    background2 = SpriteComponent()
      ..sprite = await loadSprite('background.png')
      ..size = size
      ..position = Vector2(size.x, 0);

    add(background1);
    add(background2);

    FlameAudio.bgm.initialize();
    startGame();
  }

  void pauseGame() {
    isPaused = true;
    pauseEngine();
    FlameAudio.bgm.pause();
  }

  void resumeGame() {
    isPaused = false;
    resumeEngine();
    FlameAudio.bgm.resume();
  }

  void startGame() {
    loadHighScore();
    isGameOver = false;
    elapsedTime = 0;
    enemySpawnTime = 0;
    score = 0;
    scoreTimer = 0;
    enemies.clear();
    children.whereType<Component>().toList().forEach(remove);

    add(background1);
    add(background2);

    player = Player();
    add(player);
    _spawnEnemy();

    overlays.remove('RestartOverlay');
    overlays.add('PauseButton');
    overlays.add('StopButton');

    resumeEngine();
  }

  void stopGame() {
    isGameOver = true;
    pauseEngine();
    FlameAudio.bgm.pause();
    saveHighScore(); // Save high score when game ends
    overlays.add('RestartOverlay');
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

      background1.position.x -= 100 * dt;
      background2.position.x -= 100 * dt;

      if (background1.position.x <= -size.x) {
        background1.position.x = size.x;
      }

      if (background2.position.x <= -size.x) {
        background2.position.x = size.x;
      }
    }
  }

  void endGame() {
    isGameOver = true;
    pauseEngine();
    FlameAudio.bgm.pause();
    saveHighScore(); // Save high score when game ends
    overlays.add('RestartOverlay');
  }

  @override
  void onTap() {
    if (!isGameOver && !isPaused) {
      player.jump();
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
    _drawText(canvas, 'High Score: $highScore', 10, 40); // Display high score
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

  // Save the high score using SharedPreferences
  Future<void> saveHighScore() async {
    print("Current Score: $score, High Score: $highScore"); // Debug output
    if (score > highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('highScore', score); // Store the high score
      print("Saved High Score: $score"); // Debug output
    }
  }

  // Load the high score from SharedPreferences
  Future<void> loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    highScore =
        prefs.getInt('highScore') ?? 0; // Retrieve high score or default to 0
    print("Retrieved High Score: $highScore"); // Debug output
  }
}

class Player extends SpriteComponent with HasGameRef<MyGame> {
  double speedY = 0;
  static const double gravity = 1000;
  static const double jumpStrength = -300;

  Player() : super(size: Vector2(50, 50), position: Vector2(100, 300));

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('player_1.png');
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
        content: Text("You lost!\nScore: ${game.score}"),
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

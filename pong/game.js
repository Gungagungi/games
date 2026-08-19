const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');

const WINNING_SCORE = 5;
const PADDLE_WIDTH = 12;
const PADDLE_HEIGHT = 90;
const PADDLE_SPEED = 6;
const AI_SPEED = 4;
const BALL_RADIUS = 8;

const player = {
  x: 20,
  y: canvas.height / 2 - PADDLE_HEIGHT / 2,
  width: PADDLE_WIDTH,
  height: PADDLE_HEIGHT,
  score: 0,
};

const opponent = {
  x: canvas.width - 20 - PADDLE_WIDTH,
  y: canvas.height / 2 - PADDLE_HEIGHT / 2,
  width: PADDLE_WIDTH,
  height: PADDLE_HEIGHT,
  score: 0,
};

const ball = {
  x: canvas.width / 2,
  y: canvas.height / 2,
  radius: BALL_RADIUS,
  vx: 0,
  vy: 0,
};

const keysPressed = {};
document.addEventListener('keydown', (e) => { keysPressed[e.key] = true; });
document.addEventListener('keyup', (e) => { keysPressed[e.key] = false; });

let gameOver = false;
let mode = null; // 'solo' | 'two'

document.addEventListener('keydown', (e) => {
  if (mode) return;
  if (e.key === '1') startGame('solo');
  else if (e.key === '2') startGame('two');
});

function startGame(chosenMode) {
  mode = chosenMode;
  const instructions = document.querySelector('.instructions');
  if (instructions) {
    instructions.textContent = mode === 'two'
      ? 'Joueur 1 (gauche) : Z / S — Joueur 2 (droite) : ↑ / ↓'
      : 'Toi (gauche) : ↑ / ↓ ou Z / S';
  }
  resetBall(Math.random() < 0.5 ? 1 : -1);
}

function resetBall(direction) {
  ball.x = canvas.width / 2;
  ball.y = canvas.height / 2;
  const angle = (Math.random() * 0.6 - 0.3) * Math.PI; // ~[-54°, 54°]
  const speed = 5;
  ball.vx = Math.cos(angle) * speed * direction;
  ball.vy = Math.sin(angle) * speed;
}

function movePlayer() {
  const up = mode === 'two'
    ? (keysPressed['z'] || keysPressed['Z'])
    : (keysPressed['ArrowUp'] || keysPressed['z'] || keysPressed['Z']);
  const down = mode === 'two'
    ? (keysPressed['s'] || keysPressed['S'])
    : (keysPressed['ArrowDown'] || keysPressed['s'] || keysPressed['S']);
  if (up) player.y -= PADDLE_SPEED;
  if (down) player.y += PADDLE_SPEED;
  player.y = Math.max(0, Math.min(canvas.height - player.height, player.y));
}

function movePlayer2() {
  if (keysPressed['ArrowUp']) opponent.y -= PADDLE_SPEED;
  if (keysPressed['ArrowDown']) opponent.y += PADDLE_SPEED;
  opponent.y = Math.max(0, Math.min(canvas.height - opponent.height, opponent.y));
}

function moveAI() {
  const opponentCenter = opponent.y + opponent.height / 2;
  const ballY = ball.y;
  if (opponentCenter < ballY - 10) {
    opponent.y += AI_SPEED;
  } else if (opponentCenter > ballY + 10) {
    opponent.y -= AI_SPEED;
  }
  opponent.y = Math.max(0, Math.min(canvas.height - opponent.height, opponent.y));
}

function paddleCollision(paddle) {
  return (
    ball.x - ball.radius < paddle.x + paddle.width &&
    ball.x + ball.radius > paddle.x &&
    ball.y - ball.radius < paddle.y + paddle.height &&
    ball.y + ball.radius > paddle.y
  );
}

function updateBall() {
  ball.x += ball.vx;
  ball.y += ball.vy;

  if (ball.y - ball.radius < 0) {
    ball.y = ball.radius;
    ball.vy *= -1;
  } else if (ball.y + ball.radius > canvas.height) {
    ball.y = canvas.height - ball.radius;
    ball.vy *= -1;
  }

  if (ball.vx < 0 && paddleCollision(player)) {
    ball.x = player.x + player.width + ball.radius;
    const hitPos = (ball.y - (player.y + player.height / 2)) / (player.height / 2);
    ball.vx = Math.abs(ball.vx) * 1.05;
    ball.vy = hitPos * 5;
  } else if (ball.vx > 0 && paddleCollision(opponent)) {
    ball.x = opponent.x - ball.radius;
    const hitPos = (ball.y - (opponent.y + opponent.height / 2)) / (opponent.height / 2);
    ball.vx = -Math.abs(ball.vx) * 1.05;
    ball.vy = hitPos * 5;
  }

  if (ball.x + ball.radius < 0) {
    opponent.score += 1;
    checkWin();
    if (!gameOver) resetBall(1);
  } else if (ball.x - ball.radius > canvas.width) {
    player.score += 1;
    checkWin();
    if (!gameOver) resetBall(-1);
  }
}

function checkWin() {
  if (player.score >= WINNING_SCORE || opponent.score >= WINNING_SCORE) {
    gameOver = true;
  }
}

function drawRect(x, y, w, h, color) {
  ctx.fillStyle = color;
  ctx.fillRect(x, y, w, h);
}

function drawCircle(x, y, r, color) {
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.fill();
}

function drawNet() {
  ctx.strokeStyle = '#555';
  ctx.setLineDash([8, 10]);
  ctx.beginPath();
  ctx.moveTo(canvas.width / 2, 0);
  ctx.lineTo(canvas.width / 2, canvas.height);
  ctx.stroke();
  ctx.setLineDash([]);
}

function draw() {
  drawRect(0, 0, canvas.width, canvas.height, '#000');
  drawNet();
  drawRect(player.x, player.y, player.width, player.height, '#fff');
  drawRect(opponent.x, opponent.y, opponent.width, opponent.height, '#fff');
  drawCircle(ball.x, ball.y, ball.radius, '#fff');

  ctx.fillStyle = '#fff';
  ctx.font = '32px "Courier New", monospace';
  ctx.textAlign = 'center';
  ctx.fillText(player.score, canvas.width / 4, 50);
  ctx.fillText(opponent.score, (canvas.width / 4) * 3, 50);

  if (gameOver) {
    const winner = player.score >= WINNING_SCORE
      ? (mode === 'two' ? 'Joueur 1' : 'Joueur')
      : (mode === 'two' ? 'Joueur 2' : 'Ordinateur');
    ctx.font = '28px "Courier New", monospace';
    ctx.fillText(`${winner} gagne !`, canvas.width / 2, canvas.height / 2 - 10);
    ctx.font = '16px "Courier New", monospace';
    ctx.fillText('Recharge la page pour rejouer', canvas.width / 2, canvas.height / 2 + 20);
  }

  if (!mode) {
    ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = '#fff';
    ctx.font = '24px "Courier New", monospace';
    ctx.fillText('Appuie sur 1 : Solo (vs IA)', canvas.width / 2, canvas.height / 2 - 20);
    ctx.fillText('Appuie sur 2 : 2 Joueurs', canvas.width / 2, canvas.height / 2 + 20);
  }
}

function loop() {
  if (mode && !gameOver) {
    movePlayer();
    if (mode === 'two') {
      movePlayer2();
    } else {
      moveAI();
    }
    updateBall();
  }
  draw();
  requestAnimationFrame(loop);
}

loop();

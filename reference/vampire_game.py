#!/usr/bin/env python3
"""
Vampire Survival Game
A fast-paced arcade game where you play as a vampire.
Avoid sunlight during day, hunt at night, manage your blood and thralls.

Controls:
  W/A/D/S - Movement (W=up, A=left, D=right, S=down)
  E - Switch to a bat (costs energy, flies fast)
  F - Feed on nearby human
  ESC - Quit
"""

import pygame
import random
import math
from enum import Enum

# Initialize Pygame
pygame.init()

# Constants
SCREEN_WIDTH = 1000
SCREEN_HEIGHT = 700
FPS = 60

# Game states
class TimeOfDay(Enum):
    DAY = 1
    NIGHT = 2

class VampireForm(Enum):
    HUMAN = 1
    BAT = 2

class GameState(Enum):
    MENU = 1
    PLAYING = 2
    GAME_OVER = 3

# Colors
COLOR_BG_DAY = (200, 220, 255)      # Light blue
COLOR_BG_NIGHT = (20, 20, 40)       # Dark blue/black
COLOR_VAMPIRE = (200, 0, 0)         # Red
COLOR_BAT = (100, 0, 200)           # Purple
COLOR_HUMAN = (100, 200, 100)       # Green
COLOR_ENEMY = (255, 100, 0)         # Orange
COLOR_SUNLIGHT = (255, 255, 0)      # Yellow
COLOR_TEXT = (255, 255, 255)        # White


class Vampire:
    """Player character - the vampire"""

    def __init__(self, x, y):
        self.x = x
        self.y = y
        self.radius = 12
        self.speed = 4
        self.form = VampireForm.HUMAN
        self.bat_speed = 8

        # Resources
        self.blood = 50
        self.max_blood = 100
        self.energy = 100
        self.max_energy = 100
        self.health = 100
        self.max_health = 100

        # Bat form timer
        self.bat_duration = 0
        self.max_bat_duration = 300  # 5 seconds at 60 FPS

    def update(self, keys, mouse_pos, time_of_day):
        """Update vampire based on input and state"""

        # Movement
        if keys[pygame.K_w]:
            self.y -= self.get_speed()
        if keys[pygame.K_s]:
            self.y += self.get_speed()
        if keys[pygame.K_a]:
            self.x -= self.get_speed()
        if keys[pygame.K_d]:
            self.x += self.get_speed()

        # Keep in bounds
        self.x = max(self.radius, min(SCREEN_WIDTH - self.radius, self.x))
        self.y = max(self.radius, min(SCREEN_HEIGHT - self.radius, self.y))

        # Sunlight damage during day
        if time_of_day == TimeOfDay.DAY:
            self.take_sun_damage()

        # Regenerate energy slightly at night (vampires rest)
        if time_of_day == TimeOfDay.NIGHT:
            self.energy = min(self.max_energy, self.energy + 0.3)

        # Blood drains based on time of day
        if time_of_day == TimeOfDay.DAY:
            self.blood -= 0.08  # Faster drain during day (more activity)
        else:
            self.blood -= 0.03  # Slower drain at night (vampires rest)

        # Hunger severely drains health
        if self.blood < 30:
            self.health -= 0.2  # Health loss when very hungry

        self.health = max(0, self.health)

    def get_speed(self):
        """Get current speed based on form and resources"""
        if self.form == VampireForm.BAT:
            return self.bat_speed
        else:
            # Slower if hungry
            return self.speed * (0.5 if self.blood < 20 else 1.0)

    def take_sun_damage(self):
        """Check if in sunlight and take damage"""
        # Sunlight zone is left HALF of screen (much bigger)
        if self.x < SCREEN_WIDTH // 2:
            self.health -= 0.5
            if self.health <= 0:
                self.health = 0

    def activate_bat_form(self):
        """Turn into a bat"""
        if self.energy >= 20 and self.blood >= 10:
            self.form = VampireForm.BAT
            self.bat_duration = self.max_bat_duration
            self.energy -= 20
            self.blood -= 5

    def feed(self, blood_amount):
        """Feed on blood"""
        self.blood = min(self.max_blood, self.blood + blood_amount)
        self.health = min(self.max_health, self.health + 10)

    def draw(self, screen):
        """Draw the vampire"""
        if self.form == VampireForm.BAT:
            # Show bat transformation effect
            pygame.draw.circle(screen, COLOR_BAT, (int(self.x), int(self.y)), self.radius + 2)
            pygame.draw.circle(screen, (150, 50, 255), (int(self.x), int(self.y)), self.radius)
            # End bat form if duration expired
            self.bat_duration -= 1
            if self.bat_duration <= 0:
                self.form = VampireForm.HUMAN
        else:
            pygame.draw.circle(screen, COLOR_VAMPIRE, (int(self.x), int(self.y)), self.radius)
            # Draw eyes
            eye_offset = 4
            pygame.draw.circle(screen, (255, 0, 0), (int(self.x - eye_offset), int(self.y - 3)), 2)
            pygame.draw.circle(screen, (255, 0, 0), (int(self.x + eye_offset), int(self.y - 3)), 2)


class Human:
    """NPCs that can be fed on"""

    def __init__(self, x, y):
        self.x = x
        self.y = y
        self.radius = 8
        self.speed = 1
        self.direction = random.uniform(0, 2 * math.pi)
        self.change_direction_timer = 0

    def update(self):
        """Update human movement (random walk)"""
        self.change_direction_timer += 1

        # Randomly change direction
        if self.change_direction_timer > 120:
            self.direction = random.uniform(0, 2 * math.pi)
            self.change_direction_timer = 0

        # Move
        self.x += math.cos(self.direction) * self.speed
        self.y += math.sin(self.direction) * self.speed

        # Bounce off walls
        if self.x < self.radius or self.x > SCREEN_WIDTH - self.radius:
            self.direction = math.pi - self.direction
            self.x = max(self.radius, min(SCREEN_WIDTH - self.radius, self.x))

        if self.y < self.radius or self.y > SCREEN_HEIGHT - self.radius:
            self.direction = -self.direction
            self.y = max(self.radius, min(SCREEN_HEIGHT - self.radius, self.y))

    def draw(self, screen):
        """Draw the human"""
        pygame.draw.circle(screen, COLOR_HUMAN, (int(self.x), int(self.y)), self.radius)
        pygame.draw.circle(screen, (50, 150, 50), (int(self.x), int(self.y)), self.radius - 1)


class Enemy:
    """Hunters that chase the vampire"""

    def __init__(self, x, y, vampire_x, vampire_y, is_night=False):
        self.x = x
        self.y = y
        self.radius = 10
        self.speed = 3.5 if is_night else 2.8  # Much faster
        self.detection_range = 350 if is_night else 200  # Much better detection
        self.target_x = vampire_x
        self.target_y = vampire_y
        self.chasing = False
        self.is_night = is_night
        self.patrol_timer = 0
        self.patrol_target = (self.x, self.y)
        self.health = 30  # Hunters can be killed
        self.max_health = 30

    def update(self, vampire_x, vampire_y, is_night, time_of_day):
        """Update enemy - patrol or chase"""
        # Update speed and detection based on time of day
        self.speed = 3.5 if is_night else 2.8
        self.detection_range = 350 if is_night else 200

        # Check if can see vampire
        dist_to_vampire = math.sqrt((self.x - vampire_x) ** 2 + (self.y - vampire_y) ** 2)

        if dist_to_vampire < self.detection_range:
            self.chasing = True
            self.target_x = vampire_x
            self.target_y = vampire_y
        else:
            self.chasing = False
            # Patrol smoothly - update target every 60 frames
            self.patrol_timer += 1
            if self.patrol_timer > 60:
                self.patrol_timer = 0
                # Pick random patrol point
                self.patrol_target = (random.randint(100, SCREEN_WIDTH - 100),
                                     random.randint(100, SCREEN_HEIGHT - 100))
            self.target_x, self.target_y = self.patrol_target

        # During day, hunters try to stay out of sunlight
        if not is_night and self.x < SCREEN_WIDTH // 2 - 50:
            # If in sunlight zone, move toward right side
            self.target_x = SCREEN_WIDTH * 0.7
            self.target_y = self.y

        # Move towards target
        angle = math.atan2(self.target_y - self.y, self.target_x - self.x)
        self.x += math.cos(angle) * self.speed
        self.y += math.sin(angle) * self.speed

        # Keep in bounds
        self.x = max(self.radius, min(SCREEN_WIDTH - self.radius, self.x))
        self.y = max(self.radius, min(SCREEN_HEIGHT - self.radius, self.y))

    def draw(self, screen):
        """Draw the enemy"""
        # Color based on health
        health_ratio = self.health / self.max_health
        if health_ratio > 0.6:
            color = (255, 0, 0) if self.chasing else COLOR_ENEMY
        elif health_ratio > 0.3:
            color = (255, 150, 0)  # Orange when damaged
        else:
            color = (255, 200, 0)  # Yellow when almost dead

        pygame.draw.circle(screen, color, (int(self.x), int(self.y)), self.radius)

        # Draw alert indicator if chasing
        if self.chasing:
            pygame.draw.circle(screen, (255, 100, 0), (int(self.x), int(self.y)), self.radius + 3, 2)


class Game:
    """Main game class"""

    def __init__(self):
        self.screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
        pygame.display.set_caption("Vampire Survival - Feed or Die")
        self.clock = pygame.time.Clock()
        self.font = pygame.font.Font(None, 24)
        self.big_font = pygame.font.Font(None, 36)
        self.title_font = pygame.font.Font(None, 60)

        self.game_state = GameState.MENU
        self.reset()

    def reset(self):
        """Reset game state"""
        self.vampire = Vampire(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2)
        # More humans during day
        self.humans = [Human(random.randint(50, SCREEN_WIDTH - 50),
                            random.randint(50, SCREEN_HEIGHT - 50)) for _ in range(10)]
        # 3 hunters during day
        self.enemies = [Enemy(random.randint(50, SCREEN_WIDTH - 50),
                             random.randint(50, SCREEN_HEIGHT - 50),
                             self.vampire.x, self.vampire.y, is_night=False) for _ in range(3)]

        self.time_of_day = TimeOfDay.DAY
        self.time_cycle = 0
        self.day_duration = 1800  # 30 seconds at 60 FPS
        self.total_time = 0

        self.game_over = False
        self.score = 0

    def update(self):
        """Update game state"""
        if self.game_state == GameState.MENU:
            return  # Menu doesn't need updates

        if self.game_over:
            return

        keys = pygame.key.get_pressed()

        # Handle bat transformation
        if keys[pygame.K_e]:
            self.vampire.activate_bat_form()

        # Update vampire
        self.vampire.update(keys, None, self.time_of_day)

        # Update humans
        for human in self.humans:
            human.update()

        # Update enemies (more at night, more aggressive)
        for enemy in self.enemies[:]:
            is_night = self.time_of_day == TimeOfDay.NIGHT
            enemy.update(self.vampire.x, self.vampire.y, is_night, self.time_of_day)
            # Check collision with vampire
            dist = math.sqrt((enemy.x - self.vampire.x) ** 2 + (enemy.y - self.vampire.y) ** 2)
            if dist < self.vampire.radius + enemy.radius:
                # Vampire damages enemy on collision
                if self.vampire.form == VampireForm.BAT:
                    enemy.health -= 2  # Bat form does more damage
                else:
                    enemy.health -= 0.5  # Human form does less damage

                # Enemy damages vampire
                self.vampire.health -= 0.5

                # If enemy is dead, remove and award points
                if enemy.health <= 0:
                    self.enemies.remove(enemy)
                    self.score += 50  # Bonus points for killing hunters

        # Handle feeding (F key)
        if keys[pygame.K_f]:
            for human in self.humans[:]:
                dist = math.sqrt((human.x - self.vampire.x) ** 2 + (human.y - self.vampire.y) ** 2)
                if dist < 40:
                    self.vampire.feed(30)
                    self.humans.remove(human)
                    self.score += 10
                    # Spawn new human
                    self.humans.append(Human(random.randint(50, SCREEN_WIDTH - 50),
                                           random.randint(50, SCREEN_HEIGHT - 50)))
                    break

        # Update day/night cycle
        self.time_cycle += 1
        self.total_time += 1

        if self.time_cycle > self.day_duration:
            self.time_cycle = 0
            # Toggle day/night
            if self.time_of_day == TimeOfDay.DAY:
                # TRANSITION TO NIGHT
                self.time_of_day = TimeOfDay.NIGHT
                # Reduce humans (people go inside)
                self.humans = self.humans[:4]
                # Spawn more aggressive enemies at night
                self.enemies = []
                for _ in range(6):  # 6 hunters at night
                    self.enemies.append(Enemy(random.randint(50, SCREEN_WIDTH - 50),
                                            random.randint(50, SCREEN_HEIGHT - 50),
                                            self.vampire.x, self.vampire.y, is_night=True))
            else:
                # TRANSITION TO DAY
                self.time_of_day = TimeOfDay.DAY
                # Spawn more humans during day
                self.humans = [Human(random.randint(50, SCREEN_WIDTH - 50),
                                    random.randint(50, SCREEN_HEIGHT - 50)) for _ in range(10)]
                # 3 hunters during day
                self.enemies = [Enemy(random.randint(50, SCREEN_WIDTH - 50),
                                     random.randint(50, SCREEN_HEIGHT - 50),
                                     self.vampire.x, self.vampire.y, is_night=False) for _ in range(3)]

        # Check if dead
        if self.vampire.health <= 0:
            self.game_over = True
            self.game_state = GameState.GAME_OVER

    def draw(self):
        """Draw everything"""
        # Draw menu screen
        if self.game_state == GameState.MENU:
            self.draw_menu()
            pygame.display.flip()
            return

        # Background color based on time of day
        if self.time_of_day == TimeOfDay.DAY:
            self.screen.fill(COLOR_BG_DAY)
            # Draw sunlight danger zone on left HALF of screen
            sun_overlay = pygame.Surface((SCREEN_WIDTH // 2, SCREEN_HEIGHT))
            sun_overlay.set_alpha(80)
            sun_overlay.fill((255, 255, 100))
            self.screen.blit(sun_overlay, (0, 0))
        else:
            self.screen.fill(COLOR_BG_NIGHT)

        # Draw time indicator
        time_text = f"{'DAY' if self.time_of_day == TimeOfDay.DAY else 'NIGHT'}"
        time_color = (255, 200, 0) if self.time_of_day == TimeOfDay.DAY else (100, 150, 255)
        time_label = self.big_font.render(time_text, True, time_color)
        self.screen.blit(time_label, (SCREEN_WIDTH - 150, 20))

        # Draw all entities
        for human in self.humans:
            human.draw(self.screen)

        for enemy in self.enemies:
            enemy.draw(self.screen)

        self.vampire.draw(self.screen)

        # Draw HUD
        self.draw_hud()

        # Draw game over screen
        if self.game_over:
            self.draw_game_over()

        pygame.display.flip()

    def draw_menu(self):
        """Draw the how-to-play menu"""
        self.screen.fill((20, 20, 40))  # Dark background

        # Title
        title = self.title_font.render("VAMPIRE SURVIVAL", True, (255, 0, 0))
        self.screen.blit(title, (SCREEN_WIDTH // 2 - 300, 30))

        # Subtitle
        subtitle = self.big_font.render("How to Play", True, (200, 100, 100))
        self.screen.blit(subtitle, (SCREEN_WIDTH // 2 - 100, 100))

        # Game instructions
        y_pos = 160
        line_height = 28
        instructions = [
            "OBJECTIVE: Survive as a vampire. Feed on humans, avoid hunters and sunlight.",
            "",
            "CONTROLS:",
            "  W/A/D/S     - Move (W=up, A=left, D=right, S=down)",
            "  E           - Switch to a bat (costs blood and energy)",
            "  F           - Feed on nearby human to restore blood",
            "  ESC         - Quit game",
            "",
            "GAMEPLAY:",
            "  DAY PHASE (30 seconds):",
            "    • Left half of screen is SUNLIGHT - takes damage",
            "    • Fewer hunters but MANY humans to feed on",
            "    • Goal: Stay out of sun, feed, survive",
            "",
            "  NIGHT PHASE (30 seconds):",
            "    • NO SUNLIGHT - entire map is safe",
            "    • MANY hunters patrol aggressively",
            "    • Fewer humans available to feed on",
            "    • Goal: Avoid/fight hunters, feed if possible",
            "",
            "RESOURCES:",
            "  Blood    - Drains constantly (faster in day, slower at night)",
            "  Energy   - Used to switch to a bat (press E)",
            "  Health   - Drops from sunlight and hunter attacks",
            "",
            "TIPS:",
            "  • Kill hunters by ramming them (bat form = more damage)",
            "  • Switching to a bat (E) moves fast but costs blood and energy",
            "  • You need blood to survive - feeding (F) is essential!",
        ]

        for line in instructions:
            if line == "":
                y_pos += line_height // 2
            else:
                # Color important keywords
                if "DAY" in line or "NIGHT" in line:
                    color = (255, 200, 0) if "DAY" in line else (100, 150, 255)
                elif line.startswith("  "):
                    color = (200, 200, 200)
                elif line.isupper() or ":" in line:
                    color = (100, 255, 100)
                else:
                    color = (255, 255, 255)

                label = self.font.render(line, True, color)
                self.screen.blit(label, (30, y_pos))
                y_pos += line_height

        # Start instruction
        start_text = self.big_font.render("Press SPACE to Start", True, (0, 255, 0))
        self.screen.blit(start_text, (SCREEN_WIDTH // 2 - 180, SCREEN_HEIGHT - 50))

    def draw_hud(self):
        """Draw heads-up display"""
        # Position HUD on RIGHT side to avoid yellow sunlight overlay
        hud_x = SCREEN_WIDTH - 250
        hud_y = 10

        # Color based on danger level
        blood_color = (255, 0, 0) if self.vampire.blood < 30 else (100, 255, 100)
        health_color = (255, 0, 0) if self.vampire.health < 30 else (100, 255, 100)
        energy_color = (255, 200, 0) if self.vampire.energy < 30 else (100, 255, 100)

        hud_data = [
            (f"Blood: {int(self.vampire.blood)}/{int(self.vampire.max_blood)}", blood_color),
            (f"Energy: {int(self.vampire.energy)}/{int(self.vampire.max_energy)}", energy_color),
            (f"Health: {int(self.vampire.health)}/{int(self.vampire.max_health)}", health_color),
            (f"Score: {self.score}", COLOR_TEXT),
            (f"Humans: {len(self.humans)}", COLOR_TEXT),
            (f"Enemies: {len(self.enemies)}", (255, 100, 100) if len(self.enemies) > 4 else COLOR_TEXT),
            (f"Time: {self.total_time // 60}s", COLOR_TEXT),
        ]

        for i, (text, color) in enumerate(hud_data):
            label = self.font.render(text, True, color)
            self.screen.blit(label, (hud_x, hud_y + i * 25))

        # Draw controls hint at bottom left
        controls = "W/A/D/S-Move  E-Bat  F-Feed  ESC-Quit"
        label = self.font.render(controls, True, (200, 200, 200))
        self.screen.blit(label, (10, SCREEN_HEIGHT - 30))

    def draw_game_over(self):
        """Draw game over screen"""
        # Semi-transparent overlay
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT))
        overlay.set_alpha(200)
        overlay.fill((0, 0, 0))
        self.screen.blit(overlay, (0, 0))

        # Game over text
        game_over_text = self.big_font.render("VAMPIRE DEFEATED", True, (255, 0, 0))
        score_text = self.font.render(f"Final Score: {self.score}", True, COLOR_TEXT)
        time_text = self.font.render(f"Survived: {self.total_time // 60} seconds", True, COLOR_TEXT)
        restart_text = self.font.render("Press SPACE to restart or ESC to quit", True, COLOR_TEXT)

        self.screen.blit(game_over_text, (SCREEN_WIDTH // 2 - 200, SCREEN_HEIGHT // 2 - 80))
        self.screen.blit(score_text, (SCREEN_WIDTH // 2 - 100, SCREEN_HEIGHT // 2))
        self.screen.blit(time_text, (SCREEN_WIDTH // 2 - 120, SCREEN_HEIGHT // 2 + 40))
        self.screen.blit(restart_text, (SCREEN_WIDTH // 2 - 200, SCREEN_HEIGHT // 2 + 100))

    def handle_events(self):
        """Handle input events"""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return False

            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return False

                # Start game from menu
                if event.key == pygame.K_SPACE and self.game_state == GameState.MENU:
                    self.game_state = GameState.PLAYING
                    self.reset()

                # Restart after game over
                if event.key == pygame.K_SPACE and self.game_over:
                    self.game_state = GameState.PLAYING
                    self.reset()

        return True

    def run(self):
        """Main game loop"""
        running = True

        while running:
            running = self.handle_events()

            self.update()
            self.draw()

            self.clock.tick(FPS)

        pygame.quit()


if __name__ == "__main__":
    game = Game()
    game.run()

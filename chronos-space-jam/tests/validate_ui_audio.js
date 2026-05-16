const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const requiredAudio = [
  "ui_click.wav",
  "ui_back.wav",
  "slide_start.wav",
  "tick.wav",
  "death.wav",
  "level_clear.wav",
  "menu_loop.wav",
];

for (const file of requiredAudio) {
  const fullPath = path.join(root, "assets", "audio", file);
  assert(fs.existsSync(fullPath), `Missing audio asset: ${file}`);
  assert(fs.statSync(fullPath).size > 44, `Audio asset is empty: ${file}`);
  const header = fs.readFileSync(fullPath).subarray(0, 12).toString("ascii");
  assert(header.startsWith("RIFF") && header.endsWith("WAVE"), `Invalid WAV header: ${file}`);
}

const project = read("project.godot");
assert(
  project.includes('AudioManager="*res://scripts/autoload/audio_manager.gd"'),
  "AudioManager autoload is not registered"
);

const audioManager = read("scripts/autoload/audio_manager.gd");
for (const method of ["play_ui_click", "play_ui_back", "play_slide_start", "play_tick", "play_death", "play_level_clear", "start_menu_music"]) {
  assert(audioManager.includes(`func ${method}`), `AudioManager missing ${method}`);
}

const settingsScene = read("scenes/ui/settings_menu.tscn");
for (const node of ["MasterValueLabel", "MusicValueLabel", "SFXValueLabel", "ShakeValueLabel"]) {
  assert(settingsScene.includes(`name="${node}"`), `Settings scene missing ${node}`);
}
assert(settingsScene.includes("SettingsCardStyle"), "Settings panel is missing styled card resource");
assert(settingsScene.includes("SectionCardStyle"), "Settings sections are missing card styling");
assert(!settingsScene.includes('name="TopGlow"'), "Settings background should not include the blue TopGlow band");
assert(!settingsScene.includes("Color(0.06, 0.18, 0.24"), "Settings background still contains the blue glow color");

const settingsManager = read("scripts/autoload/settings_manager.gd");
for (const setting of ["master_volume", "music_volume", "sfx_volume", "screen_shake_intensity"]) {
  assert(
    new RegExp(`var\\s+${setting}\\s*:\\s*float\\s*=\\s*50\\.0`).test(settingsManager),
    `SettingsManager should default ${setting} to 50.0`
  );
}
assert(settingsManager.includes('"master_volume", 50.0'), "SettingsManager load fallback for master_volume should be 50.0");
assert(settingsManager.includes('"music_volume",  50.0'), "SettingsManager load fallback for music_volume should be 50.0");
assert(settingsManager.includes('"sfx_volume",    50.0'), "SettingsManager load fallback for sfx_volume should be 50.0");
assert(settingsManager.includes('"screen_shake_intensity", 50.0'), "SettingsManager load fallback for screen_shake_intensity should be 50.0");

const settingsScript = read("scripts/settings_menu.gd");
for (const callback of ["_update_value_labels", "_on_slider_drag_ended"]) {
  assert(settingsScript.includes(`func ${callback}`), `Settings script missing ${callback}`);
}

const mainMenu = read("scripts/main_menu.gd");
assert(mainMenu.includes("AudioManager.start_menu_music()"), "Main menu does not start menu music");
assert(mainMenu.includes("_wire_button_audio"), "Main menu buttons do not share audio wiring");

const player = read("scripts/player.gd");
assert(player.includes("AudioManager.play_slide_start()"), "Player slide start SFX is not wired");

const gameLevel = read("scripts/game_level.gd");
for (const call of ["AudioManager.play_tick()", "AudioManager.play_death()", "AudioManager.play_level_clear()"]) {
  assert(gameLevel.includes(call), `Game level missing ${call}`);
}

console.log("UI/audio validation passed");

module terminal_interface::keymap;
import std::collections::map;

alias KeyHandler = fn void (Key key);

struct KeyMap {
  HashMap{Key, KeyHandler} table;
  KeyHandler default_handler;
}

fn void KeyMap.tinit(&self)
{
  self.table.tinit();
}

fn void KeyMap.map_key(&self, Key key, KeyHandler handler)
{
  self.table.set(key, handler);
}

fn KeyHandler? KeyMap.get(&self, Key key)
{
  return self.table.get(key);
}

module terminal_interface::keymap::key;

typedef Key = char[4];

fn uint Key.hash(self)
{
  return self[0] << 24 + self[1] << 16 + self[2] << 8 + self[3];
}

macro bool Key.is_multibyte(self) => self[0] == 27;

macro Key ctrl_key(char key) => {key.to_upper() - 64, 0, 0, 0};

macro Key alt_key(char key) => {27, key, 0, 0};

macro Key key(char key) => {key, 0, 0, 0};


const Key EMPTY = {};

const Key ESC = {[0] = 27};
const Key ENTER = {[0] = 13};
const Key SPACE = {[0] = 32};
const Key BSPC = {[0] = 127};
const Key DELETE = {27, 91, 51, 0};
const Key UP = {27, 91, 65, 0};
const Key DOWN = {27, 91, 66, 0};
const Key RIGHT = {27, 91, 67, 0};
const Key LEFT = {27, 91, 68, 0};

const Key F1 = {27, 79, 80, 0};
const Key F2 = {27, 79, 81, 0};
const Key F3 = {27, 79, 82, 0};
const Key F4 = {27, 79, 83, 0};
const Key F5 = {27, 91, 49, 53};
const Key F6 = {27, 91, 49, 55};
const Key F7 = {27, 91, 49, 56};
const Key F8 = {27, 91, 49, 57};
const Key F9 = {27, 91, 50, 48};
const Key F10 = {27, 91, 50, 49};
const Key F11 = {27, 91, 50, 51};
const Key F12 = {27, 91, 50, 52};

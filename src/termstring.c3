module terminal_interface::termstring;

typedef TermString = inline DString;

enum SimpleColor: short (String value) {
  BLACK = "30",
  BG_BLACK = "40",
  RED = "31",
  BG_RED = "41",
  GREEN = "32",
  BG_GREEN = "42",
  YELLOW = "33",
  BG_YELLOW = "43",
  BLUE = "34",
  BG_BLUE = "44",
  MAGENTA = "35",
  BG_MAGENTA = "45",
  CYAN = "36",
  BG_CYAN = "46",
  WHITE = "37",
  BG_WHITE = "47",
  DEFAULT = "39",
  BG_DEFAULT = "49",
  RESET = "0",
  BG_RESET = "0",
}

enum Style: short (String value) {
  CLEAR = "0",
  BOLD = "1",
  RESET_BOLD = "21",
  DIM = "2",
  RESET_DIM = "22",
  ITALIC = "3",
  RESET_ITALIC = "23",
  UNDERLINE = "4",
  RESET_UNDERLINE = "24",
  BLINKING = "5",
  RESET_BLINKING = "25",
  INVERSE = "7",
  RESET_INVERSE = "27",
  HIDDEN = "8",
  RESET_HIDDEN = "28",
  STRIKE_THROUGH = "9",
  RESET_STRIKE_THROUGH = "29",
}

fn TermString* TermString.append_style(&self, Style style)
{
  self.append_chars("\e[");
  self.append_chars(style.value);
  self.append_chars("m");

  return self;
}

fn TermString* TermString.reset_style(&self)
{
  return self.append_style(CLEAR);
}

fn TermString* TermString.color_simple(&self, SimpleColor color)
{
  self.append_chars("\e[");
  self.append_chars(color.value);
  self.append_chars("m");

  return self;
}

fn TermString* TermString.color_256(&self, char color, bool background = false)
{
  self.append_chars("\e[");
  if (!background) {
    self.append_chars("38;5;");
  } else {
    self.append_chars("48;5;");
  }
  self.appendf("%d", color);
  self.append_chars("m");

  return self;
}

macro TermString* TermString.append(&self, value) {
  ((DString*)self).append(value);

  return self;
}

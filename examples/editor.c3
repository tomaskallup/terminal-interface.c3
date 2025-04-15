import terminal_interface;
import std::io;

KeyMap normal_keymap;
KeyMap insert_keymap;
KeyMap command_keymap;

enum Mode {
  NORMAL,
  INSERT,
  COMMAND,
}

Mode current_mode = NORMAL;

DString command_text;

fn void? render_status_line()
{
  @pool() {
    TermString status;
    status.tinit();

    switch (current_mode) {
      case NORMAL:
        status.color_simple(BG_BLUE);
        status.color_simple(WHITE);
        status.append("NORMAL");
      case INSERT:
        status.color_simple(BG_GREEN);
        status.color_simple(WHITE);
        status.append("INSERT");
      case COMMAND:
        status.color_simple(BG_RED);
        status.color_simple(WHITE);
        status.append("COMMAND");
    }

    status.reset_style();
    ti::set_line((usz)ti::winsize.ws_row - 1, status.str_view())!;
    ti::clear_line_from_cursor()!;
  };
}

fn void? render_command_line()
{
  if (current_mode != COMMAND) {
    ti::set_line((usz)ti::winsize.ws_row, "")!;
  } else {
    ti::set_cursor_pos(ti::winsize.ws_row, 0)!!;
    ti::write(":")!!;
    ti::write(command_text.str_view())!!;
    ti::flush()!!;
  }

  ti::clear_line_from_cursor()!;
}

fn void? render_callback()
{
  ti::clear()!;
  render_status_line()!;
  render_command_line()!;
}

fn void resize_handler(Winsize)
{
  render_callback()!!;
}

fn void exit(Key)
{
  ti::close()!!;
}

fn void handle_command_key(Key key)
{
  switch (key) {
    case key::ENTER:
      if (command_text.str_view() == "q") return exit(key);
      command_text.clear();
      set_normal_mode(key);
    // Handle backspace
    case key::BSPC:
      if (command_text.len()) command_text.chop(command_text.len() - 1);
    default:
      if (key[1] == 0) {
        command_text.append_char(key[0]);
      }
  }

  render_command_line()!!;
}

fn void set_normal_mode(Key)
{
  ti::set_keymap(normal_keymap);
  current_mode = NORMAL;
  render_status_line()!!;
  render_command_line()!!;
}

fn void set_insert_mode(Key)
{
  ti::set_keymap(insert_keymap);
  current_mode = INSERT;
  render_status_line()!!;
  render_command_line()!!;
}

fn void set_command_mode(Key)
{
  ti::set_keymap(command_keymap);
  current_mode = COMMAND;
  render_status_line()!!;
  render_command_line()!!;
}

fn void main()
{
  normal_keymap.tinit();
  insert_keymap.tinit();
  command_keymap.tinit();
  command_text.tinit();

  normal_keymap.map_key(key::ctrl_key('c'), &exit);
  normal_keymap.map_key(key::key(':'), &set_command_mode);
  normal_keymap.map_key(key::key('i'), &set_insert_mode);

  command_keymap.map_key(key::ctrl_key('c'), &set_normal_mode);
  command_keymap.map_key(key::ESC, &set_normal_mode);
  command_keymap.default_handler = &handle_command_key;

  insert_keymap.map_key(key::ctrl_key('c'), &set_normal_mode);
  insert_keymap.map_key(key::ESC, &set_normal_mode);

  ti::set_keymap(normal_keymap);
  ti::set_resize_handler(&resize_handler);

  ti::init()!!;
  ti::start()!!;
}

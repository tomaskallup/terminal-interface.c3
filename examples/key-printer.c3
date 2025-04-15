import terminal_interface;
import std::io;

KeyMap keymap;
Key last_key;

fn void handle_key(Key key)
{
  last_key = key;

  render_callback()!!;
}

fn void exit(Key)
{
  ti::close()!!;
}

fn void? inital_render()
{
  ti::clear()!;
  render_callback()!;
}

fn void? render_callback()
{
  ti::set_line(1, "Press Ctrl+C to exit.")!;
  if (last_key[0] > 0) {
    ti::set_line(2, string::tformat("Last key: %s", last_key))!;
  } else {
    ti::set_line(2, "No key pressed yet.")!;
  }
  ti::clear_line_from_cursor()!;
}

fn void main()
{
  keymap.tinit();
  keymap.map_key(key::ctrl_key('c'), &exit);
  keymap.default_handler = &handle_key;

  ti::set_keymap(keymap);

  ti::init()!!;
  ti::start(&inital_render)!!;
}

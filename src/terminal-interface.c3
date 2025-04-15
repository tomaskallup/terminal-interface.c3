module terminal_interface::ti;
import libc;
import std::io;
import std::collections::list;
import std::thread;
import std::net::os;
import terminal_interface::keymap;

const TIOCGWINSZ = 0x5413;
const TIOCSWINSZ = 0x5414;

struct Winsize {
  ushort ws_row;
  ushort ws_col;
  ushort ws_xpixel;   /* unused */
  ushort ws_ypixel;   /* unused */
}

extern fn CInt ioctl(CInt fd, CInt op, ...);

alias TickCallback = fn void? ();

alias ResizeHandler = fn void (Winsize winsize);

bool initialized @private;
bool running @private;
Termios original_termios @private;
Termios termios @private;
File *input_file @private;
File *output_file @private;
Fd input_fd @private;
Winsize winsize;
bool pending_resize @private;
List{Key} input_queue @private;
TickCallback tick_callback @private;
ResizeHandler resize_handler @private;
KeyMap current_keymap @private;

Mutex queue_mutex @private;
Thread input_thread @private;

const O_NONBLOCK = 0x800;

fn int read_input(void*)
{
  int flags = os::fcntl((NativeSocket)input_fd, os::F_GETFL, 0);
  os::fcntl((NativeSocket)input_fd, os::F_SETFL, flags | O_NONBLOCK);

  while OUTER: (initialized) {
    Key buf;
    usz len = 0;
    usz wanted_len = 1;

    while(len < wanted_len) {
      char? ch = input_file.read_byte();

      if (!initialized) break OUTER;

      if (catch excuse = ch) {
        if (len) {
          // We were expecting a multibyte, but didn't receive it
          // So the user probably just pressed Esc, or there is a missing detection for a key
          // We just break out of the loop and push the "unfinished" sequence
          break;
        }
        if (excuse == io::EOF) {
          thread::sleep_ms(50);
          continue;
        } else {
          break OUTER;
        }
      }

      if (ch > 0) {
        buf[len++] = ch;
        // Handle multibytes
        if (len == 1 && buf.is_multibyte()) wanted_len = 2;
        if (len == 2 && (buf[1] == 91 || buf[1] == 79)) wanted_len = 3;
        if (len == 3 && (buf[2] == 49 || buf[2] == 50)) wanted_len = 4;
      }
    }

    queue_mutex.lock()!!;
    input_queue.push(buf);
    queue_mutex.unlock()!!;
  }

  // Restore flags
  os::fcntl((NativeSocket)input_fd, os::F_SETFL, flags);

  return 0;
}

fn void panic_handler(String message, String file, String function, uint line) {
  if (initialized && running) @catch(close());

  builtin::default_panic(message, file, function, line);
}

fn void update_winsize()
{
  assert(initialized, "You need to call init first");
  ioctl(input_fd, TIOCGWINSZ, &winsize);
  pending_resize = true;
}

faultdef ALREADY_INITIALIZED;

fn KeyMap set_keymap(KeyMap new_keymap)
{
  KeyMap old_keymap = current_keymap;
  current_keymap = new_keymap;

  return old_keymap;
}

fn void set_resize_handler(ResizeHandler new_resize_handler)
{
  resize_handler = new_resize_handler;
}

fn void? init(TickCallback new_tick_callback = null, File* new_input_file = io::stdin(), File* new_output_file = io::stdout())
{
  if (initialized) return ALREADY_INITIALIZED?;

  initialized = true;

  tick_callback = new_tick_callback;
  input_file = new_input_file;
  output_file = new_output_file;

  input_fd = libc::fileno(input_file.file);

  original_termios.getAttr(input_fd);
  termios = original_termios;

  input_queue.init(tmem);

  queue_mutex.init()!;

  builtin::panic = &panic_handler;

  update_winsize();
}

fn void winch_handler(int) {
  update_winsize();
}

fn void? start(TickCallback run_callback = null)
{
  assert(initialized, "You need to call init first");
  assert(!running, "TI is already running");
  write(
    // Switch to alternate screen
    "\e[?1049h" +++
    // Reset colors
    "\e[0m" +++
    // Go to first line & column
    "\e[H"
  )!;

  // Disable Canonical mode for raw input processing and priting the keypresses
  termios.c_lflag &= ~(termios::ICANON | termios::ECHO);
  // Disable signals, so Ctrl + c doesn't kill the app.
  termios.c_lflag &= ~(termios::ISIG);
  // Disable flow, so Ctrl + q & Ctrl + s
  termios.c_iflag &= ~(termios::IXON);
  termios.setAttr(input_fd, termios::TCSANOW);

  flush()!;

  Sigaction sa;
  sa.sa_handler = &winch_handler;
  sa.sa_flags = libc::SA_RESTART;
  running = true;
  libc::sigaction(0x1c, &sa, null);

  input_thread.create(&read_input, null)!;

  if (run_callback) run_callback()!;

  run()!;
}

fn void? run() @private
{
  assert(initialized, "You need to call init first");

  while (running) {
    if (tick_callback) tick_callback()!;

    if (try event = ti::get_event()) {
      if (event.type == EventType.WIN_RESIZE) {
        if (resize_handler != null) resize_handler(winsize);
      } else if (event.type == EventType.INPUT) {
        KeyHandler? handler = current_keymap.get(event.input);

        if (catch handler) {
          if (current_keymap.default_handler) current_keymap.default_handler(event.input);

          continue;
        }

        handler(event.input);
      }
    }
  }
}

fn void stop()
{
  assert(initialized, "You need to call init first");

  running = false;
}

fn void? close()
{
  assert(initialized, "You need to call init first");
  // Exit alternate screen and reset colors
  write("\e[?1049l" +++ "\e[0m")!;
  flush()!;

  initialized = false;
  running = false;

  // Exit input_thread
  input_thread.detach()!;
  queue_mutex.destroy()!;
  // Reset termios
  original_termios.setAttr(input_fd, termios::TCSANOW);

  builtin::panic = &builtin::default_panic;
}

enum EventType {
  INPUT,
  WIN_RESIZE,
}

struct Event {
  EventType type;
  union {
    Key input;
    Winsize new_size;
  }
}

faultdef EVENT_QUEUE_EMPTY;

fn Event? get_event() {
  assert(initialized, "You need to call init first");

  if (pending_resize) {
    pending_resize = false;
    return {
      .type = EventType.WIN_RESIZE,
      .new_size = get_winsize(),
    };
  }

  Key input = get_input();

  if (input != key::EMPTY) return {
    .type = EventType.INPUT,
    .input = input,
  };

  thread::sleep_ms(50);

  return EVENT_QUEUE_EMPTY?;
}

fn Winsize get_winsize()
{
  assert(initialized, "You need to call init first");
  return winsize;
}

fn Key get_input()
{
  assert(initialized, "You need to call init first");

  Key? input = input_queue.pop();

  if (catch excuse = input) {
    return key::EMPTY;
  }

  return input;
}

<*
  @require line >= 1 : "Line must be >= 1"
  @require col >= 1 : "Col must be >= 1"
*>
fn void? set_line_col(usz line, usz col, String content)
{
  writef("\e[%d;%df%s", line, col, content)!;
  flush()!;
}

macro void? set_line(usz line, String content)
{
  set_line_col(line, 1, content)!;
}

fn void? flush()
{
  assert(initialized, "You need to call init first");
  output_file.flush()!;
}

fn void? write_char(char c)
{
  assert(initialized, "You need to call init first");
  output_file.write_byte(c)!;
}

fn void? append_char(void* data, char c)
{
  assert(initialized, "You need to call init first");
  output_file.write_byte(c)!;
}

fn void? write(String content)
{
  assert(initialized, "You need to call init first");
  output_file.write(content)!;
}

fn void? writen(String content)
{
  write(content)!;
  write_char('\n')!;
}

fn usz? writef(String format, args...)
{
  assert(initialized, "You need to call init first");
  Formatter formatter;
  formatter.init(&append_char);
  return formatter.vprintf(format, args);
}

fn usz? writefn(String format, args...)
{
  usz? result = writef(format, ...args);
  write_char('\n')!;

  return result;
}

fn void? clear(bool should_flush = true)
{
  write("\e[2J")!;
  if (should_flush)
  {
    flush()!;
  }
}

fn void? clear_line(bool should_flush = true)
{
  write("\e[2K")!;
  if (should_flush)
  {
    flush()!;
  }
}

fn void? clear_line_from_cursor(bool should_flush = true)
{
  write("\e[0K")!;
  if (should_flush)
  {
    flush()!;
  }
}

fn void? set_cursor_pos(usz line, usz col)
{
  writef("\e[%d;%dH", line, col)!;
  flush()!;
}

fn void? reset_style(bool should_flush = true)
{
  write("\e[0m")!;
  if (should_flush)
  {
    flush()!;
  }
}

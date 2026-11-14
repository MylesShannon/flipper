<p align="center">
  <img src="docs/icon.png" alt="Flipper app icon" width="128" height="128">
</p>

<h1 align="center">Flipper</h1>

<p align="center">Reverse mouse scrolling on Mac, without touching your trackpad.</p>

<p align="center">
  <a href="https://github.com/MylesShannon/flipper/releases/latest">Download</a> ·
  <a href="https://mylesshannon.github.io/flipper/">Website</a> ·
  <a href="#faq">FAQ</a> ·
  <a href="docs/development.md">Build from source</a>
</p>

Flipper is a free, open source macOS menu bar app that reverses the scroll
direction of a mouse and a trackpad separately. Keep natural scrolling on your
MacBook trackpad or Magic Trackpad and have a normal scroll wheel on your mouse,
or the other way round.

## Why your mouse scrolls the wrong way on a Mac

macOS has a single **Natural scrolling** setting that covers every device. Turn it
on and the mouse wheel scrolls backwards. Turn it off and the trackpad does. There
is no built-in way to set the scroll direction for the mouse and the trackpad
independently. Flipper leaves that setting alone and reverses only the device you
pick.

## Features

- Reverse mouse scroll direction, trackpad scroll direction, or both.
- Reverse vertical and horizontal scrolling, each on or off.
- Takes effect straight away, with no restart or log out.
- Notarized by Apple, so it opens like any other app.
- No network access, no analytics, no dependencies. About 400 lines of Swift.
- Works on Apple silicon and Intel Macs running macOS 14 Sonoma, macOS 15
  Sequoia, macOS 26 Tahoe or later.

## Install

Download the latest `Flipper-<version>.zip` from
[Releases](https://github.com/MylesShannon/flipper/releases/latest), unzip it, and open `Flipper.app`.

Flipper sets itself up:

1. If it isn't in Applications, it offers to move itself there.
2. It adds itself to Open at Login, so it's running whenever you are. You can turn
   that off from its menu, and it stays off.
3. It asks for Accessibility, which it needs to change scroll events. Switch
   Flipper on in System Settings, Privacy & Security, Accessibility. It starts
   working within a couple of seconds, with no restart.

Until it has Accessibility, the menu bar icon is dimmed and the menu says
**Needs Accessibility**.

To build it yourself instead, see [Development](docs/development.md).

## Using it

Click the arrows in the menu bar.

- **Flip: Mouse** reverses the scroll wheel of a mouse.
- **Flip: Trackpad** reverses a trackpad or Magic Mouse.
- **Directions: Up and Down** and **Left and Right** pick which directions get
  reversed, for whichever devices are on.
- **Open at Login** starts Flipper when you log in.
- **Quit Flipper** (`⌘Q`) stops it until you open it again or log in.

It starts with Mouse, Up and Down, and Left and Right on, and Trackpad off. That's
the usual fix: leave natural scrolling on for the trackpad and give the mouse wheel
its traditional direction back.

## How it works

Flipper puts a Core Graphics event tap in front of every app and rewrites each
scroll event before it's delivered. It tells a mouse from a trackpad by how the
event scrolls: a mouse wheel moves in whole lines, a trackpad smoothly in pixels.
For each event it flips, it negates the vertical and horizontal amounts in all
three forms an event carries (lines, pixels and fixed point), since different apps
read different ones.

## FAQ

### How do I reverse mouse scrolling but not the trackpad on a Mac?

Install Flipper and leave **Flip: Mouse** on. Keep macOS's natural scrolling set
the way you like it for the trackpad, and Flipper turns the mouse wheel around.

### Can I turn off natural scrolling for the mouse only?

Not in System Settings: the mouse and trackpad switches are linked, so changing one
changes the other. Leave natural scrolling on and let Flipper reverse the mouse,
which gives the same result.

### Does it work with a Magic Mouse?

A Magic Mouse scrolls smoothly, the way a trackpad does, so Flipper treats it as
one. Use **Flip: Trackpad** for it.

### Does it work with Logitech and other third party mice?

Yes. Any mouse with a wheel that scrolls in steps counts as a mouse, wired or
Bluetooth, with or without the maker's own software. Some mice with free-spinning
or high resolution wheels send smooth scrolls, and those count as a trackpad.

### Why does Flipper need Accessibility?

Changing another app's input events is something macOS only allows for apps you've
approved under Accessibility. Flipper only reads and rewrites scroll events. It
doesn't look at keystrokes, clicks or anything else, and it never connects to the
internet.

### What about remote desktop apps?

Remote desktop apps such as RustDesk, Screen Sharing and VNC clients inject their
own scroll events, which macOS's natural scrolling setting doesn't touch, so
scrolling through them usually feels right already. Flipper does reverse injected
events, so you may want it off on a Mac you only use remotely.

### How is this different from Scroll Reverser, Mos, LinearMouse or UnnaturalScrollWheels?

They all solve the same problem, and they're good apps. Flipper does less on
purpose: it only reverses scroll direction, with no smoothing, acceleration or
button remapping, so there's very little to trust or keep up to date.

### How do I uninstall Flipper?

Quit it, switch it off in Open at Login, and drag it from Applications to the
Trash. The release zip also has `uninstall.sh`, which does all of that and resets
its Accessibility access. Add `--delete-settings` to remove its preferences too.

## License

MIT, see [LICENSE](LICENSE) and [NOTICE](NOTICE). This is a personal project and
isn't connected to any employer.

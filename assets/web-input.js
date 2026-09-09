// Byte Eater — keyboard bridge.
// kof.ui key events cannot carry key identity yet (alpha platform: Event
// exposes only type()), so physical arrows/WASD are translated into clicks
// on the on-screen d-pad buttons the game already listens to.
// This file is injected into the built index.html (see the Makefile).
(function () {
  var LEFT = '\u25C0';   // ◀
  var RIGHT = '\u25B6';  // ▶
  var UP = '\u25B2';     // ▲
  var DOWN = '\u25BC';   // ▼

  var byKey = {
    ArrowLeft: LEFT, KeyA: LEFT,
    ArrowRight: RIGHT, KeyD: RIGHT,
    ArrowUp: UP, KeyW: UP,
    ArrowDown: DOWN, KeyS: DOWN
  };

  function press(glyph) {
    var btns = document.querySelectorAll('#kof-root button');
    for (var i = 0; i < btns.length; i++) {
      var t = (btns[i].textContent || '').trim();
      if (t === glyph) {
        btns[i].click();
        return true;
      }
    }
    return false;
  }

  window.addEventListener('keydown', function (e) {
    var code = e.code || e.key;
    var glyph = byKey[code];
    if (!glyph) {
      return;
    }
    if (press(glyph)) {
      e.preventDefault();
    }
  }, true);
})();

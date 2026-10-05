const { ipcMain, clipboard } = require('electron')

const CLEAR_AFTER_MS = 30_000

let clearTimer = null

function registerClipboardHandlers() {
  ipcMain.handle('clipboard:copy', (_e, text) => {
    clipboard.writeText(text)

    if (clearTimer) clearTimeout(clearTimer)
    clearTimer = setTimeout(() => {
      // Only clear if our text is still on the clipboard
      if (clipboard.readText() === text) {
        clipboard.writeText('')
      }
      clearTimer = null
    }, CLEAR_AFTER_MS)

    return { ok: true, clearsIn: CLEAR_AFTER_MS }
  })
}

module.exports = { registerClipboardHandlers }

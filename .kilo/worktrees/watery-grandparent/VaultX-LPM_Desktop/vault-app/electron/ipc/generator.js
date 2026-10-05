const { ipcMain } = require('electron')
const { generatePassword } = require('../../crypto/vault-crypto')

function registerGeneratorHandlers() {
  ipcMain.handle('password:generate', (_e, opts) => {
    const password = generatePassword(opts?.length ?? 20, opts)
    return { password }
  })
}

module.exports = { registerGeneratorHandlers }

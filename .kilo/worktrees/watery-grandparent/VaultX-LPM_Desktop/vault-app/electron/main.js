const { app, BrowserWindow, shell } = require('electron')
const path = require('path')
const { initDb } = require('../db/schema')
const { registerVaultHandlers, clearSession } = require('./ipc/vault')
const { registerClipboardHandlers } = require('./ipc/clipboard')
const { registerGeneratorHandlers } = require('./ipc/generator')

const isDev = process.env.NODE_ENV === 'development' || !app.isPackaged

let mainWindow

async function createWindow() {
  await initDb(app)

  mainWindow = new BrowserWindow({
    width: 960,
    height: 680,
    minWidth: 720,
    minHeight: 520,
    titleBarStyle: 'hiddenInset',
    backgroundColor: '#FAFAF8',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false, // needed for argon2 native module
    },
  })

  if (isDev) {
    mainWindow.loadURL('http://localhost:5173')
    mainWindow.webContents.openDevTools({ mode: 'detach' })
  } else {
    mainWindow.loadFile(path.join(__dirname, '../dist/index.html'))
  }

  // Open external links in default browser, not Electron
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url)
    return { action: 'deny' }
  })

  registerVaultHandlers(mainWindow)
  registerClipboardHandlers()
  registerGeneratorHandlers()
}

app.whenReady().then(createWindow)

app.on('window-all-closed', () => {
  clearSession()
  if (process.platform !== 'darwin') app.quit()
})

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow()
})

app.on('before-quit', () => {
  clearSession()
})

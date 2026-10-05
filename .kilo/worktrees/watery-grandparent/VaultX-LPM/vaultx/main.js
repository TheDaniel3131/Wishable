const { app, BrowserWindow, ipcMain, dialog, clipboard, shell } = require('electron');
const path = require('path');
const fs = require('fs');

let win;

function createWindow() {
  win = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 900,
    minHeight: 600,
    title: 'VaultX',
    backgroundColor: '#0a0a0f',
    titleBarStyle: process.platform === 'darwin' ? 'hiddenInset' : 'default',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    icon: path.join(__dirname, 'assets', 'icon.png'),
  });

  win.loadFile('src/index.html');

  // Remove menu bar on Windows/Linux
  if (process.platform !== 'darwin') win.setMenuBarVisibility(false);
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });

// ── IPC Handlers ──────────────────────────────

// Copy to clipboard
ipcMain.handle('clipboard-write', (_, text) => {
  clipboard.writeText(text);
  return true;
});

// Save encrypted vault file to disk
ipcMain.handle('save-file', async (_, { defaultPath, content }) => {
  const { filePath, canceled } = await dialog.showSaveDialog(win, {
    defaultPath,
    filters: [
      { name: 'VaultX Encrypted', extensions: ['vaultx'] },
      { name: 'CSV', extensions: ['csv'] },
      { name: 'JSON', extensions: ['json'] },
    ],
  });
  if (canceled || !filePath) return { success: false };
  fs.writeFileSync(filePath, content, 'utf8');
  return { success: true, filePath };
});

// Open file picker and read file
ipcMain.handle('open-file', async () => {
  const { filePaths, canceled } = await dialog.showOpenDialog(win, {
    filters: [
      { name: 'Vault / Import Files', extensions: ['vaultx', 'csv', 'json'] },
    ],
    properties: ['openFile'],
  });
  if (canceled || !filePaths.length) return null;
  const filePath = filePaths[0];
  const content = fs.readFileSync(filePath, 'utf8');
  return { filePath, content, ext: path.extname(filePath).slice(1) };
});

// Read/write local vault storage (replaces localStorage for file mode)
const VAULT_PATH = path.join(app.getPath('userData'), 'vault.vaultx');

ipcMain.handle('vault-read', () => {
  if (!fs.existsSync(VAULT_PATH)) return null;
  return fs.readFileSync(VAULT_PATH, 'utf8');
});

ipcMain.handle('vault-write', (_, data) => {
  fs.writeFileSync(VAULT_PATH, data, 'utf8');
  return true;
});

ipcMain.handle('vault-exists', () => fs.existsSync(VAULT_PATH));

ipcMain.handle('vault-delete', () => {
  if (fs.existsSync(VAULT_PATH)) fs.unlinkSync(VAULT_PATH);
  return true;
});

ipcMain.handle('open-url', (_, url) => {
  shell.openExternal(url);
});

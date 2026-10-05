const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('vaultAPI', {
  clipboardWrite: (text) => ipcRenderer.invoke('clipboard-write', text),
  saveFile: (opts) => ipcRenderer.invoke('save-file', opts),
  openFile: () => ipcRenderer.invoke('open-file'),
  vaultRead: () => ipcRenderer.invoke('vault-read'),
  vaultWrite: (data) => ipcRenderer.invoke('vault-write', data),
  vaultExists: () => ipcRenderer.invoke('vault-exists'),
  vaultDelete: () => ipcRenderer.invoke('vault-delete'),
  openUrl: (url) => ipcRenderer.invoke('open-url', url),
});

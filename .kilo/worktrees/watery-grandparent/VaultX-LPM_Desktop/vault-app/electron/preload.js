const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('vault', {
  status:   ()           => ipcRenderer.invoke('vault:status'),
  create:   (password)   => ipcRenderer.invoke('vault:create', password),
  unlock:   (password)   => ipcRenderer.invoke('vault:unlock', password),
  lock:     ()           => ipcRenderer.invoke('vault:lock'),
  list:     ()           => ipcRenderer.invoke('vault:list'),
  save:     (credential) => ipcRenderer.invoke('vault:save', credential),
  delete:   (id)         => ipcRenderer.invoke('vault:delete', id),
  onLocked: (cb)         => ipcRenderer.on('vault:locked', cb),
})

contextBridge.exposeInMainWorld('clipboard', {
  copy: (text) => ipcRenderer.invoke('clipboard:copy', text),
})

contextBridge.exposeInMainWorld('generator', {
  generate: (opts) => ipcRenderer.invoke('password:generate', opts),
})

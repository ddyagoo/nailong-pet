const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('desktopDragStart', () => ipcRenderer.send('pet:dragStart'));
contextBridge.exposeInMainWorld('desktopDragEnd', () => ipcRenderer.send('pet:dragEnd'));
contextBridge.exposeInMainWorld('desktopReserveBubble', (visible) =>
  ipcRenderer.send('pet:reserve', !!visible),
);
contextBridge.exposeInMainWorld('desktopMenu', () => ipcRenderer.send('pet:menu'));

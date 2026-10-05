document.addEventListener('DOMContentLoaded', async () => {
    const startBtn = document.getElementById('startBtn');
    const stopBtn = document.getElementById('stopBtn');
    const minutesInput = document.getElementById('minutes');
    const statusEl = document.getElementById('status');
  
    // Get current tab
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    const alarmName = `refresh_tab_${tab.id}`;
  
    // Check if alarm already exists for this tab
    const alarm = await chrome.alarms.get(alarmName);
    if (alarm) {
      statusEl.textContent = 'Active: Refreshing this tab...';
      statusEl.style.color = '#03dac6'; // Teal accent
    }
  
    startBtn.addEventListener('click', async () => {
      const minutes = parseFloat(minutesInput.value);
      if (minutes > 0) {
        // Send message to background worker to start the alarm
        chrome.runtime.sendMessage({
          action: 'start',
          tabId: tab.id,
          minutes: minutes
        });
        statusEl.textContent = `Active: Refreshing every ${minutes} min`;
        statusEl.style.color = '#03dac6';
      }
    });
  
    stopBtn.addEventListener('click', () => {
      chrome.runtime.sendMessage({
          action: 'stop',
          tabId: tab.id
      });
      statusEl.textContent = 'Inactive';
      statusEl.style.color = '#aaaaaa';
    });
  });
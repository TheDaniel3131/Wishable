document.addEventListener('DOMContentLoaded', async () => {
  const startBtn = document.getElementById('startBtn');
  const stopBtn = document.getElementById('stopBtn');
  const resetBtn = document.getElementById('resetBtn');
  const minutesInput = document.getElementById('minutes');
  const statusEl = document.getElementById('status');
  const statusContainer = document.querySelector('.status-container');

  // Saved refresh interval minutes from localStorage (previous value)
  const savedMinutes = localStorage.getItem('refreshIntervalMinutes');
  if (savedMinutes) {
    minutesInput.value = savedMinutes;
  }

  // Get current tab
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  const alarmName = `refresh_tab_${tab.id}`;

  // Check if alarm already exists for this ta
  const alarm = await chrome.alarms.get(alarmName);
  if (alarm) {
    const activeMinutes = alarm.periodInMinutes || savedMinutes || 1;
    minutesInput.value = activeMinutes;
    statusEl.textContent = `Refreshing every ${activeMinutes} min`;
    statusContainer.classList.add('is-active');
  }

  startBtn.addEventListener('click', async () => {
    const minutes = parseFloat(minutesInput.value);
    if (minutes > 0) {
      localStorage.setItem('refreshIntervalMinutes', minutes);
      
      // Send message to background worker to start the alarm
      chrome.runtime.sendMessage({
        action: 'start',
        tabId: tab.id,
        minutes: minutes
      });
      
      statusEl.textContent = `Refreshing every ${minutes} min`;
      statusContainer.classList.add('is-active');
    }
  });

  stopBtn.addEventListener('click', () => {
    chrome.runtime.sendMessage({
        action: 'stop',
        tabId: tab.id
    });
    statusEl.textContent = 'Inactive';
    statusContainer.classList.remove('is-active');
  });

  // 4. The New Reset Logic
  resetBtn.addEventListener('click', () => {
    // Stop the active timer
    chrome.runtime.sendMessage({
        action: 'stop',
        tabId: tab.id
    });
    
    // Wipe memory and reset to default
    localStorage.removeItem('refreshIntervalMinutes');
    minutesInput.value = 1;
    
    // Update UI
    statusEl.textContent = 'Inactive';
    statusContainer.classList.remove('is-active');
  });
});
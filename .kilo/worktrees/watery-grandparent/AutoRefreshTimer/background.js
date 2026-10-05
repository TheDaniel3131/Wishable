chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    const alarmName = `refresh_tab_${message.tabId}`;
    
    if (message.action === 'start') {
        // Create an alarm specifically for this tab ID
        chrome.alarms.create(alarmName, {
            periodInMinutes: message.minutes
        });
    } else if (message.action === 'stop') {
        chrome.alarms.clear(alarmName);
    }
});

// Listen for the alarm to trigger
chrome.alarms.onAlarm.addListener((alarm) => {
    if (alarm.name.startsWith('refresh_tab_')) {
        // Extract the tab ID from the alarm name
        const tabId = parseInt(alarm.name.replace('refresh_tab_', ''), 10);
        
        // Execute a reload script on that specific tab
        chrome.scripting.executeScript({
            target: { tabId: tabId },
            func: () => {
                window.location.reload();
            }
        }).catch(err => {
            // If the tab was closed, clear its alarm to clean up
            chrome.alarms.clear(alarm.name);
            console.log("Tab no longer exists, clearing alarm.");
        });
    }
});
const http = require('http');
const fs = require('fs');
const path = require('path');
const WebSocket = require('ws');

const PORT = process.env.PORT || 3000;

// Serve HTML
const server = http.createServer((req, res) => {
    if (req.url === '/') {
        fs.readFile(path.join(__dirname, 'public', 'index.html'), (err, content) => {
            if (err) res.writeHead(500);
            else {
                res.writeHead(200, { 'Content-Type': 'text/html' });
                res.end(content);
            }
        });
    } else {
        res.writeHead(404);
        res.end();
    }
});

const wss = new WebSocket.Server({ server });

// State: The Shopping Cart
let cart = [];

function broadcast() {
    const data = JSON.stringify({ type: 'sync', cart: cart });
    wss.clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(data);
        }
    });
}

wss.on('connection', (ws) => {
    // Send current cart to new user
    broadcast();

    ws.on('message', (message) => {
        const data = JSON.parse(message);

        if (data.type === 'add') {
            // Add item with quantity
            cart.push({
                id: Date.now(),
                name: data.name,
                qty: data.qty || 1,
                bought: false
            });
            broadcast();
        } 
        else if (data.type === 'toggle') {
            // Mark as bought
            const item = cart.find(i => i.id === data.id);
            if (item) {
                item.bought = !item.bought;
                broadcast();
            }
        }
        else if (data.type === 'delete') {
            // Remove item
            cart = cart.filter(i => i.id !== data.id);
            broadcast();
        }
        else if (data.type === 'clear') {
            // Clear bought items
            cart = cart.filter(i => !i.bought);
            broadcast();
        }
    });
});

server.listen(PORT, () => {
    console.log(`Live Cart running on port ${PORT}`);
});
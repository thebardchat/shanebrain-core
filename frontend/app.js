/* =============================================================================
   SHANEBRAIN CYBERPUNK UI - Application Logic
   ============================================================================= */

// Configuration
const CONFIG = {
    ollamaUrl: 'http://localhost:11434',
    weaviateUrl: 'http://localhost:8080',
    model: 'llama3.2:1b',
    systemPrompt: `You are ShaneBrain - Shane Brazelton's personal AI assistant.
Be direct, no fluff. Lead with solutions. Keep responses short and actionable.
Never say "Certainly!" or "I'd be happy to help!" - just help.`
};

// State
let currentMode = 'chat';
let conversationHistory = [];
let startTime = Date.now();

// =============================================================================
// INITIALIZATION
// =============================================================================

document.addEventListener('DOMContentLoaded', () => {
    initializeUI();
    checkConnections();
    loadKnowledgeBase();
    startClock();
    updateUptime();
    setInterval(updateUptime, 1000);
});

function initializeUI() {
    // Set init time
    document.getElementById('init-time').textContent = formatTime(new Date());

    // Mode buttons
    document.querySelectorAll('.mode-btn').forEach(btn => {
        btn.addEventListener('click', () => setMode(btn.dataset.mode));
    });

    // Auto-resize textarea
    const input = document.getElementById('user-input');
    input.addEventListener('input', () => {
        input.style.height = 'auto';
        input.style.height = Math.min(input.scrollHeight, 150) + 'px';
    });
}

function setMode(mode) {
    currentMode = mode;
    document.querySelectorAll('.mode-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.mode === mode);
    });
    addSystemMessage(`Mode switched to: ${mode.toUpperCase()}`);
}

// =============================================================================
// CONNECTION CHECKS
// =============================================================================

async function checkConnections() {
    // Check Ollama
    try {
        const resp = await fetch(`${CONFIG.ollamaUrl}/api/tags`);
        const data = await resp.json();
        const models = data.models?.map(m => m.name) || [];
        document.getElementById('model-name').textContent = models[0] || CONFIG.model;
    } catch (e) {
        console.error('Ollama connection failed:', e);
    }

    // Check Weaviate
    try {
        const resp = await fetch(`${CONFIG.weaviateUrl}/v1/.well-known/ready`);
        const statusDot = document.getElementById('weaviate-status');
        if (resp.ok) {
            statusDot.classList.add('online');
            statusDot.classList.remove('offline');
        } else {
            statusDot.classList.add('offline');
            statusDot.classList.remove('online');
        }
    } catch (e) {
        console.error('Weaviate connection failed:', e);
        document.getElementById('weaviate-status').classList.add('offline');
    }
}

async function checkHealth() {
    addSystemMessage('Running system diagnostics...');

    const checks = [
        { name: 'Ollama LLM', url: `${CONFIG.ollamaUrl}/api/tags` },
        { name: 'Weaviate DB', url: `${CONFIG.weaviateUrl}/v1/.well-known/ready` }
    ];

    let results = [];
    for (const check of checks) {
        try {
            const resp = await fetch(check.url);
            results.push(`[OK] ${check.name}: Online`);
        } catch (e) {
            results.push(`[X] ${check.name}: Offline`);
        }
    }

    addSystemMessage('SYSTEM STATUS:\n' + results.join('\n'));
}

// =============================================================================
// KNOWLEDGE BASE
// =============================================================================

async function loadKnowledgeBase() {
    try {
        const resp = await fetch(`${CONFIG.weaviateUrl}/v1/objects?class=LegacyKnowledge&limit=50`);
        const data = await resp.json();

        const list = document.getElementById('knowledge-list');
        const count = data.objects?.length || 0;
        document.getElementById('knowledge-count').textContent = `${count} chunks`;

        list.innerHTML = '';
        (data.objects || []).forEach(obj => {
            const item = document.createElement('div');
            item.className = 'knowledge-item';
            item.textContent = obj.properties?.title || 'Untitled';
            item.onclick = () => querySpecificKnowledge(obj.properties?.title);
            list.appendChild(item);
        });
    } catch (e) {
        console.error('Failed to load knowledge base:', e);
        document.getElementById('knowledge-count').textContent = 'Error';
    }
}

async function queryKnowledge() {
    const query = prompt('Search knowledge base:');
    if (!query) return;

    addUserMessage(`/search ${query}`);
    addThinkingMessage();

    try {
        // Search Weaviate using GraphQL
        const graphqlQuery = {
            query: `{
                Get {
                    LegacyKnowledge(
                        nearText: { concepts: ["${query}"] }
                        limit: 3
                    ) {
                        title
                        content
                        category
                    }
                }
            }`
        };

        const resp = await fetch(`${CONFIG.weaviateUrl}/v1/graphql`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(graphqlQuery)
        });

        const data = await resp.json();
        removeThinkingMessage();

        const results = data.data?.Get?.LegacyKnowledge || [];
        if (results.length > 0) {
            let response = `Found ${results.length} relevant entries:\n\n`;
            results.forEach((r, i) => {
                response += `**${i + 1}. ${r.title}**\n${r.content?.substring(0, 200)}...\n\n`;
            });
            addAIMessage(response);
        } else {
            addAIMessage('No matching knowledge found.');
        }
    } catch (e) {
        removeThinkingMessage();
        addAIMessage('Knowledge search failed: ' + e.message);
    }
}

async function querySpecificKnowledge(title) {
    addUserMessage(`Tell me about: ${title}`);
    await sendToOllama(`Based on the ShaneBrain knowledge base, explain: ${title}`);
}

// =============================================================================
// CHAT FUNCTIONALITY
// =============================================================================

function handleKeyPress(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault();
        sendMessage();
    }
}

async function sendMessage() {
    const input = document.getElementById('user-input');
    const message = input.value.trim();

    if (!message) return;

    input.value = '';
    input.style.height = 'auto';

    addUserMessage(message);

    // Check for commands
    if (message.startsWith('/')) {
        handleCommand(message);
        return;
    }

    await sendToOllama(message);
}

function handleCommand(message) {
    const [cmd, ...args] = message.split(' ');

    switch (cmd.toLowerCase()) {
        case '/clear':
            clearChat();
            break;
        case '/search':
            queryKnowledge();
            break;
        case '/health':
            checkHealth();
            break;
        case '/mode':
            if (args[0]) setMode(args[0]);
            break;
        case '/help':
            addSystemMessage(`Available commands:
/clear - Clear chat history
/search - Search knowledge base
/health - Check system status
/mode [chat|memory|wellness] - Switch mode
/help - Show this help`);
            break;
        default:
            addSystemMessage(`Unknown command: ${cmd}`);
    }
}

async function sendToOllama(message) {
    addThinkingMessage();

    // Build context from knowledge base if in memory mode
    let context = '';
    if (currentMode === 'memory') {
        context = await getRelevantContext(message);
    }

    const fullPrompt = context
        ? `Context from knowledge base:\n${context}\n\nUser question: ${message}`
        : message;

    try {
        const resp = await fetch(`${CONFIG.ollamaUrl}/api/generate`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                model: CONFIG.model,
                prompt: fullPrompt,
                system: CONFIG.systemPrompt,
                stream: false
            })
        });

        const data = await resp.json();
        removeThinkingMessage();

        if (data.response) {
            addAIMessage(data.response);
            conversationHistory.push({ role: 'user', content: message });
            conversationHistory.push({ role: 'assistant', content: data.response });
        } else {
            addAIMessage('No response received from model.');
        }
    } catch (e) {
        removeThinkingMessage();
        addAIMessage('Connection error: ' + e.message);
    }
}

async function getRelevantContext(query) {
    try {
        const graphqlQuery = {
            query: `{
                Get {
                    LegacyKnowledge(
                        nearText: { concepts: ["${query}"] }
                        limit: 2
                    ) {
                        title
                        content
                    }
                }
            }`
        };

        const resp = await fetch(`${CONFIG.weaviateUrl}/v1/graphql`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(graphqlQuery)
        });

        const data = await resp.json();
        const results = data.data?.Get?.LegacyKnowledge || [];

        return results.map(r => `${r.title}:\n${r.content}`).join('\n\n');
    } catch (e) {
        console.error('Context retrieval failed:', e);
        return '';
    }
}

// =============================================================================
// MESSAGE HANDLING
// =============================================================================

function addUserMessage(content) {
    addMessage(content, 'user-message', 'USER');
}

function addAIMessage(content) {
    addMessage(content, 'ai-message', 'SHANEBRAIN');
}

function addSystemMessage(content) {
    addMessage(content, 'system-message', 'SYSTEM');
}

function addMessage(content, className, sender) {
    const chatWindow = document.getElementById('chat-window');

    const msg = document.createElement('div');
    msg.className = `message ${className}`;

    msg.innerHTML = `
        <div class="message-header">
            <span class="sender">${sender}</span>
            <span class="timestamp">${formatTime(new Date())}</span>
        </div>
        <div class="message-content">
            ${formatContent(content)}
        </div>
    `;

    chatWindow.appendChild(msg);
    chatWindow.scrollTop = chatWindow.scrollHeight;
}

function addThinkingMessage() {
    const chatWindow = document.getElementById('chat-window');

    const msg = document.createElement('div');
    msg.className = 'message ai-message thinking-message';
    msg.innerHTML = `
        <div class="message-header">
            <span class="sender">SHANEBRAIN</span>
            <span class="timestamp">${formatTime(new Date())}</span>
        </div>
        <div class="message-content">
            <span class="loading">Processing</span>
        </div>
    `;

    chatWindow.appendChild(msg);
    chatWindow.scrollTop = chatWindow.scrollHeight;
}

function removeThinkingMessage() {
    const thinking = document.querySelector('.thinking-message');
    if (thinking) thinking.remove();
}

function formatContent(content) {
    // Convert markdown-style formatting
    return content
        .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
        .replace(/`(.*?)`/g, '<code>$1</code>')
        .replace(/```([\s\S]*?)```/g, '<pre><code>$1</code></pre>')
        .replace(/\n/g, '<br>');
}

function clearChat() {
    const chatWindow = document.getElementById('chat-window');
    chatWindow.innerHTML = '';
    conversationHistory = [];
    addSystemMessage('Chat cleared. Neural link reset.');
}

// =============================================================================
// UTILITIES
// =============================================================================

function formatTime(date) {
    return date.toLocaleTimeString('en-US', {
        hour12: false,
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    });
}

function startClock() {
    const updateClock = () => {
        document.getElementById('current-time').textContent = formatTime(new Date());
    };
    updateClock();
    setInterval(updateClock, 1000);
}

function updateUptime() {
    const elapsed = Date.now() - startTime;
    const hours = Math.floor(elapsed / 3600000);
    const minutes = Math.floor((elapsed % 3600000) / 60000);
    const seconds = Math.floor((elapsed % 60000) / 1000);

    document.getElementById('uptime').textContent =
        `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}

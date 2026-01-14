/* =============================================================================
   SHANEBRAIN CYBERPUNK UI - Application Logic
   ============================================================================= */

// Configuration - Dynamic URLs based on current host
const currentHost = window.location.hostname; // Works for localhost AND Tailscale IP
const CONFIG = {
    ollamaUrl: `http://${currentHost}:11434`,
    weaviateUrl: `http://${currentHost}:8080`,
    model: 'llama3.2:1b',
    systemPrompt: `You are ShaneBrain - Shane Brazelton's personal AI assistant.
Be direct, no fluff. Lead with solutions. Keep responses short and actionable.
Never say "Certainly!" or "I'd be happy to help!" - just help.`
};

// State
let currentMode = 'chat';
let conversationHistory = [];
let startTime = Date.now();
let sessionId = 'session_' + Date.now();
let userId = 'shane'; // Default user

// =============================================================================
// INITIALIZATION
// =============================================================================

document.addEventListener('DOMContentLoaded', async () => {
    initializeUI();
    checkConnections();
    loadKnowledgeBase();
    await loadRecentConversations(); // Load memory from Weaviate
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
// PERSISTENT MEMORY - Save/Load conversations to Weaviate
// =============================================================================

async function saveConversation(userMessage, aiResponse) {
    try {
        const timestamp = new Date().toISOString();

        const conversationData = {
            class: 'Conversation',
            properties: {
                user_id: userId,
                message: userMessage,
                response: aiResponse,
                timestamp: timestamp,
                project: 'shanebrain',
                mode: currentMode
            }
        };

        await fetch(`${CONFIG.weaviateUrl}/v1/objects`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(conversationData)
        });

        console.log('Conversation saved to memory');
        updateMemoryCount();
    } catch (e) {
        console.error('Failed to save conversation:', e);
    }
}

async function loadRecentConversations() {
    try {
        const graphqlQuery = {
            query: `{
                Get {
                    Conversation(
                        limit: 10
                        sort: [{ path: ["timestamp"], order: desc }]
                    ) {
                        user_id
                        message
                        response
                        timestamp
                        mode
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
        const conversations = data.data?.Get?.Conversation || [];

        if (conversations.length > 0) {
            // Load into local history (reversed to chronological order)
            conversations.reverse().forEach(conv => {
                conversationHistory.push({ role: 'user', content: conv.message });
                conversationHistory.push({ role: 'assistant', content: conv.response });
            });

            addSystemMessage(`Loaded ${conversations.length} conversations from memory.`);
        }

        updateMemoryCount();
    } catch (e) {
        console.error('Failed to load conversations:', e);
    }
}

async function updateMemoryCount() {
    try {
        const resp = await fetch(`${CONFIG.weaviateUrl}/v1/objects?class=Conversation&limit=1`);
        const data = await resp.json();
        // Note: This is approximate, for exact count we'd need aggregate query
        const countResp = await fetch(`${CONFIG.weaviateUrl}/v1/graphql`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                query: `{ Aggregate { Conversation { meta { count } } } }`
            })
        });
        const countData = await countResp.json();
        const count = countData.data?.Aggregate?.Conversation?.[0]?.meta?.count || 0;

        // Update UI to show memory count
        const knowledgeCount = document.getElementById('knowledge-count');
        if (knowledgeCount) {
            const existing = knowledgeCount.textContent;
            knowledgeCount.textContent = existing.split('+')[0] + ` + ${count} memories`;
        }
    } catch (e) {
        console.error('Failed to get memory count:', e);
    }
}

async function getConversationContext() {
    // Get recent conversation history for context
    const recentHistory = conversationHistory.slice(-10); // Last 5 exchanges
    if (recentHistory.length === 0) return '';

    let context = 'Recent conversation history:\n';
    for (let i = 0; i < recentHistory.length; i += 2) {
        const user = recentHistory[i];
        const ai = recentHistory[i + 1];
        if (user && ai) {
            context += `User: ${user.content}\nShaneBrain: ${ai.content}\n\n`;
        }
    }
    return context;
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

    // Build context from multiple sources
    let knowledgeContext = '';
    let conversationContext = '';

    // Always include recent conversation context for continuity
    conversationContext = await getConversationContext();

    // Add knowledge base context if in memory mode
    if (currentMode === 'memory') {
        knowledgeContext = await getRelevantContext(message);
    }

    // Build the full prompt with all context
    let fullPrompt = message;
    if (conversationContext || knowledgeContext) {
        fullPrompt = '';
        if (conversationContext) {
            fullPrompt += `${conversationContext}\n`;
        }
        if (knowledgeContext) {
            fullPrompt += `Relevant knowledge:\n${knowledgeContext}\n\n`;
        }
        fullPrompt += `Current question: ${message}`;
    }

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

            // Update local history
            conversationHistory.push({ role: 'user', content: message });
            conversationHistory.push({ role: 'assistant', content: data.response });

            // SAVE TO WEAVIATE - Persistent memory!
            await saveConversation(message, data.response);
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

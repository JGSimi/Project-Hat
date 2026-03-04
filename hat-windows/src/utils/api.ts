export type InferenceMode = 'local' | 'api';
export type CloudProvider = 'google' | 'openai' | 'anthropic' | 'custom';

export type ChatTurn = {
    role: string;   // "user" or "assistant"
    content: string;
};

// Mocks the SettingsManager behavior from the Swift code
export const SettingsManager = {
    get inferenceMode(): InferenceMode { return 'local'; },
    get localModelName(): string { return 'gemma3:4b'; },
    get systemPrompt(): string { return 'Responda APENAS com a letra e o texto da alternativa. Sem introduções. Pergunta: '; },
    get selectedProvider(): CloudProvider { return 'google'; },
    get apiEndpoint(): string { return 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions'; },
    get apiModelName(): string { return 'gemini-2.5-flash'; },
    get apiKey(): string { return ''; } // Would be fetched from tauri-plugin-store
};

export async function fetchLocalOllama(
    prompt: string,
    model: string,
    system: string,
    images?: string[],
    history: ChatTurn[] = []
) {
    const messages: Array<{ role: string; content: string; images?: string[] }> = [];

    // System message
    const trimmedSystem = system.trim();
    if (trimmedSystem) {
        messages.push({ role: 'system', content: trimmedSystem });
    }

    // History (text only, no images)
    for (const turn of history) {
        messages.push({ role: turn.role, content: turn.content });
    }

    // Current user message (with images)
    const userMsg: { role: string; content: string; images?: string[] } = {
        role: 'user',
        content: prompt
    };
    if (images && images.length > 0) {
        userMsg.images = images;
    }
    messages.push(userMsg);

    const payload = {
        model,
        messages,
        stream: false,
        options: { temperature: 0.0 }
    };

    const response = await fetch('http://localhost:11434/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
    });

    if (!response.ok) {
        throw new Error(`Local Ollama Erro: ${response.status}`);
    }

    const data = await response.json();
    return data.message.content.trim();
}

export async function executeAIRequest(
    prompt: string,
    images?: string[],
    history: ChatTurn[] = []
): Promise<string> {
    const mode = SettingsManager.inferenceMode;
    const system = SettingsManager.systemPrompt;

    if (mode === 'local') {
        return fetchLocalOllama(prompt, SettingsManager.localModelName, system, images, history);
    } else {
        // Cloud API logic structure
        return Promise.resolve("Cloud APIs to be connected via tauri-plugin-http.");
    }
}

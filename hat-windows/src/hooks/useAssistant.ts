import { useState, useEffect, useCallback } from 'react';
import { readText, writeText } from '@tauri-apps/plugin-clipboard-manager';
import { register, unregisterAll, isRegistered } from '@tauri-apps/plugin-global-shortcut';
import { sendNotification, isPermissionGranted, requestPermission } from '@tauri-apps/plugin-notification';
import { getCurrentWindow } from '@tauri-apps/api/window';
import { executeAIRequest, ChatTurn } from '../utils/api';

export type Attachment = {
    name: string;
    type: string;
    data: string; // Base64 for images, text content for documents
};

export type ChatMessage = {
    id: string;
    text: string;
    isUser: boolean;
    attachments?: Attachment[];
};

export function useAssistant() {
    const [messages, setMessages] = useState<ChatMessage[]>([]);
    const [isProcessing, setIsProcessing] = useState(false);

    // Mock LLM processor (to be replaced by Ollama/Cloud fetch)
    const processPrompt = async (prompt: string, attachments?: Attachment[]) => {
        setIsProcessing(true);

        // Add User Message
        const userMsg: ChatMessage = { id: Date.now().toString(), text: prompt, isUser: true, attachments };
        setMessages((prev) => [...prev, userMsg]);

        try {
            let response = "";
            
            // Separar anexos
            let finalPrompt = prompt;
            const imagesBase64: string[] = [];
            
            if (attachments) {
                for (const att of attachments) {
                    if (att.type.startsWith("image/")) {
                        // O Ollama espera apenas a base64 sem o prefixo data:image/...;base64,
                        const base64Data = att.data.split(',')[1] || att.data;
                        imagesBase64.push(base64Data);
                    } else {
                        // Para documentos e texto
                        finalPrompt += `\n\n[Arquivo: ${att.name}]\n${att.data}`;
                    }
                }
            }

            // Build history from current messages (before the new user message was added via setState)
            // React state updates are async, so `messages` here is the state BEFORE the new userMsg
            const history: ChatTurn[] = messages.map(msg => ({
                role: msg.isUser ? 'user' : 'assistant',
                content: msg.text
            }));

            try {
                response = await executeAIRequest(finalPrompt, imagesBase64, history);
            } catch (err) {
                console.warn("Local API returned error, returning fallback simulate.", err);
                // Fallback simulate to show the UI works even without local ollama running
                await new Promise(resolve => setTimeout(resolve, 1500));
                response = `[Win-Resposta] Você enviou: "${prompt}".\nErro ao bater no Ollama. Verifique se ele está rodando na porta 11434.`;
            }

            const assistantMsg: ChatMessage = { id: (Date.now() + 1).toString(), text: response, isUser: false };
            setMessages((prev) => [...prev, assistantMsg]);

            // Copy to clipboard
            await writeText(response);

            // Notify
            let permissionGranted = await isPermissionGranted();
            if (!permissionGranted) {
                const permission = await requestPermission();
                permissionGranted = permission === 'granted';
            }
            if (permissionGranted) {
                sendNotification({ title: 'Hat', body: response });
            }

        } catch (e) {
            console.error(e);
            setMessages((prev) => [...prev, { id: Date.now().toString(), text: "Ocorreu um erro no processamento.", isUser: false }]);
        } finally {
            setIsProcessing(false);
        }
    };

    const processClipboard = useCallback(async () => {
        try {
            if (isProcessing) return;
            const text = await readText();
            if (!text || text.trim() === "") return;

            const appWindow = getCurrentWindow();
            await appWindow.show();
            await appWindow.setFocus();

            await processPrompt(text);
        } catch (e) {
            console.error("Failed to read clipboard", e);
        }
    }, [isProcessing]);

    useEffect(() => {
        const setupShortcut = async () => {
            try {
                await unregisterAll();
                // Equivalent to Mac Cmd+Shift+X is Ctrl+Shift+X or Alt+Shift+X inside Tauri
                const shortcutString = 'CommandOrControl+Shift+X';
                const alreadyRegistered = await isRegistered(shortcutString);

                if (!alreadyRegistered) {
                    await register(shortcutString, (event) => {
                        if (event.state === "Pressed") {
                            processClipboard();
                        }
                    });
                }
            } catch (err) {
                console.error("Failed to register shortcut", err);
            }
        };

        setupShortcut();

        return () => {
            unregisterAll().catch(console.error);
        };
    }, [processClipboard]);

    return {
        messages,
        setMessages,
        processPrompt,
        isProcessing,
    };
}

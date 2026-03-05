import { useState, useRef, useEffect } from "react";
import { MessageSquare, Settings, Trash2, ArrowUp, ImageIcon, X, Loader2, FileIcon, XCircle, SunDim } from "lucide-react";
import { useAssistant, Attachment } from "./hooks/useAssistant";
import { useOpacity } from "./hooks/useOpacity";
import "./App.css";

// TBD: Models and API integrations

export default function App() {
  const [showSettings, setShowSettings] = useState(false);
  const [showOpacity, setShowOpacity] = useState(false);
  const [inputText, setInputText] = useState("");
  const [pendingAttachments, setPendingAttachments] = useState<File[]>([]);
  const { messages, setMessages, processPrompt, isProcessing } = useAssistant();
  const { opacity, setOpacity } = useOpacity();
  const scrollRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const opacityRef = useRef<HTMLDivElement>(null);
  const opacityBtnRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages]);

  useEffect(() => {
    if (!showOpacity) return;
    const handler = (e: MouseEvent) => {
      if (
        opacityRef.current && !opacityRef.current.contains(e.target as Node) &&
        opacityBtnRef.current && !opacityBtnRef.current.contains(e.target as Node)
      ) {
        setShowOpacity(false);
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, [showOpacity]);

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      setPendingAttachments((prev) => [...prev, ...Array.from(e.target.files!)]);
    }
  };

  const removeAttachment = (index: number) => {
    setPendingAttachments((prev) => prev.filter((_, i) => i !== index));
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    if (e.dataTransfer.files) {
      setPendingAttachments((prev) => [...prev, ...Array.from(e.dataTransfer.files)]);
    }
  };

  const readFileAsDataURL = (file: File): Promise<string> => {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result as string);
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
  };

  const readFileAsText = (file: File): Promise<string> => {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result as string);
      reader.onerror = reject;
      reader.readAsText(file);
    });
  };

  const handleSend = async () => {
    const text = inputText;
    if ((!text.trim() && pendingAttachments.length === 0) || isProcessing) return;
    
    setInputText("");
    const filesToProcess = [...pendingAttachments];
    setPendingAttachments([]);

    const attachments: Attachment[] = [];
    for (const file of filesToProcess) {
      if (file.type.startsWith("image/")) {
        const data = await readFileAsDataURL(file);
        attachments.push({ name: file.name, type: file.type, data });
      } else {
        const data = await readFileAsText(file);
        attachments.push({ name: file.name, type: file.type, data });
      }
    }

    await processPrompt(text, attachments);
  };

  return (
    <div className="app-container">
      <div className={`chat-view ${showSettings ? "hidden" : ""}`} onDragOver={handleDragOver} onDrop={handleDrop}>
        {/* Header */}
        <header className="header" data-tauri-drag-region>
          <div className="header-title">
            <MessageSquare size={18} />
            <span>Chat</span>
          </div>
          <div className="header-actions">
            <button onClick={() => setMessages([])} title="Limpar histórico">
              <Trash2 size={18} />
            </button>
            <button
              ref={opacityBtnRef}
              onClick={() => setShowOpacity(!showOpacity)}
              title="Opacidade"
              className={`icon-btn ${showOpacity ? "active-toggle" : ""}`}
            >
              <SunDim size={18} />
            </button>
            <button onClick={() => setShowSettings(true)} title="Configurações">
              <Settings size={18} />
            </button>
          </div>
        </header>

        {showOpacity && (
          <div className="opacity-popover" ref={opacityRef}>
            <input
              type="range"
              min="0.15"
              max="1"
              step="0.01"
              value={opacity}
              onChange={(e) => setOpacity(parseFloat(e.target.value))}
              className="opacity-slider"
            />
          </div>
        )}

        {/* Chat List */}
        <div className="chat-list" ref={scrollRef}>
          {messages.length === 0 ? (
            <div className="empty-state">
              <div className="empty-state-icon">
                <MessageSquare size={32} strokeWidth={1.2} />
              </div>
              <span className="empty-state-title">Hat</span>
              <span className="empty-state-subtitle">Envie uma mensagem para começar.</span>
            </div>
          ) : (
            messages.map((m) => (
              <div key={m.id} className={`chat-bubble-container ${m.isUser ? "user" : "assistant"}`}>
                <div className={`chat-bubble ${m.isUser ? "user-bubble" : "assistant-bubble"}`}>
                  {m.attachments && m.attachments.length > 0 && (
                    <div className="message-attachments">
                      {m.attachments.map((att, i) => (
                        att.type.startsWith("image/") ? (
                          <img key={i} src={att.data} alt={att.name} className="message-img-attachment" />
                        ) : (
                          <div key={i} className="message-file-attachment">
                            <FileIcon size={14} />
                            <span>{att.name}</span>
                          </div>
                        )
                      ))}
                    </div>
                  )}
                  {m.text}
                </div>
              </div>
            ))
          )}
        </div>

        {/* Footer */}
        <footer className="footer-container">
          {pendingAttachments.length > 0 && (
            <div className="pending-attachments">
              {pendingAttachments.map((file, i) => (
                <div key={i} className="pending-attachment-item">
                  {file.type.startsWith("image/") ? (
                     <ImageIcon size={16} />
                  ) : (
                     <FileIcon size={16} />
                  )}
                  <span className="attachment-name">{file.name}</span>
                  <button className="remove-att-btn" onClick={() => removeAttachment(i)}>
                    <XCircle size={14} />
                  </button>
                </div>
              ))}
            </div>
          )}
          <div className="footer">
            <input 
              type="file" 
              multiple 
              ref={fileInputRef} 
              style={{ display: 'none' }} 
              onChange={handleFileSelect} 
            />
            <button className="icon-btn" title="Anexar arquivo" onClick={() => fileInputRef.current?.click()}>
              <ImageIcon size={20} />
            </button>
            <div className="input-wrapper">
              <textarea
                placeholder="Envie uma mensagem..."
                value={inputText}
                onChange={(e) => setInputText(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    handleSend();
                  }
                }}
                rows={1}
              />
            </div>
            <button
              className={`send-btn ${(inputText.trim() || pendingAttachments.length > 0) && !isProcessing ? "active" : ""}`}
              onClick={handleSend}
              disabled={(!inputText.trim() && pendingAttachments.length === 0) || isProcessing}
            >
              {isProcessing ? <Loader2 size={18} className="spin" /> : <ArrowUp size={18} />}
            </button>
          </div>
        </footer>
      </div>

      {showSettings && (
        <div className="settings-view">
          <header className="header" data-tauri-drag-region>
            <div className="header-title">
              <Settings size={18} />
              <span>Configurações</span>
            </div>
            <button className="icon-btn" style={{ padding: 0 }} onClick={() => setShowSettings(false)}>
              <X size={20} />
            </button>
          </header>
          <div className="settings-content" style={{ padding: 20 }}>
            <h3 style={{ marginTop: 0 }}>Configurações (Em Breve)</h3>
            <p className="placeholder-text" style={{ color: 'var(--text-muted)', fontSize: 14 }}>
              Em breve: Modelos cloud vs Local (Ollama), System Prompts.
            </p>
          </div>
        </div>
      )}
    </div>
  );
}

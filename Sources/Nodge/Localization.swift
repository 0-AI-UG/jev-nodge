import Foundation

enum UIStringKey: Int, CaseIterable {
    case assistantLanguage, languageSubtitle, voiceActivation, microphoneOff, wakeActive
    case voiceShortcut, shortcutSubtitle, connectOpenRouter, connectSubtitle
    case shortcutOnly, wakePhrase, continueButton, startButton, back
    case previousLanguage, nextLanguage, wakeName, chooseWakeName, addOpenRouterKey
    case enableWakePhrase, disableWakePhrase, startVoiceInput, setup
    case enableAccessibility, editCommands, openLog, quit
    case goAhead, wakePhraseOn, pressToSpeak, listening, working, cancelled, error
}

extension AssistantLanguage {
    func text(_ key: UIStringKey) -> String {
        let values: [String]
        switch self {
        case .english:
            values = [
                "Assistant language", "Used for listening and spoken answers.", "Voice activation",
                "The microphone stays off until you press the shortcut.", "Wake phrase keeps the microphone active.",
                "Voice shortcut", "Tap Fn alone, or record a key combination.", "Connect OpenRouter",
                "Your key stays in Keychain. The local voice downloads once after setup.",
                "Shortcut only", "Wake phrase", "Continue", "Start", "Back", "Previous language", "Next language",
                "Wake name", "Choose a wake name", "Add an OpenRouter API key", "Enable wake phrase",
                "Disable wake phrase", "Start voice input", "Setup…", "Enable Accessibility…", "Edit commands…",
                "Open log", "Quit Jev Nodge", "Go ahead, I’m listening", "Wake phrase is on", "Press %@ to speak",
                "Listening…", "Working…", "Cancelled", "Error",
            ]
        case .german:
            values = [
                "Assistentensprache", "Für Zuhören und gesprochene Antworten.", "Sprachaktivierung",
                "Das Mikrofon bleibt aus, bis du das Kürzel drückst.", "Das Aktivierungswort hält das Mikrofon aktiv.",
                "Sprachkürzel", "Drücke nur Fn oder zeichne eine Tastenkombination auf.", "OpenRouter verbinden",
                "Dein Schlüssel bleibt im Schlüsselbund. Die lokale Stimme wird einmalig geladen.",
                "Nur Kürzel", "Aktivierungswort", "Weiter", "Starten", "Zurück", "Vorherige Sprache", "Nächste Sprache",
                "Aktivierungsname", "Wähle einen Aktivierungsnamen", "OpenRouter-API-Schlüssel hinzufügen", "Aktivierungswort einschalten",
                "Aktivierungswort ausschalten", "Spracheingabe starten", "Einrichtung…", "Bedienungshilfen aktivieren…", "Befehle bearbeiten…",
                "Protokoll öffnen", "Jev Nodge beenden", "Ich höre zu", "Aktivierungswort ist an", "Drücke %@ zum Sprechen",
                "Höre zu…", "Arbeite…", "Abgebrochen", "Fehler",
            ]
        case .russian:
            values = [
                "Язык ассистента", "Для распознавания и голосовых ответов.", "Голосовая активация",
                "Микрофон выключен, пока вы не нажмёте сочетание.", "Ключевая фраза оставляет микрофон активным.",
                "Голосовое сочетание", "Нажмите только Fn или запишите сочетание клавиш.", "Подключение OpenRouter",
                "Ключ хранится в Связке ключей. Локальный голос загрузится один раз.",
                "Только сочетание", "Ключевая фраза", "Продолжить", "Начать", "Назад", "Предыдущий язык", "Следующий язык",
                "Имя активации", "Выберите имя активации", "Добавьте API-ключ OpenRouter", "Включить ключевую фразу",
                "Выключить ключевую фразу", "Начать голосовой ввод", "Настройка…", "Включить Универсальный доступ…", "Изменить команды…",
                "Открыть журнал", "Выйти из Jev Nodge", "Я слушаю", "Ключевая фраза включена", "Нажмите %@, чтобы говорить",
                "Слушаю…", "Выполняю…", "Отменено", "Ошибка",
            ]
        case .spanish:
            values = [
                "Idioma del asistente", "Se usa para escuchar y responder por voz.", "Activación por voz",
                "El micrófono permanece apagado hasta que pulses el atajo.", "La frase de activación mantiene el micrófono activo.",
                "Atajo de voz", "Pulsa solo Fn o graba una combinación de teclas.", "Conectar OpenRouter",
                "Tu clave queda en el Llavero. La voz local se descarga una vez.",
                "Solo atajo", "Frase de activación", "Continuar", "Iniciar", "Atrás", "Idioma anterior", "Idioma siguiente",
                "Nombre de activación", "Elige un nombre de activación", "Añade una clave API de OpenRouter", "Activar frase de activación",
                "Desactivar frase de activación", "Iniciar entrada de voz", "Configuración…", "Activar Accesibilidad…", "Editar comandos…",
                "Abrir registro", "Salir de Jev Nodge", "Adelante, te escucho", "La frase de activación está activa", "Pulsa %@ para hablar",
                "Escuchando…", "Trabajando…", "Cancelado", "Error",
            ]
        case .french:
            values = [
                "Langue de l’assistant", "Utilisée pour l’écoute et les réponses vocales.", "Activation vocale",
                "Le micro reste coupé jusqu’à l’appui sur le raccourci.", "La phrase d’activation garde le micro actif.",
                "Raccourci vocal", "Appuyez sur Fn seul ou enregistrez une combinaison.", "Connecter OpenRouter",
                "Votre clé reste dans le Trousseau. La voix locale est téléchargée une fois.",
                "Raccourci seul", "Phrase d’activation", "Continuer", "Démarrer", "Retour", "Langue précédente", "Langue suivante",
                "Nom d’activation", "Choisissez un nom d’activation", "Ajoutez une clé API OpenRouter", "Activer la phrase d’activation",
                "Désactiver la phrase d’activation", "Démarrer la saisie vocale", "Configuration…", "Activer Accessibilité…", "Modifier les commandes…",
                "Ouvrir le journal", "Quitter Jev Nodge", "Je vous écoute", "La phrase d’activation est active", "Appuyez sur %@ pour parler",
                "Écoute…", "Traitement…", "Annulé", "Erreur",
            ]
        case .italian:
            values = [
                "Lingua dell’assistente", "Usata per l’ascolto e le risposte vocali.", "Attivazione vocale",
                "Il microfono resta spento finché non premi la scorciatoia.", "La frase di attivazione mantiene il microfono attivo.",
                "Scorciatoia vocale", "Premi solo Fn o registra una combinazione di tasti.", "Connetti OpenRouter",
                "La chiave resta nel Portachiavi. La voce locale viene scaricata una sola volta.",
                "Solo scorciatoia", "Frase di attivazione", "Continua", "Avvia", "Indietro", "Lingua precedente", "Lingua successiva",
                "Nome di attivazione", "Scegli un nome di attivazione", "Aggiungi una chiave API OpenRouter", "Attiva frase di attivazione",
                "Disattiva frase di attivazione", "Avvia input vocale", "Configurazione…", "Attiva Accessibilità…", "Modifica comandi…",
                "Apri registro", "Esci da Jev Nodge", "Ti ascolto", "La frase di attivazione è attiva", "Premi %@ per parlare",
                "In ascolto…", "Elaborazione…", "Annullato", "Errore",
            ]
        case .portuguese:
            values = [
                "Idioma do assistente", "Usado para ouvir e responder por voz.", "Ativação por voz",
                "O microfone fica desligado até você pressionar o atalho.", "A frase de ativação mantém o microfone ativo.",
                "Atalho de voz", "Pressione apenas Fn ou grave uma combinação de teclas.", "Conectar OpenRouter",
                "Sua chave fica nas Chaves. A voz local é baixada uma vez.",
                "Somente atalho", "Frase de ativação", "Continuar", "Iniciar", "Voltar", "Idioma anterior", "Próximo idioma",
                "Nome de ativação", "Escolha um nome de ativação", "Adicione uma chave de API OpenRouter", "Ativar frase de ativação",
                "Desativar frase de ativação", "Iniciar entrada de voz", "Configuração…", "Ativar Acessibilidade…", "Editar comandos…",
                "Abrir registro", "Sair do Jev Nodge", "Pode falar, estou ouvindo", "A frase de ativação está ativa", "Pressione %@ para falar",
                "Ouvindo…", "Processando…", "Cancelado", "Erro",
            ]
        case .chinese:
            values = [
                "助理语言", "用于语音识别和语音回答。", "语音激活",
                "按下快捷键前，麦克风会保持关闭。", "唤醒词会让麦克风保持开启。",
                "语音快捷键", "单独按 Fn，或录制一个组合键。", "连接 OpenRouter",
                "密钥保存在钥匙串中。本地语音只需下载一次。",
                "仅快捷键", "唤醒词", "继续", "开始", "返回", "上一种语言", "下一种语言",
                "唤醒名称", "选择唤醒名称", "添加 OpenRouter API 密钥", "启用唤醒词",
                "停用唤醒词", "开始语音输入", "设置…", "启用辅助功能…", "编辑命令…",
                "打开日志", "退出 Jev Nodge", "请说，我在听", "唤醒词已开启", "按 %@ 说话",
                "正在听…", "处理中…", "已取消", "错误",
            ]
        case .japanese:
            values = [
                "アシスタントの言語", "音声認識と音声回答に使用します。", "音声起動",
                "ショートカットを押すまでマイクはオフです。", "ウェイクフレーズ使用中はマイクが有効です。",
                "音声ショートカット", "Fn のみを押すか、キーの組み合わせを登録します。", "OpenRouter に接続",
                "キーはキーチェーンに保存されます。ローカル音声は一度だけダウンロードされます。",
                "ショートカットのみ", "ウェイクフレーズ", "続ける", "開始", "戻る", "前の言語", "次の言語",
                "起動名", "起動名を選択", "OpenRouter API キーを追加", "ウェイクフレーズを有効化",
                "ウェイクフレーズを無効化", "音声入力を開始", "設定…", "アクセシビリティを有効化…", "コマンドを編集…",
                "ログを開く", "Jev Nodge を終了", "どうぞ、聞いています", "ウェイクフレーズはオンです", "%@ を押して話す",
                "聞いています…", "処理中…", "キャンセル済み", "エラー",
            ]
        }
        return values[key.rawValue]
    }

    func text(_ key: UIStringKey, _ argument: String) -> String {
        String(format: text(key), argument)
    }
}

{
    "ai": {
        "extraModels": [
            {
                "api_format": "openai",
                "description": "This is a custom model. Edit the config to add more! | Anyway, this is DeepSeek R1 Distill LLaMA 70B",
                "endpoint": "https://openrouter.ai/api/v1/chat/completions",
                "homepage": "https://openrouter.ai/deepseek/deepseek-r1-distill-llama-70b:free",
                "icon": "spark-symbolic",
                "key_get_link": "https://openrouter.ai/settings/keys",
                "key_id": "openrouter",
                "model": "deepseek/deepseek-r1-distill-llama-70b:free",
                "name": "Custom: DS R1 Dstl. LLaMA 70B",
                "requires_key": true
            }
        ],
        "systemPrompt": "## Style\n- Use casual tone, don't be formal! Make sure you answer precisely without hallucination and prefer bullet points over walls of text. You can have a friendly greeting at the beginning of the conversation, but don't repeat the user's question\n\n## Context (ignore when irrelevant)\n- You are a helpful and inspiring sidebar assistant on a AxOS Linux system\n- Desktop environment: Sleex\n- Current date & time: {DATETIME}\n- Focused app: {WINDOWCLASS}\n\n## Presentation\n- Use Markdown features in your response: \n  - **Bold** text to **highlight keywords** in your response\n  - **Split long information into small sections** with h2 headers and a relevant emoji at the start of it (for example `## 🐧 Linux`). Bullet points are preferred over long paragraphs, unless you're offering writing support or instructed otherwise by the user.\n- Asked to compare different options? You should firstly use a table to compare the main aspects, then elaborate or include relevant comments from online forums *after* the table. Make sure to provide a final recommendation for the user's use case!\n- Use LaTeX formatting for mathematical and scientific notations whenever appropriate. Enclose all LaTeX '$$' delimiters. NEVER generate LaTeX code in a latex block unless the user explicitly asks for it. DO NOT use LaTeX for regular documents (resumes, letters, essays, CVs, etc.).\n",
        "tool": "functions"
    },
    "appearance": {
        "opacity": 50,
        "palette": {
            "type": "auto"
        },
        "shellScale": "1",
        "transparency": true
    },
    "apps": {
        "bluetooth": "qs -p /usr/share/sleex/settings.qml",
        "imageViewer": "loupe",
        "network": "qs -p /usr/share/sleex/settings.qml",
        "networkEthernet": "qs -p /usr/share/sleex/settings.qml",
        "settings": "qs -p /usr/share/sleex/settings.qml",
        "taskManager": "missioncenter",
        "terminal": "foot"
    },
    "audio": {
        "protection": {
            "enable": true,
            "maxAllowed": 100,
            "maxAllowedIncrease": 10
        }
    },
    "background": {
        "clockFontFamily": "Rubik",
        "clockMode": "light",
        "clockSizeMultiplier": 1.3,
        "clockX": 657.84765625,
        "clockY": 565.67578125,
        "enableClock": false,
        "enableQuote": false,
        "fixedClockPosition": false,
        "showWatermark": false,
        "wallpaperPath": "/usr/share/sleex/wallpapers//SleexOne.png",
        "wallpaperSelectorPath": "/usr/share/sleex/wallpapers/"
    },
    "bar": {
        "background": false,
        "borderless": false,
        "bottom": false,
        "screenList": [
        ],
        "showClock": true,
        "showRessources": false,
        "showTitle": false,
        "showTrayAndIcons": true,
        "showWorkspaces": true,
        "tray": {
            "invertPinnedItems": true,
            "monochromeIcons": true,
            "pinnedItems": [
            ],
            "showItemId": false
        },
        "verbose": true,
        "workspaces": {
            "alwaysShowNumbers": false,
            "showAppIcons": true,
            "showNumberDelay": 300,
            "shown": 5
        }
    },
    "battery": {
        "critical": 5,
        "low": 20,
        "sound": true,
        "suspend": 2
    },
    "dashboard": {
        "avatarPath": "file:///usr/share/sleex/assets/logo/1024px/white.png",
        "calendar": {
            "syncInterval": 15,
            "useVdirsyncer": false
        },
        "dasboardScale": "0.67",
        "enableWeather": true,
        "ghUsername": "Abscissa24",
        "mediaPlayer": "spotify",
        "opt": {
            "enableAIAssistant": false,
            "enableCalendar": true,
            "enableTodo": true
        },
        "userDesc": "",
        "weatherLocation": "Port-Shepstone"
    },
    "display": {
        "nightLightAuto": true,
        "nightLightEnabled": true,
        "nightLightFrom": "19:00",
        "nightLightTemperature": 2792,
        "nightLightTo": "06:30"
    },
    "dock": {
        "enabled": false,
        "height": 60,
        "hoverRegionHeight": 3,
        "hoverToReveal": false,
        "pinnedApps": [
            "pcmanfm-qt",
            "foot",
            "firefox"
        ],
        "pinnedOnStartup": false
    },
    "hacks": {
        "arbitraryRaceConditionDelay": 20
    },
    "interactions": {
        "scrolling": {
            "fasterTouchpadScroll": true,
            "mouseScrollDeltaThreshold": 120,
            "mouseScrollFactor": 120,
            "touchpadScrollFactor": 50
        }
    },
    "networking": {
        "userAgent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
    },
    "osd": {
        "timeout": 1000
    },
    "overview": {
        "numOfCols": 5,
        "numOfRows": 2,
        "scale": 0.18,
        "showXwaylandIndicator": true
    },
    "policies": {
        "ai": 2
    },
    "resources": {
        "updateInterval": 3000
    },
    "search": {
        "engineBaseUrl": "https://www.google.com/search?q=",
        "excludedSites": [
            "quora.com"
        ],
        "nonAppResultDelay": 30,
        "prefix": {
            "action": "/",
            "clipboard": ";",
            "emojis": ":"
        },
        "sloppy": false
    },
    "time": {
        "dateFormat": "dddd, dd/MM",
        "firstDayOfWeek": 0,
        "format": "hh:mm",
        "longDateFormat": "dd/MM/yyyy"
    },
    "timeout": {
        "illuminance": 10000,
        "lock": 15000,
        "standby": 10000,
        "suspend": 15000
    },
    "windows": {
        "centerTitle": true,
        "showTitlebar": true
    }
}

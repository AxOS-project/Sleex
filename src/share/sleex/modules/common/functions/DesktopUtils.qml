pragma Singleton
import Quickshell

Singleton {
    id: root

    function getIconName(fileName, isDir) {
        if (isDir) return "folder"
        let ext = fileName.includes('.') ? fileName.split('.').pop().toLowerCase() : ""
        
        const map = {
            // Images
            "png": "image-x-generic", "jpg": "image-x-generic", "jpeg": "image-x-generic", "svg": "image-svg+xml", 
            "gif": "image-x-generic", "bmp": "image-x-generic", "webp": "image-x-generic", "ico": "image-x-generic", 
            "tiff": "image-x-generic", "tif": "image-x-generic", "heic": "image-x-generic", "heif": "image-x-generic", 
            "raw": "image-x-generic", "psd": "image-vnd.adobe.photoshop", "ai": "application-illustrator", "xcf": "image-x-xcf",

            // Vidéos
            "mp4": "video-x-generic", "mkv": "video-x-generic", "webm": "video-x-generic", "avi": "video-x-generic", 
            "mov": "video-x-generic", "flv": "video-x-generic", "wmv": "video-x-generic", "m4v": "video-x-generic", 
            "mpg": "video-x-generic", "mpeg": "video-x-generic", "3gp": "video-x-generic", "vob": "video-x-generic",
            "ogv": "video-x-generic", "ts": "video-x-generic",

            // Audio
            "mp3": "audio-x-generic", "wav": "audio-x-generic", "flac": "audio-x-generic", "aac": "audio-x-generic", 
            "ogg": "audio-x-generic", "m4a": "audio-x-generic", "wma": "audio-x-generic", "opus": "audio-x-generic", 
            "alac": "audio-x-generic", "mid": "audio-midi", "midi": "audio-midi", "amr": "audio-x-generic",

            // Archives & Images
            "zip": "application-zip", "tar": "application-x-tar", "gz": "application-gzip", "rar": "application-vnd.rar", 
            "7z": "application-x-7z-compressed", "xz": "application-x-xz", "bz2": "application-x-bzip2", "tgz": "application-x-compressed-tar", 
            "iso": "application-x-cd-image", "img": "application-x-cd-image", "dmg": "application-x-apple-diskimage",
            "deb": "application-vnd.debian.binary-package", "rpm": "application-x-rpm", "apk": "application-vnd.android.package-archive",

            // Documents
            "pdf": "application-pdf", "doc": "application-msword", "docx": "application-vnd.openxmlformats-officedocument.wordprocessingml.document", 
            "xls": "application-vnd.ms-excel", "xlsx": "application-vnd.openxmlformats-officedocument.spreadsheetml.sheet", 
            "ppt": "application-vnd.ms-powerpoint", "pptx": "application-vnd.openxmlformats-officedocument.presentationml.presentation", 
            "odt": "application-vnd.oasis.opendocument.text", "ods": "application-vnd.oasis.opendocument.spreadsheet", 
            "odp": "application-vnd.oasis.opendocument.presentation", "rtf": "application-rtf", "epub": "application-epub+zip", 
            "mobi": "application-x-mobipocket-ebook", "djvu": "image-vnd.djvu", "csv": "text-csv", "tsv": "text-tab-separated-values",

            // Data & Config
            "txt": "text-x-generic", "md": "text-markdown", "rst": "text-x-rst", "tex": "text-x-tex", "log": "text-x-log",
            "json": "application-json", "xml": "text-xml", "yaml": "text-x-yaml", "yml": "text-x-yaml", "toml": "text-x-toml", 
            "ini": "text-x-generic", "conf": "text-x-generic", "cfg": "text-x-generic", "env": "text-x-generic",

            // Code
            "qml": "text-x-qml", "cpp": "text-x-c++src", "c": "text-x-csrc", "h": "text-x-chdr", "hpp": "text-x-c++hdr", 
            "py": "text-x-python", "js": "text-x-javascript", "ts": "text-x-typescript", "jsx": "text-x-javascript", "tsx": "text-x-typescript",
            "java": "text-x-java", "rs": "text-x-rust", "go": "text-x-go", "rb": "text-x-ruby", "php": "application-x-php", 
            "cs": "text-x-csharp", "swift": "text-x-swift", "kt": "text-x-kotlin", "sh": "application-x-shellscript", 
            "bash": "application-x-shellscript", "zsh": "application-x-shellscript", "fish": "application-x-shellscript",
            "html": "text-html", "htm": "text-html", "css": "text-css", "scss": "text-x-scss", "sass": "text-x-sass", "less": "text-x-less",
            "vue": "text-html", "svelte": "text-html", "sql": "application-x-sql", "graphql": "text-x-generic", "lua": "text-x-lua", 
            "pl": "text-x-perl", "dart": "text-x-dart", "r": "text-x-r", "dockerfile": "text-x-generic", "make": "text-x-makefile",

            // Executables
            "exe": "application-x-executable", "msi": "application-x-msi", "bat": "application-x-ms-dos-executable",
            "cmd": "application-x-ms-dos-executable", "appimage": "application-x-executable", "run": "application-x-executable",
            "bin": "application-x-executable", "out": "application-x-executable", "so": "application-x-sharedlib", 
            "dll": "application-x-sharedlib",

            // Fonts
            "ttf": "font-x-generic", "otf": "font-x-generic", "woff": "font-x-generic", "woff2": "font-x-generic"
        }
        return map[ext] || "text-x-generic"
    }

    function getFileType(fileName, isDir) {
        if (isDir) return "directory"
        let ext = fileName.includes('.') ? fileName.split('.').pop().toLowerCase() : ""
        if (ext === "desktop") return "desktop"

        const map = {
            "image": [
                "png", "jpg", "jpeg", "svg", "gif", "bmp", "webp", "ico", "tiff", "tif", 
                "heic", "heif", "raw", "psd", "ai", "xcf"
            ],
            "video": [
                "mp4", "mkv", "webm", "avi", "mov", "flv", "wmv", "m4v", "mpg", "mpeg", 
                "3gp", "vob", "ogv", "ts"
            ],
            "audio": [
                "mp3", "wav", "flac", "aac", "ogg", "m4a", "wma", "opus", "alac", "mid", 
                "midi", "amr"
            ],
            "archive": [
                "zip", "tar", "gz", "rar", "7z", "xz", "bz2", "tgz", "iso", "img", 
                "dmg", "deb", "rpm", "apk"
            ],
            "document": [
                "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "odt", "ods", "odp", 
                "rtf", "epub", "mobi", "djvu"
            ],
            "text": [
                "txt", "md", "rst", "tex", "log", "json", "xml", "yaml", "yml", "toml", 
                "ini", "conf", "cfg", "env", "csv", "tsv"
            ],
            "code": [
                "qml", "cpp", "c", "h", "hpp", "py", "js", "ts", "jsx", "tsx", "java", 
                "rs", "go", "rb", "php", "cs", "swift", "kt", "sh", "bash", "zsh", "fish", 
                "html", "htm", "css", "scss", "sass", "less", "vue", "svelte", "sql", 
                "graphql", "lua", "pl", "dart", "r", "dockerfile", "make"
            ],
            "executable": [
                "exe", "msi", "bat", "cmd", "appimage", "run", "bin", "out", "so", "dll"
            ],
            "font": [
                "ttf", "otf", "woff", "woff2"
            ]
        }

        for (const [type, extensions] of Object.entries(map)) {
            if (extensions.includes(ext)) return type;
        }
        return "unknown"
    }

    function getAppId(fileName) {
        return fileName.endsWith(".desktop") ? fileName.replace(".desktop", "") : null
    }
}
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Serialize, Deserialize, Default, Clone)]
pub struct Config {
    pub yandex_token: String,
    #[serde(default)]
    pub soundcloud_client_id: String,
    #[serde(default)]
    pub discord_client_id: String,
    #[serde(default)]
    pub lastfm_api_key: String,
    #[serde(default)]
    pub liked_shuffle: bool,
    #[serde(default)]
    pub last_update_check: u64,
    /// Where yt-dlp should get YouTube cookies from: either a browser name
    /// (`chromium`, `firefox`, `edge`, ...) read directly with
    /// `--cookies-from-browser`, or a path to a Netscape `cookies.txt` file.
    /// When empty, `<config>/cookies.txt` is used if it exists.
    #[serde(default)]
    pub ytdlp_cookies: String,
}

pub const DEFAULT_DISCORD_CLIENT_ID: &str = "1409612809859366932";

/// Epoch seconds (0 if unavailable).
pub fn now_secs() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

fn config_dir() -> PathBuf {
    crate::paths::config_dir()
}

fn config_file() -> PathBuf {
    config_dir().join("config.json")
}

pub fn load() -> Config {
    let path = config_file();
    match std::fs::read_to_string(&path) {
        // Editors on Windows like to add a UTF-8 BOM; `serde_json` rejects it
        // and the player would fall back to defaults, wiping every setting on
        // the next save.
        Ok(text) => serde_json::from_str(text.trim_start_matches('\u{feff}')).unwrap_or_default(),
        Err(_) => Config::default(),
    }
}

pub fn save(config: &Config) {
    let dir = config_dir();
    let _ = std::fs::create_dir_all(&dir);
    let path = config_file();
    if let Ok(text) = serde_json::to_string_pretty(config) {
        let _ = std::fs::write(&path, text);
    }
}

/// The default place users are told to put their cookies file.
pub fn default_cookies_file() -> PathBuf {
    config_dir().join("cookies.txt")
}

/// Browsers `yt-dlp --cookies-from-browser` knows about.
pub const COOKIE_BROWSERS: &[&str] = &[
    "brave", "chrome", "chromium", "edge", "firefox", "opera", "safari", "vivaldi", "whale",
];

/// Where yt-dlp should read YouTube cookies from.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CookieSource {
    /// Let yt-dlp read the cookies straight from a browser profile. The value is
    /// passed to `--cookies-from-browser` unchanged, so `chromium`,
    /// `firefox:ProfileName` and `chrome+gnomekeyring` all work.
    Browser(String),
    /// A Netscape `cookies.txt` file, passed with `--cookies`.
    File(PathBuf),
}

/// True when the value looks like a `--cookies-from-browser` argument rather
/// than a file path: a known browser, optionally with `+keyring` and/or
/// `:profile`. Windows paths (`C:\...`) never match because the drive letter is
/// not a browser name.
pub fn is_cookie_browser(value: &str) -> bool {
    let value = value.trim();
    if value.is_empty() {
        return false;
    }
    let base = value
        .split([':', '+'])
        .next()
        .unwrap_or("")
        .trim()
        .to_ascii_lowercase();
    COOKIE_BROWSERS.contains(&base.as_str())
}

/// Cookies yt-dlp should use, if any.
///
/// `ytdlp_cookies` wins: a browser name enables `--cookies-from-browser`, an
/// existing file enables `--cookies`. When it is empty or points at a missing
/// file, `<config>/cookies.txt` is picked up automatically.
pub fn cookie_source() -> Option<CookieSource> {
    let cfg = load();
    let configured = cfg.ytdlp_cookies.trim();
    if !configured.is_empty() {
        if is_cookie_browser(configured) {
            return Some(CookieSource::Browser(configured.to_string()));
        }
        let path = expand_home(configured);
        if path.is_file() {
            return Some(CookieSource::File(path));
        }
    }
    let fallback = default_cookies_file();
    if fallback.is_file() {
        return Some(CookieSource::File(fallback));
    }
    None
}

/// The cookies file used by yt-dlp, when one is configured.
pub fn cookies_file() -> Option<PathBuf> {
    match cookie_source() {
        Some(CookieSource::File(path)) => Some(path),
        _ => None,
    }
}

/// Expand a leading `~`/`~user`-style home marker. Windows users normally pass
/// absolute paths, but `~/...` is handy in config.json and on Unix.
fn expand_home(value: &str) -> PathBuf {
    if let Some(rest) = value.strip_prefix("~/").or_else(|| value.strip_prefix("~\\")) {
        return crate::paths::home_dir().join(rest);
    }
    PathBuf::from(value)
}

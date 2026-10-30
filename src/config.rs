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
    /// Optional path to a Netscape `cookies.txt` file for yt-dlp. Needed for
    /// age-restricted YouTube tracks. When empty, `<config>/cookies.txt` is
    /// used if it exists.
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
        Ok(text) => serde_json::from_str(&text).unwrap_or_default(),
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

/// The cookies file used for yt-dlp, if one is available.
///
/// `ytdlp_cookies` wins when it points at an existing file; otherwise
/// `<config>/cookies.txt` is picked up automatically, so dropping the file
/// next to `config.json` is enough to enable it.
pub fn cookies_file() -> Option<PathBuf> {
    let cfg = load();
    let configured = cfg.ytdlp_cookies.trim();
    if !configured.is_empty() {
        let path = expand_home(configured);
        if path.is_file() {
            return Some(path);
        }
    }
    let fallback = default_cookies_file();
    if fallback.is_file() {
        return Some(fallback);
    }
    None
}

/// Expand a leading `~`/`~user`-style home marker. Windows users normally pass
/// absolute paths, but `~/...` is handy in config.json and on Unix.
fn expand_home(value: &str) -> PathBuf {
    if let Some(rest) = value.strip_prefix("~/").or_else(|| value.strip_prefix("~\\")) {
        return crate::paths::home_dir().join(rest);
    }
    PathBuf::from(value)
}

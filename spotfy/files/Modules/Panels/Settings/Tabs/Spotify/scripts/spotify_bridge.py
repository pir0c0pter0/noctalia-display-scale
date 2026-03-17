#!/usr/bin/env python3
"""Spotify bridge for Noctalia Shell. Receives commands via CLI args, returns JSON via stdout."""

import sys
import json
import os
import argparse

CONFIG_DIR = os.path.expanduser("~/.config/noctalia-shell")
CONFIG_FILE = os.path.join(CONFIG_DIR, "spotify_config.json")
TOKEN_FILE = os.path.join(CONFIG_DIR, "spotify_token.json")
REDIRECT_URI = "http://localhost:8888/callback"
SCOPES = (
    "user-read-playback-state "
    "user-modify-playback-state "
    "user-read-currently-playing "
    "playlist-read-private "
    "playlist-read-collaborative "
    "user-library-read"
)


def output(data):
    print(json.dumps(data, ensure_ascii=False))
    sys.exit(0)


def error(code, message):
    output({"status": "error", "code": code, "message": message})


def load_config():
    if not os.path.exists(CONFIG_FILE):
        return None
    with open(CONFIG_FILE) as f:
        return json.load(f)


def save_config(client_id, client_secret):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(CONFIG_FILE, "w") as f:
        json.dump({"client_id": client_id, "client_secret": client_secret}, f)


def get_spotify_client():
    config = load_config()
    if not config:
        error("not_configured", "Spotify app credentials not configured")
    if not os.path.exists(TOKEN_FILE):
        error("token_expired", "Not authenticated. Run auth first.")
    try:
        import spotipy
        from spotipy.oauth2 import SpotifyOAuth
        auth_manager = SpotifyOAuth(
            client_id=config["client_id"],
            client_secret=config["client_secret"],
            redirect_uri=REDIRECT_URI,
            scope=SCOPES,
            cache_path=TOKEN_FILE,
        )
        token_info = auth_manager.get_cached_token()
        if not token_info:
            error("token_expired", "Token expired. Re-authenticate.")
        if auth_manager.is_token_expired(token_info):
            token_info = auth_manager.refresh_access_token(token_info["refresh_token"])
        sp = spotipy.Spotify(auth_manager=auth_manager)
        return sp
    except Exception as e:
        error("network_error", str(e))


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command")

    setup_p = sub.add_parser("setup")
    setup_p.add_argument("client_id")
    setup_p.add_argument("client_secret")
    sub.add_parser("auth")
    sub.add_parser("logout")
    sub.add_parser("status")
    sub.add_parser("play")
    sub.add_parser("pause")
    sub.add_parser("next")
    sub.add_parser("prev")
    volume_p = sub.add_parser("volume")
    volume_p.add_argument("level", type=int)
    shuffle_p = sub.add_parser("shuffle")
    shuffle_p.add_argument("state", choices=["on", "off"])
    repeat_p = sub.add_parser("repeat")
    repeat_p.add_argument("mode", choices=["off", "track", "context"])
    sub.add_parser("playlists")
    playlist_p = sub.add_parser("playlist")
    playlist_p.add_argument("id")
    pt_p = sub.add_parser("playlist_tracks")
    pt_p.add_argument("id")
    search_p = sub.add_parser("search")
    search_p.add_argument("query", nargs="+")
    queue_p = sub.add_parser("queue")
    queue_p.add_argument("uri")
    sub.add_parser("queue_list")

    args = parser.parse_args()

    if not args.command:
        error("invalid_command", "No command provided")

    if args.command == "setup":
        if not args.client_id or not args.client_secret:
            error("invalid_input", "Client ID and Secret are required")
        save_config(args.client_id, args.client_secret)
        output({"status": "ok"})

    elif args.command == "auth":
        cmd_auth()

    elif args.command == "status":
        cmd_status()

    elif args.command == "play":
        sp = get_spotify_client()
        try:
            sp.start_playback()
            output({"status": "ok"})
        except Exception as e:
            handle_playback_error(e)

    elif args.command == "pause":
        sp = get_spotify_client()
        try:
            sp.pause_playback()
            output({"status": "ok"})
        except Exception as e:
            handle_playback_error(e)

    elif args.command == "next":
        sp = get_spotify_client()
        try:
            sp.next_track()
            output({"status": "ok"})
        except Exception as e:
            handle_playback_error(e)

    elif args.command == "prev":
        sp = get_spotify_client()
        try:
            sp.previous_track()
            output({"status": "ok"})
        except Exception as e:
            handle_playback_error(e)

    elif args.command == "volume":
        sp = get_spotify_client()
        try:
            sp.volume(args.level)
            output({"status": "ok"})
        except Exception as e:
            handle_playback_error(e)

    elif args.command == "shuffle":
        sp = get_spotify_client()
        try:
            sp.shuffle(args.state == "on")
            output({"status": "ok"})
        except Exception as e:
            handle_playback_error(e)

    elif args.command == "repeat":
        sp = get_spotify_client()
        try:
            sp.repeat(args.mode)
            output({"status": "ok"})
        except Exception as e:
            handle_playback_error(e)

    elif args.command == "playlists":
        cmd_playlists()

    elif args.command == "playlist":
        sp = get_spotify_client()
        try:
            sp.start_playback(context_uri=f"spotify:playlist:{args.id}")
            output({"status": "ok"})
        except Exception as e:
            handle_playback_error(e)

    elif args.command == "playlist_tracks":
        cmd_playlist_tracks(args.id)

    elif args.command == "search":
        cmd_search(" ".join(args.query))

    elif args.command == "queue":
        sp = get_spotify_client()
        try:
            sp.add_to_queue(args.uri)
            output({"status": "ok"})
        except Exception as e:
            handle_playback_error(e)

    elif args.command == "queue_list":
        cmd_queue_list()

    elif args.command == "logout":
        # Delete token file to force re-auth
        if os.path.exists(TOKEN_FILE):
            os.remove(TOKEN_FILE)
        output({"status": "ok"})


def handle_playback_error(e):
    msg = str(e)
    if "NO_ACTIVE_DEVICE" in msg or "No active device" in msg:
        error("no_active_device", "No active Spotify device found")
    elif "PREMIUM_REQUIRED" in msg or "Premium required" in msg:
        error("not_premium", "Spotify Premium required for playback control")
    elif "429" in msg:
        error("rate_limited", "Rate limited. Try again shortly.")
    else:
        error("api_error", msg)


def cmd_auth():
    config = load_config()
    if not config:
        error("not_configured", "Run setup first")
    try:
        import spotipy
        from spotipy.oauth2 import SpotifyOAuth
        import threading

        auth_manager = SpotifyOAuth(
            client_id=config["client_id"],
            client_secret=config["client_secret"],
            redirect_uri=REDIRECT_URI,
            scope=SCOPES,
            cache_path=TOKEN_FILE,
            open_browser=True,
        )
        # This blocks until browser callback or timeout
        import signal

        def timeout_handler(signum, frame):
            error("auth_timeout", "Authorization timed out after 120 seconds")

        signal.signal(signal.SIGALRM, timeout_handler)
        signal.alarm(120)

        token_info = auth_manager.get_access_token(as_dict=True)
        signal.alarm(0)

        if token_info:
            sp = spotipy.Spotify(auth_manager=auth_manager)
            user = sp.current_user()
            premium = user.get("product", "free") == "premium"
            output({
                "status": "ok",
                "user": user.get("display_name", "Unknown"),
                "premium": premium,
            })
        else:
            error("auth_failed", "Failed to obtain token")
    except SystemExit:
        raise
    except Exception as e:
        error("auth_failed", str(e))


def cmd_status():
    sp = get_spotify_client()
    try:
        pb = sp.current_playback()
        if not pb or not pb.get("device"):
            output({
                "is_playing": False,
                "no_device": True,
                "track": None,
            })
            return
        track = pb.get("item")
        track_data = None
        if track:
            artists = ", ".join(a["name"] for a in track.get("artists", []))
            album = track.get("album", {})
            images = album.get("images", [])
            art_url = images[0]["url"] if images else ""
            track_data = {
                "name": track.get("name", "Unknown"),
                "artist": artists,
                "album": album.get("name", "Unknown"),
                "album_art_url": art_url,
                "duration_ms": track.get("duration_ms", 0),
                "uri": track.get("uri", ""),
            }
        device = pb.get("device", {})
        output({
            "is_playing": pb.get("is_playing", False),
            "no_device": False,
            "track": track_data,
            "progress_ms": pb.get("progress_ms", 0),
            "volume": device.get("volume_percent", 0),
            "shuffle": pb.get("shuffle_state", False),
            "repeat": pb.get("repeat_state", "off"),
            "device": {
                "name": device.get("name", "Unknown"),
                "type": device.get("type", "Unknown"),
            },
        })
    except Exception as e:
        handle_playback_error(e)


def cmd_playlists():
    sp = get_spotify_client()
    try:
        results = sp.current_user_playlists(limit=50)
        items = []
        for pl in results.get("items", []):
            items.append({
                "id": pl["id"],
                "name": pl["name"],
                "track_count": pl["tracks"]["total"],
            })
        output({"items": items})
    except Exception as e:
        error("api_error", str(e))


def cmd_playlist_tracks(playlist_id):
    sp = get_spotify_client()
    try:
        results = sp.playlist_tracks(playlist_id, limit=100)
        items = []
        for item in results.get("items", []):
            track = item.get("track")
            if not track:
                continue
            artists = ", ".join(a["name"] for a in track.get("artists", []))
            items.append({
                "name": track.get("name", "Unknown"),
                "artist": artists,
                "album": track.get("album", {}).get("name", "Unknown"),
                "duration_ms": track.get("duration_ms", 0),
                "uri": track.get("uri", ""),
            })
        output({"items": items})
    except Exception as e:
        error("api_error", str(e))


def cmd_search(query):
    sp = get_spotify_client()
    try:
        results = sp.search(q=query, limit=15, type="track,artist")
        tracks = []
        for t in results.get("tracks", {}).get("items", []):
            artists = ", ".join(a["name"] for a in t.get("artists", []))
            tracks.append({
                "name": t.get("name", "Unknown"),
                "artist": artists,
                "album": t.get("album", {}).get("name", "Unknown"),
                "uri": t.get("uri", ""),
            })
        artists = []
        for a in results.get("artists", {}).get("items", []):
            artists.append({
                "name": a.get("name", "Unknown"),
                "uri": a.get("uri", ""),
            })
        output({"tracks": tracks, "artists": artists})
    except Exception as e:
        error("api_error", str(e))


def cmd_queue_list():
    sp = get_spotify_client()
    try:
        q = sp.queue()
        items = []
        for t in q.get("queue", [])[:20]:
            artists = ", ".join(a["name"] for a in t.get("artists", []))
            items.append({
                "name": t.get("name", "Unknown"),
                "artist": artists,
                "uri": t.get("uri", ""),
            })
        output({"items": items})
    except Exception as e:
        error("api_error", str(e))


if __name__ == "__main__":
    main()

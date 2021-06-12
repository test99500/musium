// Musium -- Music playback daemon with web-based library browser
// Copyright 2020 Ruud van Asseldonk
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy of the License has been included in the root of the repository.

//! Logging of historical playback events.

use std::path::Path;
use std::sync::mpsc::Receiver;

use crate::{MetaIndex, TrackId};
use crate::player::QueueId;
use crate::database;
use crate::database::{Database, Listen};

/// Changes in the playback state to be recorded.
pub enum PlaybackEvent {
    Started(QueueId, TrackId),
    Completed(QueueId, TrackId),
}

/// Main for the thread that logs historical playback events.
pub fn main(
    db_path: &Path,
    index: &dyn MetaIndex,
    events: Receiver<PlaybackEvent>,
) {
    let connection = sqlite::open(db_path).expect("Failed to open SQLite database.");
    database::ensure_schema_exists(&connection).expect("Failed to create schema in SQLite database.");
    let mut db = Database::new(&connection).expect("Failed to prepare SQLite statements.");

    let mut last_listen_id = None;

    for event in events {
        let now = chrono::Utc::now();
        let use_zulu_suffix = true;
        let now_str = now.to_rfc3339_opts(chrono::SecondsFormat::Millis, use_zulu_suffix);

        match event {
            PlaybackEvent::Started(queue_id, track_id) => {
                let track = index.get_track(track_id).unwrap();
                let album = index.get_album(track.album_id).unwrap();
                let artist = index.get_artist(album.artist_id).unwrap();
                let listen = Listen {
                    started_at: &now_str[..],
                    queue_id: queue_id,
                    track_id: track_id,
                    album_id: track.album_id,
                    album_artist_id: album.artist_id,
                    track_title: index.get_string(track.title),
                    album_title: index.get_string(album.title),
                    track_artist: index.get_string(track.artist),
                    album_artist: index.get_string(artist.name),
                    duration_seconds: track.duration_seconds,
                    track_number: track.track_number,
                    disc_number: track.disc_number,
                };
                let result = db.insert_listen_started(listen);
                last_listen_id = Some(result.expect("Failed to insert listen started event into SQLite database."));
            }
            PlaybackEvent::Completed(queue_id, track_id) => {
                if let Some(listen_id) = last_listen_id {
                    db.update_listen_completed(
                        listen_id,
                        &now_str[..],
                        queue_id,
                        track_id,
                    ).expect(
                        "Failed to insert listen completed event into SQLite database."
                    );
                } else {
                    panic!(
                        "Completed queue entry {}, track {}, before starting.",
                        queue_id, track_id,
                    );
                }
            }
        }
    }
}

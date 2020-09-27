-- Musium -- Music playback daemon with web-based library browser
-- Copyright 2020 Ruud van Asseldonk
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- A copy of the License has been included in the root of the repository.

module Search
  ( SearchElements
  , new
  ) where

import Control.Monad.Reader.Class (ask, local)
import Data.Array as Array
import Data.Foldable (for_)
import Data.String.CodeUnits as CodeUnits
import Effect.Aff (launchAff_)
import Effect.Class (liftEffect)
import Effect.Class.Console as Console
import Prelude

import Dom (Element)
import Html (Html)
import Html as Html
import Model (SearchArtist (..), SearchAlbum (..), SearchTrack (..))
import Model as Model

type SearchElements =
  { searchBox :: Element
  , resultBox :: Element
  }

renderSearchArtist :: SearchArtist -> Html Unit
renderSearchArtist (SearchArtist artist) = do
  Html.li $ do
    Html.addClass "artist"
    Html.div $ do
      Html.addClass "name"
      Html.text artist.name
    Html.div $ do
      Html.addClass "discography"
      for_ artist.albums $ \albumId -> do
        Html.img (Model.thumbUrl albumId) ("An album by " <> artist.name) $ pure unit

-- TODO: Deduplicate between here and album component.
renderSearchAlbum :: SearchAlbum -> Html Unit
renderSearchAlbum (SearchAlbum album) = do
  Html.li $ do
    Html.addClass "album"
    Html.img (Model.thumbUrl album.id) (album.title <> " by " <> album.artist) $ do
      Html.addClass "thumb"
    Html.span $ do
      Html.addClass "title"
      Html.text album.title
    Html.span $ do
      Html.addClass "artist"
      Html.text $ album.artist <> " "
      Html.span $ do
        Html.addClass "date"
        Html.setTitle album.date
        -- The date is of the form YYYY-MM-DD in ascii, so we can safely take
        -- the first 4 characters to get the year.
        Html.text (CodeUnits.take 4 album.date)

renderSearchTrack :: SearchTrack -> Html Unit
renderSearchTrack (SearchTrack track) = do
  Html.li $ do
    Html.addClass "track"
    -- TODO: Turn album rendering into re-usable function.
    Html.img (Model.thumbUrl track.albumId) track.album $ do
      Html.addClass "thumb"
    Html.span $ do
      Html.addClass "title"
      Html.text track.title
    Html.span $ do
      Html.addClass "artist"
      Html.text track.artist

new :: Html SearchElements
new = do
  searchBox <- Html.input "search" $ do
    Html.setId "search-box"
    ask

  resultBox <- Html.div $ do
    Html.setId "search-results"
    ask

  local (const searchBox) $ do
    Html.onInput $ \query -> do
      -- Fire off the search query and render it when it comes in.
      -- TODO: Pass these through the event loop, to ensure that the result
      -- matches the query, and perhaps for caching as well.
      launchAff_ $ do
        Model.SearchResults result <- Model.search query
        Console.log $ "Received artists: " <> (show $ Array.length $ result.artists)
        Console.log $ "Received albums:  " <> (show $ Array.length $ result.albums)
        Console.log $ "Received tracks:  " <> (show $ Array.length $ result.tracks)
        liftEffect $ do
          Html.withElement resultBox $ do
            Html.clear

            when (not $ Array.null result.artists) $ do
              Html.h2 $ Html.text "Artists"
              Html.div $ do
                Html.setId "search-artists"
                Html.ul $ for_ result.artists renderSearchArtist

            when (not $ Array.null result.albums) $ do
              Html.h2 $ Html.text "Albums"
              Html.div $ do
                Html.setId "search-albums"
                Html.ul $ for_ result.albums renderSearchAlbum

            when (not $ Array.null result.tracks) $ do
              Html.h2 $ Html.text "Tracks"
              Html.div $ do
                Html.setId "search-tracks"
                Html.ul $ for_ result.tracks renderSearchTrack

  pure $ { searchBox, resultBox }

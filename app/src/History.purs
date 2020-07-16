-- Mindec -- Music metadata indexer
-- Copyright 2020 Ruud van Asseldonk
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- A copy of the License has been included in the root of the repository.

module History
  ( pushState
  , onPopState
  ) where

import Data.Function.Uncurried (Fn3, runFn3)
import Effect (Effect)
import Prelude

foreign import pushStateImpl :: forall a. Fn3 a String String (Effect Unit)
foreign import onPopState :: forall a. (a -> Effect Unit) -> Effect Unit

-- TODO: Settle on a type; input and output must match, and that is easiest if I
-- just hard-code it.
pushState :: forall a. a -> String -> String -> Effect Unit
pushState state title url = runFn3 pushStateImpl state title url

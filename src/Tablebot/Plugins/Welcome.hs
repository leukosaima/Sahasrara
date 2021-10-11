-- |
-- Module      : Tablebot.Plugins.Welcome
-- Description : A plugin for generating welcome messages.
-- Copyright   : (c) Amelie WD 2021
-- License     : MIT
-- Maintainer  : tablebot@ameliewd.com
-- Stability   : experimental
-- Portability : POSIX
--
-- Commands for generating welcome messages.
module Tablebot.Plugins.Welcome (welcomePlugin) where

import Control.Monad.IO.Class
import Data.Aeson (FromJSON, eitherDecode)
import qualified Data.ByteString.Lazy as B
import Data.Text (Text, pack)
import Data.Yaml (decodeFileEither)
import Data.Yaml.Internal (ParseException)
import GHC.Generics (Generic)
import Tablebot.Plugin
import Tablebot.Plugin.Discord (sendMessage)
import Tablebot.Plugin.SmartCommand
import Tablebot.Util.Error
import Tablebot.Util.Random (chooseOne, chooseOneWeighted)
import Text.Printf
import Text.RawString.QQ

-- | @favourite@ is the user-facing command that generates categories.
favourite :: Command
favourite =
  Command
    "favourite"
    ( parseComm $ \m -> do
        cat <- liftIO $ generateCategory =<< randomCategoryClass
        let formatted = either id id $ (\(i, c) -> i ++ " is your favourite:\n> " ++ c ++ "?") <$> cat
        _ <- sendMessage m $ pack $ formatted
        return ()
    )

favouriteHelp :: HelpPage
favouriteHelp =
  HelpPage
    "favourite"
    "generate a category of things you might have a favourite of"
    [r|**Favourite**
Generate a random category of thing to help inspire welcome messages.

*Usage:* `favourite`|]
    []

data CategoryClass = CategoryClass
  { name :: !String,
    weight :: !(Maybe Int),
    template :: !(Maybe String),
    interrogative :: !(Maybe String),
    values :: ![String]
  }
  deriving (Show, Generic)

data FileData = FileData {classes :: ![CategoryClass]} deriving (Show, Generic)

instance FromJSON CategoryClass

instance FromJSON FileData

yamlFile :: FilePath
yamlFile = "resources/welcome_messages.yaml"

categories :: IO [CategoryClass]
categories = do
  cats <- decodeFileEither yamlFile :: IO (Either ParseException FileData)
  return $ case cats of
    Left err -> []
    Right out -> classes out

randomCategoryClass :: IO (Either Error CategoryClass)
randomCategoryClass = do
  cats <- categories
  chooseOneWeighted getWeight cats
  where
    getWeight c = case weight c of
      Just x -> x
      Nothing -> length $ values c

generateCategory :: Either Error CategoryClass -> IO (Either Error (String, String))
generateCategory (Left err) = return $ Left err
generateCategory (Right catClass) = do
  choice <- chooseOne $ values catClass
  return $ (\x -> (getInterrogative catClass, printf (getTemplate catClass) x)) <$> choice
  where
    getTemplate c = case template c of
      Just x -> x
      Nothing -> "%s"
    getInterrogative c = case interrogative c of
      Just x -> x
      Nothing -> "What"

-- | @welcomePlugin@ assembles these commands into a plugin.
welcomePlugin :: Plugin
welcomePlugin = plug {commands = [favourite], helpPages = [favouriteHelp]}
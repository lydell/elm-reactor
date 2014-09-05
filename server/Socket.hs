{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE OverloadedStrings #-}
module Socket where

import Control.Monad.Trans (MonadIO(liftIO))
import Control.Monad (forever)
import Control.Concurrent (threadDelay, forkIO)
import Control.Exception as E
import qualified Data.ByteString.Char8 as BSC
import qualified Filesystem.Path.CurrentOS as FP
import qualified Network.WebSockets as WS
import qualified System.FSNotify.Devel as NDevel
import qualified System.FSNotify as Notify

import qualified Generate

fileChangeApp :: FilePath -> WS.ServerApp
fileChangeApp watchedFile pendingConnection =
  do connection <- WS.acceptRequest pendingConnection
     _ <- forkIO $ keepAlive connection
     notifyManager <- liftIO $ Notify.startManager
     updateOnChange watchedFile connection notifyManager
     Notify.stopManager notifyManager

keepAlive :: WS.Connection -> IO ()
keepAlive connection =
  E.catch alive handler
  where
    alive =
      do WS.sendPing connection $ BSC.pack "ping"
         threadDelay (10 * 1000000) -- 10 seconds
         keepAlive connection
    handler :: E.SomeException -> IO ()
    handler _ = return ()

updateOnChange ::  FilePath -> WS.Connection -> Notify.WatchManager -> IO ()
updateOnChange watchedFile connection manager =
  do _ <- NDevel.treeExtExists manager "." "elm" (sendSwap watchedFile connection)
     forever $ threadDelay 10000000 -- related to https://ghc.haskell.org/trac/ghc/ticket/5544

sendSwap :: FilePath -> WS.Connection -> FP.FilePath -> IO ()
sendSwap watchedFile connection _ =
    do result <- liftIO $ Generate.js watchedFile
       WS.sendTextData connection $ BSC.pack result

port module Model.WebSocketMessage exposing (..)

import Json.Decode as JsonDecode
import Json.Encode as JsonEncode
import Url exposing (Url)
import WebSocket as WebSocket


port sendSocketCommand : JsonEncode.Value -> Cmd msg


type alias SocketMessage =
    { action : String
    , status : String
    }


type alias SocketContent a =
    { content : a }


socketMessageEncoder : String -> JsonEncode.Value -> JsonEncode.Value
socketMessageEncoder action data =
    JsonEncode.object
        [ ( "action", JsonEncode.string action )
        , ( "content", data )
        ]


socketMessageDecoder : JsonDecode.Decoder SocketMessage
socketMessageDecoder =
    JsonDecode.map2 SocketMessage
        (JsonDecode.at [ "action" ] JsonDecode.string)
        (JsonDecode.at [ "status" ] JsonDecode.string)


socketContentFromString : JsonDecode.Decoder a -> String -> Result JsonDecode.Error a
socketContentFromString a input =
    JsonDecode.decodeString (JsonDecode.field "content" a) input


socketSend : WebSocket.WebSocketCmd -> Cmd msg
socketSend =
    WebSocket.send sendSocketCommand

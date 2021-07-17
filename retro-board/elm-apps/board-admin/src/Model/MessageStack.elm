module Model.MessageStack exposing (..)

import Json.Decode as JsonDecode
import Json.Encode as JsonEncode
import Model.ActionItem exposing (ActionItem, actionItemDecoder, actionItemEncoder)
import Model.Message exposing (Message, messageDecoder, messageEncoder)


type alias MessageStackId =
    String


type alias MessageStack =
    { id : MessageStackId
    , messages : List Message
    , actions : List ActionItem
    }


messageStackEncoder : MessageStack -> JsonEncode.Value
messageStackEncoder stack =
    JsonEncode.object
        [ ( "_id", JsonEncode.string stack.id )
        , ( "messages", JsonEncode.list messageEncoder stack.messages )
        , ( "actions", JsonEncode.list actionItemEncoder stack.actions )
        ]


messageStackDecoder : JsonDecode.Decoder MessageStack
messageStackDecoder =
    JsonDecode.map3 MessageStack
        (JsonDecode.at [ "_id" ] JsonDecode.string)
        (JsonDecode.at [ "messages" ] (JsonDecode.list messageDecoder))
        (JsonDecode.at [ "actions" ] (JsonDecode.list actionItemDecoder))

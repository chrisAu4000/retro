module Model.Message exposing (..)

import Json.Decode as JsonDecode
import Json.Encode as JsonEncode


type alias MessageId =
    String


type alias Message =
    { id : MessageId
    , text : String
    , upvotes : Int
    , messageType : String
    }


messageEncoder : Message -> JsonEncode.Value
messageEncoder msg =
    JsonEncode.object
        [ ( "_id", JsonEncode.string msg.id )
        , ( "text", JsonEncode.string msg.text )
        , ( "upvotes", JsonEncode.int msg.upvotes )
        , ( "type", JsonEncode.string msg.messageType )
        ]


messageDecoder : JsonDecode.Decoder Message
messageDecoder =
    JsonDecode.map4 Message
        (JsonDecode.at [ "_id" ] JsonDecode.string)
        (JsonDecode.at [ "text" ] JsonDecode.string)
        (JsonDecode.at [ "upvotes" ] JsonDecode.int)
        (JsonDecode.at [ "type" ] JsonDecode.string)


type alias MessageStackId =
    String


type alias MessageStack =
    { id : MessageStackId
    , messages : List Message
    }


messageStackEncoder : MessageStack -> JsonEncode.Value
messageStackEncoder stack =
    JsonEncode.object
        [ ( "_id", JsonEncode.string stack.id )
        , ( "messages", JsonEncode.list messageEncoder stack.messages )
        ]


messageStackDecoder : JsonDecode.Decoder MessageStack
messageStackDecoder =
    JsonDecode.map2 MessageStack
        (JsonDecode.at [ "_id" ] JsonDecode.string)
        (JsonDecode.at [ "messages" ] (JsonDecode.list messageDecoder))

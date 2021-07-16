module Model.Message exposing (..)

import Json.Decode as JsonDecode
import Json.Encode as JsonEncode


type alias MessageId =
    String


type alias Message =
    { id : MessageId
    , text : String
    , upvotes : Int
    }


messageEncoder : Message -> JsonEncode.Value
messageEncoder msg =
    JsonEncode.object
        [ ( "_id", JsonEncode.string msg.id )
        , ( "text", JsonEncode.string msg.text )
        , ( "upvotes", JsonEncode.int msg.upvotes )
        ]


messageDecoder : JsonDecode.Decoder Message
messageDecoder =
    JsonDecode.map3 Message
        (JsonDecode.at [ "_id" ] JsonDecode.string)
        (JsonDecode.at [ "text" ] JsonDecode.string)
        (JsonDecode.at [ "upvotes" ] JsonDecode.int)


type alias ActionItemId =
    String


type alias ActionItem =
    { id : ActionItemId
    , text : String
    }


actionItemEncoder : ActionItem -> JsonEncode.Value
actionItemEncoder action =
    JsonEncode.object
        [ ( "_id", JsonEncode.string action.id )
        , ( "text", JsonEncode.string action.text )
        ]


actionItemDecoder : JsonDecode.Decoder ActionItem
actionItemDecoder =
    JsonDecode.map2 ActionItem
        (JsonDecode.at [ "_id" ] JsonDecode.string)
        (JsonDecode.at [ "text" ] JsonDecode.string)


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

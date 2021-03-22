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
    , createrId : String
    }


messageEncoder : Message -> JsonEncode.Value
messageEncoder msg =
    JsonEncode.object
        [ ( "_id", JsonEncode.string msg.id )
        , ( "text", JsonEncode.string msg.text )
        , ( "upvotes", JsonEncode.int msg.upvotes )
        , ( "type", JsonEncode.string msg.messageType )
        , ( "createrId", JsonEncode.string msg.createrId )
        ]


messageDecoder : JsonDecode.Decoder Message
messageDecoder =
    JsonDecode.map5 Message
        (JsonDecode.at [ "_id" ] JsonDecode.string)
        (JsonDecode.at [ "text" ] JsonDecode.string)
        (JsonDecode.at [ "upvotes" ] JsonDecode.int)
        (JsonDecode.at [ "type" ] JsonDecode.string)
        (JsonDecode.at [ "createrId" ] JsonDecode.string)

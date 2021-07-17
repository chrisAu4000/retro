module Model.ActionItem exposing (..)

import Json.Decode as JsonDecode
import Json.Encode as JsonEncode


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

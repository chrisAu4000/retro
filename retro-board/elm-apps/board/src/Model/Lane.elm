module Model.Lane exposing (..)

import Json.Decode as JsonDecode
import Json.Encode as JsonEncode
import Model.MessageStack exposing (MessageStack, messageStackDecoder, messageStackEncoder)


type alias LaneId =
    String


type alias Lane =
    { id : LaneId
    , heading : String
    , stacks : List MessageStack
    }


laneEncoder : Lane -> JsonEncode.Value
laneEncoder lane =
    JsonEncode.object
        [ ( "_id", JsonEncode.string lane.id )
        , ( "heading", JsonEncode.string lane.heading )
        , ( "stacks", JsonEncode.list messageStackEncoder lane.stacks )
        ]


laneDecoder : JsonDecode.Decoder Lane
laneDecoder =
    JsonDecode.map3 Lane
        (JsonDecode.at [ "_id" ] JsonDecode.string)
        (JsonDecode.at [ "heading" ] JsonDecode.string)
        (JsonDecode.at [ "stacks" ] (JsonDecode.list messageStackDecoder))

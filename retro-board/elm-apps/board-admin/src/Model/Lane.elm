module Model.Lane exposing (..)

import Json.Decode as JsonDecode
import Json.Encode as JsonEncode
import Model.Message exposing (Message, messageDecoder, messageEncoder)


type alias LaneId =
    String


type alias Lane =
    { id : LaneId
    , heading : String
    , messages : List Message
    }


laneEncoder : Lane -> JsonEncode.Value
laneEncoder lane =
    JsonEncode.object
        [ ( "_id", JsonEncode.string lane.id )
        , ( "heading", JsonEncode.string lane.heading )
        , ( "messages", JsonEncode.list messageEncoder lane.messages )
        ]


laneDecoder : JsonDecode.Decoder Lane
laneDecoder =
    JsonDecode.map3 Lane
        (JsonDecode.at [ "_id" ] JsonDecode.string)
        (JsonDecode.at [ "heading" ] JsonDecode.string)
        (JsonDecode.at [ "messages" ] (JsonDecode.list messageDecoder))
